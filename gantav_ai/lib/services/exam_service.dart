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

  // ─── Mock Test Generation ─────────────────────────────────────────────────

  /// Generates a fresh mock test for the given exam+subject via AI.
  /// Falls back to a deterministic sample test if AI is unavailable.
  static Future<MockTest> generateMockTest({
    required ExamCategory exam,
    required ExamSubject subject,
    int questionCount = 25,
    int durationMinutes = 30,
  }) async {
    final testId =
        'mt_${exam.id}_${subject.id}_${DateTime.now().millisecondsSinceEpoch}';

    // Try cache first
    final cached = await _loadCachedTest(testId);
    if (cached != null) return cached;

    List<ExamQuestion> questions = [];
    String source = 'ai-pyq-style';
    String description =
        'AI-generated, PYQ-style questions modelled on ${exam.name} (2024–2026) pattern.';

    // 1. Try real online PYQs via Gemini Google-Search grounding
    if (ApiConfig.hasGemini) {
      try {
        questions = await PyqService.fetchOnlinePyqs(
          exam: exam,
          subject: subject,
          count: questionCount,
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

    // 2. Fall back to AI-generated PYQ-style questions
    if (questions.isEmpty && ApiConfig.isConfigured) {
      try {
        questions = await _aiGenerateQuestions(
          exam: exam,
          subject: subject,
          count: questionCount,
        );
      } catch (e) {
        debugPrint('[ExamService] AI generation failed: $e');
      }
    }

    // 3. Final offline fallback
    if (questions.isEmpty) {
      questions = _fallbackQuestions(exam: exam, subject: subject, count: questionCount);
    }

    final test = MockTest(
      id: testId,
      examId: exam.id,
      subjectId: subject.id,
      title: '${subject.name} — Full Mock Test',
      description: description,
      durationMinutes: durationMinutes,
      questions: questions,
      createdAt: DateTime.now(),
      source: source,
    );

    await _cacheTest(test);
    return test;
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
- Cover a variety of topics within ${subject.name}.
- Mix difficulty: ~30% easy, ~50% medium, ~20% hard.
- Each question must have exactly 4 options.
- Provide a concise 1–2 line explanation for the correct answer.
- For numerical/math: keep answers precise. For theory: avoid ambiguity.

Return ONLY a valid JSON array, no markdown, no prose:
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

    final response = await GeminiService.callAI(
      prompt,
      task: AITask.courseGeneration, // uses the strongest JSON-capable provider
      maxTokens: 4500,
      temperature: 0.4,
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

  static Future<MockTest?> _loadCachedTest(String testId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachePrefix + testId);
      if (raw == null) return null;
      return MockTest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
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
