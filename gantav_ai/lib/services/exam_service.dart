import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam_models.dart';
import 'api_config.dart';
import 'gemini_service.dart';
import 'pyq_service.dart';

/// Service responsible for generating AI mock tests and storing user attempts.
///
/// Questions are AI-generated in "past year style" — framed like PYQs from 2024–2026
/// (pattern, difficulty, topic distribution), but NOT presented as real verbatim PYQs.
/// This avoids LLM hallucination from misleading students.
class ExamService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  static String? get _uid => _auth.currentUser?.uid;

  // Local cache so tests open instantly if we already generated them
  static const String _cachePrefix = 'mock_test_cache_';
  static const String _attemptsKey = 'mock_attempts';

  // Persistent per exam+subject question bank. First attempt fills it with ~50
  // AI-generated questions; every subsequent attempt reshuffles a random subset
  // instead of calling the AI again. This is what keeps quota alive and ensures
  // the user never sees the tiny 2-question static fallback after day one.
  static const String _bankPrefix = 'exam_qbank_v1_';
  static const int _bankTargetSize = 50;
  static const Duration _bankTtl = Duration(days: 30);

  // ─── Mock Test Generation ─────────────────────────────────────────────────

  /// Generates a mock test for the given exam+subject.
  ///
  /// Strategy: maintain a persistent bank of ~50 questions per (exam, subject).
  /// A mock test is a random subset of `questionCount` drawn from the bank, so
  /// the very first user pays the AI cost and every later attempt is instant
  /// and works offline. The bank auto-refreshes after [_bankTtl].
  static Future<MockTest> generateMockTest({
    required ExamCategory exam,
    required ExamSubject subject,
    int questionCount = 25,
    int durationMinutes = 30,
  }) async {
    final bank = await _getOrBuildBank(exam: exam, subject: subject);

    final picked = _pickSubset(bank.questions, questionCount);
    final source = bank.source;
    final description = bank.description;

    final testId =
        'mt_${exam.id}_${subject.id}_${DateTime.now().millisecondsSinceEpoch}';

    final test = MockTest(
      id: testId,
      examId: exam.id,
      subjectId: subject.id,
      title: '${subject.name} — Full Mock Test',
      description: description,
      durationMinutes: durationMinutes,
      questions: picked,
      createdAt: DateTime.now(),
      source: source,
    );

    await _cacheTest(test);
    return test;
  }

  /// Re-rolls the bank from scratch (used when the user taps "Fresh questions"
  /// in the mock-test intro screen, if exposed). Safe to call — falls back to
  /// the existing bank if AI is unavailable.
  static Future<void> refreshBank({
    required ExamCategory exam,
    required ExamSubject subject,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bankKey(exam, subject));
    await _getOrBuildBank(exam: exam, subject: subject);
  }

  // ─── Question Bank ────────────────────────────────────────────────────────

  static String _bankKey(ExamCategory exam, ExamSubject subject) =>
      '$_bankPrefix${exam.id}_${subject.id}';

  static Future<_QuestionBank> _getOrBuildBank({
    required ExamCategory exam,
    required ExamSubject subject,
  }) async {
    // 1. Local cache
    final cached = await _loadBank(exam, subject);
    if (cached != null && cached.questions.length >= 10) return cached;

    // 2. Firestore mirror (so a second device/user doesn't re-pay the AI cost)
    final remote = await _loadBankFromFirestore(exam, subject);
    if (remote != null && remote.questions.length >= 10) {
      await _saveBank(exam, subject, remote);
      return remote;
    }

    // 3. Build fresh
    return _buildBank(exam: exam, subject: subject);
  }

  static Future<_QuestionBank> _buildBank({
    required ExamCategory exam,
    required ExamSubject subject,
  }) async {
    List<ExamQuestion> questions = [];
    String source = 'ai-pyq-style';
    String description =
        'AI-generated, PYQ-style questions modelled on ${exam.name} (2024–2026) pattern.';

    // Try real online PYQs via Gemini Google-Search grounding
    if (ApiConfig.hasGemini) {
      try {
        questions = await PyqService.fetchOnlinePyqs(
          exam: exam,
          subject: subject,
          count: _bankTargetSize,
        );
        if (questions.isNotEmpty) {
          source = 'online-pyq';
          description =
              'Real past year questions sourced from trusted ${exam.name} repositories (2024–2026).';
        }
      } catch (e) {
        debugPrint('[ExamService] online PYQ fetch failed: $e');
      }
    }

    // Fall back to AI-generated PYQ-style questions
    if (questions.length < 10 && ApiConfig.isConfigured) {
      try {
        final generated = await _aiGenerateQuestions(
          exam: exam,
          subject: subject,
          count: _bankTargetSize,
        );
        // Merge, dedupe on question text
        final existing = questions.map((q) => q.question.toLowerCase()).toSet();
        for (final q in generated) {
          if (existing.add(q.question.toLowerCase())) questions.add(q);
        }
      } catch (e) {
        debugPrint('[ExamService] AI generation failed: $e');
      }
    }

    // Final offline fallback — only used when we have zero questions
    if (questions.isEmpty) {
      questions = _fallbackQuestions(
        exam: exam,
        subject: subject,
        count: 10,
      );
      source = 'offline-fallback';
      description =
          'Offline starter questions. Connect to internet to unlock the full AI-generated bank.';
    }

    final bank = _QuestionBank(
      questions: questions,
      source: source,
      description: description,
      builtAt: DateTime.now(),
    );
    await _saveBank(exam, subject, bank);
    // Mirror to Firestore (best effort, don't block)
    _saveBankToFirestore(exam, subject, bank);
    return bank;
  }

  static Future<_QuestionBank?> _loadBank(
      ExamCategory exam, ExamSubject subject) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_bankKey(exam, subject));
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final builtAt = DateTime.tryParse(map['built_at']?.toString() ?? '');
      if (builtAt == null ||
          DateTime.now().difference(builtAt) > _bankTtl) {
        await prefs.remove(_bankKey(exam, subject));
        return null;
      }
      final list = (map['questions'] as List)
          .map((j) => ExamQuestion.fromJson(j as Map<String, dynamic>))
          .toList();
      return _QuestionBank(
        questions: list,
        source: map['source']?.toString() ?? 'ai-pyq-style',
        description: map['description']?.toString() ?? '',
        builtAt: builtAt,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveBank(
      ExamCategory exam, ExamSubject subject, _QuestionBank bank) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _bankKey(exam, subject),
        jsonEncode({
          'built_at': bank.builtAt.toIso8601String(),
          'source': bank.source,
          'description': bank.description,
          'questions': bank.questions.map((q) => q.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  static Future<_QuestionBank?> _loadBankFromFirestore(
      ExamCategory exam, ExamSubject subject) async {
    try {
      final snap = await _db
          .collection('exam_banks')
          .doc('${exam.id}_${subject.id}')
          .get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final builtAt = DateTime.tryParse(data['built_at']?.toString() ?? '');
      if (builtAt == null ||
          DateTime.now().difference(builtAt) > _bankTtl) {
        return null;
      }
      final list = (data['questions'] as List)
          .map((j) => ExamQuestion.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      return _QuestionBank(
        questions: list,
        source: data['source']?.toString() ?? 'ai-pyq-style',
        description: data['description']?.toString() ?? '',
        builtAt: builtAt,
      );
    } catch (e) {
      debugPrint('[ExamService] firestore bank load error: $e');
      return null;
    }
  }

  static Future<void> _saveBankToFirestore(
      ExamCategory exam, ExamSubject subject, _QuestionBank bank) async {
    try {
      await _db.collection('exam_banks').doc('${exam.id}_${subject.id}').set({
        'built_at': bank.builtAt.toIso8601String(),
        'source': bank.source,
        'description': bank.description,
        'questions': bank.questions.map((q) => q.toJson()).toList(),
        'exam_id': exam.id,
        'subject_id': subject.id,
      });
    } catch (e) {
      debugPrint('[ExamService] firestore bank save error: $e');
    }
  }

  static List<ExamQuestion> _pickSubset(
      List<ExamQuestion> bank, int count) {
    if (bank.length <= count) {
      final copy = List<ExamQuestion>.from(bank)..shuffle(Random());
      return copy;
    }
    final copy = List<ExamQuestion>.from(bank)..shuffle(Random());
    return copy.take(count).toList();
  }

  static Future<List<ExamQuestion>> _aiGenerateQuestions({
    required ExamCategory exam,
    required ExamSubject subject,
    required int count,
  }) async {
    // Hard-anchor the prompt to PYQ-STYLE framing, emphasise 2024-2026 patterns
    final prompt = '''
You are an expert Indian competitive-exam question setter for ${exam.name} (${exam.tagline}).

Generate exactly $count multiple-choice questions for the subject "${subject.name}".

Guidelines:
- Match the *style, difficulty curve, and topic distribution* of past year questions from 2024, 2025, and 2026.
- Do NOT copy any specific real PYQ verbatim. Create original questions in the same pattern.
- Ensure strong TOPIC DIVERSITY — spread across every major sub-topic of ${subject.name}. No two questions should test the exact same concept.
- Mix difficulty: ~30% easy, ~50% medium, ~20% hard.
- Each question must have exactly 4 options, unambiguous, and only ONE correct.
- Provide a concise 1–2 line explanation for the correct answer.
- For numerical/math: keep answers precise. For theory: avoid ambiguity.
- Use unique ids q_1, q_2, … q_$count.

Return ONLY a valid JSON array (no markdown, no prose, no trailing commas):
[
  {
    "id": "q_1",
    "question": "...",
    "options": ["A","B","C","D"],
    "correct_index": 0,
    "explanation": "...",
    "topic": "sub-topic inside ${subject.name}",
    "marks": 1.0,
    "negative_marks": 0.25
  }
]
''';

    // Larger bank needs a bigger token budget. Gemini 1.5 Flash handles ~8K
    // comfortably for JSON arrays of this shape.
    final tokenBudget = (count * 180).clamp(2000, 8000);
    final response = await GeminiService.callAI(
      prompt,
      task: AITask.courseGeneration, // uses the strongest JSON-capable provider
      maxTokens: tokenBudget,
      temperature: 0.5,
    );
    if (response == null) return [];

    try {
      final jsonStr = GeminiService.extractJson(response);
      final List<dynamic> data = jsonDecode(jsonStr);
      final questions = <ExamQuestion>[];
      for (var i = 0; i < data.length; i++) {
        try {
          final q = ExamQuestion.fromJson(data[i] as Map<String, dynamic>);
          if (q.question.isNotEmpty && q.options.length == 4) {
            questions.add(q);
          }
        } catch (_) {
          // skip malformed item
        }
      }
      return questions;
    } catch (e) {
      debugPrint('[ExamService] JSON parse error: $e');
      return [];
    }
  }

  /// Fallback question bank — small set of neutral "template" questions per subject so
  /// the UI always works even when offline or keys are missing.
  static List<ExamQuestion> _fallbackQuestions({
    required ExamCategory exam,
    required ExamSubject subject,
    required int count,
  }) {
    final rnd = Random();
    final templates = _fallbackTemplates[subject.id] ?? _fallbackTemplates['generic']!;
    final out = <ExamQuestion>[];
    for (int i = 0; i < count; i++) {
      final t = templates[i % templates.length];
      final shuffled = List<String>.from(t['options'] as List);
      shuffled.shuffle(rnd);
      final correctText = (t['options'] as List)[t['correct_index'] as int].toString();
      out.add(ExamQuestion(
        id: 'fb_${subject.id}_$i',
        question: t['question'] as String,
        options: shuffled,
        correctIndex: shuffled.indexOf(correctText),
        explanation: t['explanation'] as String? ?? '',
        topic: subject.name,
      ));
    }
    return out;
  }

  // Simple fallback template bank — lightweight placeholders per subject family
  static final Map<String, List<Map<String, dynamic>>> _fallbackTemplates = {
    'generic': [
      {
        'question': 'Sample question: 2 + 2 = ?',
        'options': ['3', '4', '5', '6'],
        'correct_index': 1,
        'explanation': 'Basic arithmetic.',
      },
      {
        'question': 'Sample question: Which of these is a primary colour?',
        'options': ['Green', 'Orange', 'Red', 'Purple'],
        'correct_index': 2,
        'explanation': 'Red, blue, yellow are primary colours.',
      },
    ],
  };

  // ─── Cache ─────────────────────────────────────────────────────────────────

  static Future<void> _cacheTest(MockTest test) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachePrefix + test.id, jsonEncode(test.toJson()));
    } catch (_) {}
  }

  // ─── Scoring ───────────────────────────────────────────────────────────────

  /// Computes a [MockAttempt] from raw answers.
  static MockAttempt scoreAttempt({
    required MockTest test,
    required Map<String, int?> answers,
    required DateTime startedAt,
    required DateTime submittedAt,
  }) {
    double score = 0;
    int correct = 0;
    int wrong = 0;
    int unattempted = 0;

    for (final q in test.questions) {
      final picked = answers[q.id];
      if (picked == null) {
        unattempted++;
      } else if (picked == q.correctIndex) {
        correct++;
        score += q.marks;
      } else {
        wrong++;
        score -= q.negativeMarks;
      }
    }
    // Never allow negative final score
    if (score < 0) score = 0;

    return MockAttempt(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
      testId: test.id,
      examId: test.examId,
      subjectId: test.subjectId,
      testTitle: test.title,
      startedAt: startedAt,
      submittedAt: submittedAt,
      durationTakenSeconds: submittedAt.difference(startedAt).inSeconds,
      answers: answers,
      score: score,
      maxScore: test.totalMarks,
      correct: correct,
      wrong: wrong,
      unattempted: unattempted,
    );
  }

  // ─── Attempts: persist locally + Firestore ────────────────────────────────

  static Future<void> saveAttempt(MockAttempt attempt) async {
    // Local
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_attemptsKey) ?? <String>[];
      list.insert(0, jsonEncode(attempt.toJson()));
      // keep last 100
      if (list.length > 100) list.removeRange(100, list.length);
      await prefs.setStringList(_attemptsKey, list);
    } catch (e) {
      debugPrint('[ExamService] local attempt save error: $e');
    }

    // Firestore (best-effort)
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('mock_attempts')
          .doc(attempt.id)
          .set(attempt.toJson());
    } catch (e) {
      debugPrint('[ExamService] firestore attempt save error: $e');
    }
  }

  static Future<List<MockAttempt>> loadAttempts({String? examId, String? subjectId}) async {
    // Prefer Firestore when authed, else fall back to local cache
    final uid = _uid;
    if (uid != null) {
      try {
        Query<Map<String, dynamic>> q = _db
            .collection('users')
            .doc(uid)
            .collection('mock_attempts');
        if (examId != null) q = q.where('exam_id', isEqualTo: examId);
        if (subjectId != null) q = q.where('subject_id', isEqualTo: subjectId);
        final snap = await q.get();
        final attempts = snap.docs.map((d) => MockAttempt.fromJson(d.data())).toList()
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        if (attempts.isNotEmpty) return attempts;
      } catch (e) {
        debugPrint('[ExamService] firestore load error: $e');
      }
    }

    // Local fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_attemptsKey) ?? <String>[];
      final all = list
          .map((s) {
            try {
              return MockAttempt.fromJson(jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<MockAttempt>()
          .toList();
      return all.where((a) {
        if (examId != null && a.examId != examId) return false;
        if (subjectId != null && a.subjectId != subjectId) return false;
        return true;
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

class _QuestionBank {
  final List<ExamQuestion> questions;
  final String source;
  final String description;
  final DateTime builtAt;

  _QuestionBank({
    required this.questions,
    required this.source,
    required this.description,
    required this.builtAt,
  });
}
