import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam_models.dart';
import 'api_config.dart';
import 'gemini_service.dart';

/// Fetches *real* past-year questions from online resources using Gemini's
/// built-in Google Search grounding tool, then converts them into mock test
/// questions.
///
/// Flow:
///   1. Ask Gemini (with `google_search` tool) to browse trusted PYQ
///      sources for the exam+subject and return a structured JSON list.
///   2. Normalise the response into [ExamQuestion] objects.
///   3. Cache the result so repeated generations are instant.
///
/// When the grounded call fails (no Gemini key, rate-limit, malformed JSON),
/// the caller ([ExamService]) falls back to the AI PYQ-style generator.
class PyqService {
  static const String _cachePrefix = 'pyq_online_cache_';
  static const Duration _cacheTtl = Duration(days: 3);

  // ─── Dataset layer (bundled JSON + Firestore mirror) ─────────────────────

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Firestore collection for admin-uploaded PYQ banks.
  /// Document id: `{exam_id}_{subject_id}`, e.g. `entrance_physics`.
  /// Schema: `{ exam_id, subject_id, source, updated_at, questions: [...] }`.
  static const String _firestoreCollection = 'pyq_bank';

  /// In-memory cache of bundled assets so we don't re-read the same JSON.
  static final Map<String, List<ExamQuestion>> _assetCache = {};

  /// Load real PYQs from the bundled asset `assets/pyq/{examId}_{subjectId}.json`
  /// merged with any admin-uploaded questions in Firestore
  /// `pyq_bank/{examId}_{subjectId}`.
  ///
  /// Dataset is authoritative: this takes precedence over the Gemini online
  /// fetch in [ExamService._buildBank]. Returns an empty list if neither
  /// source has data, letting the caller fall through to AI.
  static Future<List<ExamQuestion>> loadDatasetQuestions({
    required ExamCategory exam,
    required ExamSubject subject,
  }) async {
    final asset = await _loadFromAsset(exam.id, subject.id);
    final remote = await _loadFromFirestore(exam.id, subject.id);

    // Merge asset + remote, dedupe by id (remote wins on conflict)
    final byId = <String, ExamQuestion>{};
    for (final q in asset) {
      byId[q.id] = q;
    }
    for (final q in remote) {
      byId[q.id] = q;
    }
    final merged = byId.values.toList();
    merged.shuffle(Random());
    return merged;
  }

  /// Read the bundled `assets/pyq/{examId}_{subjectId}.json`. Returns empty
  /// on missing file, parse error, or schema mismatch — caller handles
  /// fallback.
  static Future<List<ExamQuestion>> _loadFromAsset(
    String examId,
    String subjectId,
  ) async {
    final cacheKey = '${examId}_$subjectId';
    final cached = _assetCache[cacheKey];
    if (cached != null) return cached;

    try {
      final raw =
          await rootBundle.loadString('assets/pyq/${examId}_$subjectId.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <ExamQuestion>[];
      for (final item in decoded) {
        try {
          final q = ExamQuestion.fromJson(item as Map<String, dynamic>);
          if (q.question.trim().isEmpty) continue;
          if (q.options.length != 4) continue;
          if (q.correctIndex < 0 || q.correctIndex > 3) continue;
          out.add(q);
        } catch (_) {
          // skip malformed record
        }
      }
      _assetCache[cacheKey] = out;
      debugPrint(
          '[PyqService] loaded ${out.length} Qs from asset pyq/${examId}_$subjectId.json');
      return out;
    } catch (e) {
      // Missing asset is expected for subjects without a bundled bank — no
      // need to noisy-log.
      return const [];
    }
  }

  /// Read admin-uploaded questions from Firestore. Supports both the flat
  /// `questions` array on the bank doc AND a subcollection `questions` of
  /// per-question docs, so large banks can be written page-by-page.
  static Future<List<ExamQuestion>> _loadFromFirestore(
    String examId,
    String subjectId,
  ) async {
    final docId = '${examId}_$subjectId';
    try {
      final docRef = _db.collection(_firestoreCollection).doc(docId);
      final snap = await docRef.get();
      final out = <ExamQuestion>[];

      if (snap.exists) {
        final data = snap.data() ?? {};
        final list = (data['questions'] as List?) ?? const [];
        for (final item in list) {
          try {
            final q = ExamQuestion.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
            if (q.options.length == 4 &&
                q.correctIndex >= 0 &&
                q.correctIndex <= 3 &&
                q.question.trim().isNotEmpty) {
              out.add(q);
            }
          } catch (_) {}
        }
      }

      // Also check the subcollection — used when the bank exceeds the 1 MB
      // single-doc limit.
      try {
        final subSnap = await docRef.collection('questions').limit(500).get();
        for (final d in subSnap.docs) {
          try {
            final q = ExamQuestion.fromJson(
              Map<String, dynamic>.from(d.data()),
            );
            if (q.options.length == 4 &&
                q.correctIndex >= 0 &&
                q.correctIndex <= 3 &&
                q.question.trim().isNotEmpty) {
              out.add(q);
            }
          } catch (_) {}
        }
      } catch (_) {}

      if (out.isNotEmpty) {
        debugPrint('[PyqService] loaded ${out.length} Qs from Firestore $docId');
      }
      return out;
    } catch (e) {
      debugPrint('[PyqService] firestore load error for $docId: $e');
      return const [];
    }
  }

  /// Admin-only: import the bundled asset into Firestore for the given
  /// (exam, subject) so the bank is shared across users and can be extended
  /// remotely without a new APK build. Returns the number of questions
  /// written, or -1 on failure.
  static Future<int> importAssetToFirestore({
    required ExamCategory exam,
    required ExamSubject subject,
    String source = 'bundled-asset',
  }) async {
    final docId = '${exam.id}_${subject.id}';
    try {
      final questions = await _loadFromAsset(exam.id, subject.id);
      if (questions.isEmpty) {
        debugPrint('[PyqService] no asset questions to import for $docId');
        return 0;
      }

      // Single-doc write when small enough (<900 KB budget). Most seeds fit.
      final payload = {
        'exam_id': exam.id,
        'subject_id': subject.id,
        'source': source,
        'updated_at': DateTime.now().toIso8601String(),
        'question_count': questions.length,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

      await _db.collection(_firestoreCollection).doc(docId).set(payload);
      debugPrint(
          '[PyqService] imported ${questions.length} Qs to $_firestoreCollection/$docId');
      return questions.length;
    } catch (e) {
      debugPrint('[PyqService] import failed for $docId: $e');
      return -1;
    }
  }

  // ─── Legacy online fetch (Gemini grounded) ───────────────────────────────

  /// Returns real PYQ-derived questions for (exam, subject). Returns an
  /// empty list on any failure — caller must have its own fallback.
  static Future<List<ExamQuestion>> fetchOnlinePyqs({
    required ExamCategory exam,
    required ExamSubject subject,
    int count = 25,
  }) async {
    // 1. Cache
    final cached = await _loadCache(exam.id, subject.id);
    if (cached != null && cached.length >= count) {
      debugPrint('[PyqService] cache hit: ${cached.length} Qs for ${exam.id}/${subject.id}');
      return cached.take(count).toList();
    }

    // 2. Need Gemini for Google Search grounding
    if (!ApiConfig.hasGemini) {
      debugPrint('[PyqService] no Gemini key; skipping online PYQ fetch');
      return const [];
    }

    try {
      final questions = await _fetchGroundedPyqs(
        exam: exam,
        subject: subject,
        count: count,
      );
      if (questions.isNotEmpty) {
        await _saveCache(exam.id, subject.id, questions);
      }
      return questions;
    } catch (e) {
      debugPrint('[PyqService] grounded fetch failed: $e');
      return const [];
    }
  }

  // ─── Gemini Google-Search grounded call ──────────────────────────────────

  static Future<List<ExamQuestion>> _fetchGroundedPyqs({
    required ExamCategory exam,
    required ExamSubject subject,
    required int count,
  }) async {
    final prompt = '''
You are researching real Past Year Questions (PYQs) for the Indian competitive exam "${exam.name}" (${exam.tagline}), subject "${subject.name}".

**Task:** Use the Google Search tool to browse trusted Indian PYQ repositories (official commission/board websites, Testbook, Oliveboard, Adda247, GradeUp, BYJU'S Exam Prep, official previous-paper PDFs). Collect **real questions that have actually appeared** in ${exam.name} papers between 2024 and 2026.

**Return exactly $count multiple-choice questions** covering the syllabus of ${subject.name}.

Rules:
- Prefer recent (2024–2026) questions. If insufficient, include 2022–2023 questions clearly marked by year in the "topic" field.
- Each question must have exactly 4 options and exactly one correct answer.
- Keep explanations short (1–2 lines), neutral, fact-based.
- Do NOT invent questions. If you cannot find a real question, skip it rather than fabricate.
- Never expose URLs, citation markers, or Google Search artefacts in the "question" / "options" / "explanation" fields.

**Output: ONLY a valid JSON array, no markdown fences, no surrounding prose.**

[
  {
    "id": "q_1",
    "question": "...",
    "options": ["...","...","...","..."],
    "correct_index": 0,
    "explanation": "...",
    "topic": "sub-topic (include year if known, e.g. 'Polity • 2024')",
    "marks": 1.0,
    "negative_marks": 0.25
  }
]
''';

    final url = Uri.parse(
      '${ApiConfig.geminiBaseUrl}/${ApiConfig.geminiModel}:generateContent?key=${ApiConfig.geminiApiKey}',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      // Native Google Search grounding — lets Gemini browse real PYQ pages
      'tools': [
        {'google_search': <String, dynamic>{}},
      ],
      'generationConfig': {
        'temperature': 0.35,
        'maxOutputTokens': 6000,
      },
    });

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      debugPrint('[PyqService] Gemini HTTP ${response.statusCode}: ${response.body}');
      return const [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = (data['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) return const [];

    final parts = (candidates.first['content']?['parts'] as List?) ?? const [];
    final text = parts
        .map((p) => (p as Map<String, dynamic>)['text']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .join('\n');

    if (text.trim().isEmpty) return const [];

    return _parseQuestions(text);
  }

  static List<ExamQuestion> _parseQuestions(String raw) {
    try {
      final jsonStr = GeminiService.extractJson(raw);
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return const [];

      final out = <ExamQuestion>[];
      for (var i = 0; i < decoded.length; i++) {
        try {
          final item = decoded[i] as Map<String, dynamic>;
          final q = ExamQuestion.fromJson(item);
          if (q.question.trim().isEmpty) continue;
          if (q.options.length != 4) continue;
          if (q.correctIndex < 0 || q.correctIndex > 3) continue;
          out.add(q);
        } catch (_) {
          // skip malformed item
        }
      }
      return out;
    } catch (e) {
      debugPrint('[PyqService] parse error: $e');
      return const [];
    }
  }

  // ─── Cache ───────────────────────────────────────────────────────────────

  static String _cacheKey(String examId, String subjectId) =>
      '$_cachePrefix${examId}_$subjectId';

  static Future<void> _saveCache(
    String examId,
    String subjectId,
    List<ExamQuestion> questions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(examId, subjectId),
        jsonEncode({
          'stored_at': DateTime.now().toIso8601String(),
          'questions': questions.map((q) => q.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  static Future<List<ExamQuestion>?> _loadCache(
    String examId,
    String subjectId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(examId, subjectId));
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final storedAt = DateTime.tryParse((data['stored_at'] ?? '').toString());
      if (storedAt == null || DateTime.now().difference(storedAt) > _cacheTtl) {
        return null;
      }
      final list = (data['questions'] as List?) ?? const [];
      return list
          .map((q) => ExamQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
