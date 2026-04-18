import 'package:flutter/material.dart';

/// Data models for the Exam Preparation section (SSC, UPSC, Banking, JEE/NEET/CUET, etc.)
///
/// Question bank is AI-generated in the style of past year questions (2024–2026).
/// We intentionally do NOT claim these are verbatim real PYQs, since LLMs hallucinate.

// ─── Exam Category ───────────────────────────────────────────────────────────

class ExamCategory {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final List<ExamSubject> subjects;
  final int mockTestCount;
  final String difficulty; // 'Easy' | 'Medium' | 'Hard'

  const ExamCategory({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.subjects,
    this.mockTestCount = 0,
    this.difficulty = 'Medium',
  });

  /// Built-in catalog of supported exams. Extend this list to add new exams.
  static List<ExamCategory> catalog() {
    return [
      ExamCategory(
        id: 'ssc',
        name: 'SSC',
        tagline: 'CGL • CHSL • MTS',
        description: 'Staff Selection Commission exams — reasoning, quant, English, GK.',
        icon: Icons.account_balance_rounded,
        gradient: const [Color(0xFF6D5BDB), Color(0xFF4C3BB0)],
        subjects: const [
          ExamSubject(id: 'ssc_reasoning', name: 'Reasoning', icon: Icons.psychology_rounded, topicCount: 24),
          ExamSubject(id: 'ssc_quant', name: 'Quantitative Aptitude', icon: Icons.calculate_rounded, topicCount: 28),
          ExamSubject(id: 'ssc_english', name: 'English', icon: Icons.menu_book_rounded, topicCount: 18),
          ExamSubject(id: 'ssc_gk', name: 'General Awareness', icon: Icons.public_rounded, topicCount: 30),
        ],
        mockTestCount: 40,
      ),
      ExamCategory(
        id: 'upsc',
        name: 'UPSC',
        tagline: 'Prelims • Mains',
        description: 'Civil Services examination — polity, history, geography, current affairs.',
        icon: Icons.gavel_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFB45309)],
        subjects: const [
          ExamSubject(id: 'upsc_polity', name: 'Indian Polity', icon: Icons.account_balance_rounded, topicCount: 25),
          ExamSubject(id: 'upsc_history', name: 'History', icon: Icons.auto_stories_rounded, topicCount: 32),
          ExamSubject(id: 'upsc_geography', name: 'Geography', icon: Icons.public_rounded, topicCount: 22),
          ExamSubject(id: 'upsc_economy', name: 'Economy', icon: Icons.trending_up_rounded, topicCount: 18),
          ExamSubject(id: 'upsc_current', name: 'Current Affairs', icon: Icons.newspaper_rounded, topicCount: 40),
        ],
        mockTestCount: 60,
        difficulty: 'Hard',
      ),
      ExamCategory(
        id: 'banking',
        name: 'Banking',
        tagline: 'IBPS • SBI • RBI',
        description: 'Bank PO and Clerk level exams — reasoning, quant, English, banking awareness.',
        icon: Icons.account_balance_wallet_rounded,
        gradient: const [Color(0xFF0DBAB5), Color(0xFF059669)],
        subjects: const [
          ExamSubject(id: 'bank_reasoning', name: 'Reasoning', icon: Icons.psychology_rounded, topicCount: 22),
          ExamSubject(id: 'bank_quant', name: 'Quantitative Aptitude', icon: Icons.calculate_rounded, topicCount: 26),
          ExamSubject(id: 'bank_english', name: 'English', icon: Icons.menu_book_rounded, topicCount: 16),
          ExamSubject(id: 'bank_awareness', name: 'Banking Awareness', icon: Icons.account_balance_rounded, topicCount: 24),
          ExamSubject(id: 'bank_computer', name: 'Computer Knowledge', icon: Icons.computer_rounded, topicCount: 14),
        ],
        mockTestCount: 45,
      ),
      ExamCategory(
        id: 'entrance',
        name: 'JEE / NEET / CUET',
        tagline: 'Engineering • Medical • University',
        description: 'Entrance exams — physics, chemistry, mathematics, biology, aptitude.',
        icon: Icons.science_rounded,
        gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
        subjects: const [
          ExamSubject(id: 'entrance_physics', name: 'Physics', icon: Icons.bolt_rounded, topicCount: 28),
          ExamSubject(id: 'entrance_chemistry', name: 'Chemistry', icon: Icons.science_rounded, topicCount: 26),
          ExamSubject(id: 'entrance_maths', name: 'Mathematics', icon: Icons.functions_rounded, topicCount: 30),
          ExamSubject(id: 'entrance_biology', name: 'Biology', icon: Icons.biotech_rounded, topicCount: 24),
          ExamSubject(id: 'entrance_aptitude', name: 'General Aptitude', icon: Icons.psychology_rounded, topicCount: 15),
        ],
        mockTestCount: 55,
        difficulty: 'Hard',
      ),
    ];
  }

  static ExamCategory? byId(String id) {
    try {
      return catalog().firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ─── Subject ─────────────────────────────────────────────────────────────────

class ExamSubject {
  final String id;
  final String name;
  final IconData icon;
  final int topicCount;

  /// Curated YouTube video IDs for preparation — lightweight playlist baked
  /// into the catalog so the subject screen always has content even offline.
  /// Admins can override/extend these via the admin panel later.
  final List<String> videoIds;

  const ExamSubject({
    required this.id,
    required this.name,
    required this.icon,
    this.topicCount = 0,
    this.videoIds = const [],
  });

  /// Falls back to the seed map when no explicit [videoIds] were provided
  /// (the catalog relies on this so existing entries get free video content).
  List<String> get effectiveVideoIds =>
      videoIds.isNotEmpty ? videoIds : (kSubjectVideoSeeds[id] ?? const []);
}

/// Seed preparation videos per subject id. Maintained centrally so the UI
/// layer can simply look up [subject.id] without recomputing.
const Map<String, List<String>> kSubjectVideoSeeds = {
  // SSC
  'ssc_reasoning': ['F0yWOKLNWdo', 'E2-iBIyTfFE', 'sPS7tYFi7qI'],
  'ssc_quant':     ['6ssAs_VMxvQ', 'kxB3FJ4dUiw', 'B7XHv4VQEgI'],
  'ssc_english':   ['F7rxRtXxsoI', 'Za4HhqEMUW8', 'xlDvvMoGSm4'],
  'ssc_gk':        ['6IaRwJgjSAE', 'zZpSJ2Gq19o', 'aEaNtRacDzY'],

  // UPSC
  'upsc_polity':     ['VHugGUWK00M', 'W-ITRxDk9JM', 'Uj3HazOOdDg'],
  'upsc_history':    ['OcazZCQNu24', 'R-LVXDDm4UA', 'Kfx3cQppTHY'],
  'upsc_geography':  ['8OM8hTJ_TKI', 'VsXVBsQtZXM', 'WgkOjxUCIho'],
  'upsc_economy':    ['5XcZl1Yy0hU', 'pevhi_9NvrM', 'iLvGyEj8YfQ'],
  'upsc_current':    ['lKZB7xjjRVM', 'kQLa88MyGjc', 'VdZrXWJWe10'],

  // Banking
  'bank_reasoning':  ['Z6ZsXxTmyIU', 'rAGtyDp69Tc', 'UUO9jAhpyOM'],
  'bank_quant':      ['BmHx2odQtU4', 'GxgJH6JN_lU', 'iH4vHv4vLjU'],
  'bank_english':    ['Eg7kS2Oe0m4', 'KpUNA2nutPw', 'FZiJMGrcL4o'],
  'bank_awareness':  ['qoBpaC0rqhE', 'pBHtPiu2z6o', 'uHv3SXmKkXQ'],
  'bank_computer':   ['Fl4L5KDS8Uk', 'bum_19loj-E', 'aU0euN3qrzU'],

  // Entrance (JEE / NEET / CUET)
  'entrance_physics':   ['PplUEcysUQA', 'DC2OosMqbyc', 'y2r2TpETZIw'],
  'entrance_chemistry': ['VSdz3IYAu60', 'l2Cc9wXfD84', 'oKkZoBsuNJU'],
  'entrance_maths':     ['_BUR2ENY1X0', 'lXZFSS7RADs', 'PQm4ZRhoGbM'],
  'entrance_biology':   ['RGjbjCnPoJs', 'H9_z7Lz6kD4', 'EEjAR-uhSeg'],
  'entrance_aptitude':  ['cbCRHRfyH6M', 'pRc43p4SVLs', '7vshePMvTH0'],
};

// ─── Mock Test Question ──────────────────────────────────────────────────────

class ExamQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String topic;
  final double marks;
  final double negativeMarks;
  final String difficulty; // 'easy' | 'medium' | 'hard'
  final int year; // 0 = unknown

  const ExamQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.topic = '',
    this.marks = 1.0,
    this.negativeMarks = 0.25,
    this.difficulty = 'medium',
    this.year = 0,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> j) {
    final opts = (j['options'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return ExamQuestion(
      id: (j['id'] ?? 'q_${DateTime.now().microsecondsSinceEpoch}').toString(),
      question: (j['question'] ?? '').toString(),
      options: opts,
      correctIndex: (j['correct_index'] ?? j['correctIndex'] ?? 0) as int,
      explanation: (j['explanation'] ?? '').toString(),
      topic: (j['topic'] ?? '').toString(),
      marks: ((j['marks'] ?? 1.0) as num).toDouble(),
      negativeMarks: ((j['negative_marks'] ?? j['negativeMarks'] ?? 0.25) as num).toDouble(),
      difficulty: (j['difficulty'] ?? 'medium').toString().toLowerCase(),
      year: (j['year'] is num) ? (j['year'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'options': options,
        'correct_index': correctIndex,
        'explanation': explanation,
        'topic': topic,
        'marks': marks,
        'negative_marks': negativeMarks,
        'difficulty': difficulty,
        'year': year,
      };
}

// ─── Mock Test ───────────────────────────────────────────────────────────────

class MockTest {
  final String id;
  final String examId;
  final String subjectId;
  final String title;
  final String description;
  final int durationMinutes;
  final List<ExamQuestion> questions;
  final DateTime createdAt;
  final String source; // 'ai-pyq-style' | 'dataset' | etc.

  const MockTest({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.questions,
    required this.createdAt,
    this.source = 'ai-pyq-style',
  });

  double get totalMarks => questions.fold(0.0, (sum, q) => sum + q.marks);

  Map<String, dynamic> toJson() => {
        'id': id,
        'exam_id': examId,
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'duration_minutes': durationMinutes,
        'questions': questions.map((q) => q.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'source': source,
      };

  factory MockTest.fromJson(Map<String, dynamic> j) => MockTest(
        id: (j['id'] ?? '').toString(),
        examId: (j['exam_id'] ?? '').toString(),
        subjectId: (j['subject_id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        durationMinutes: (j['duration_minutes'] ?? 30) as int,
        questions: ((j['questions'] as List?) ?? const [])
            .map((q) => ExamQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()) ?? DateTime.now(),
        source: (j['source'] ?? 'ai-pyq-style').toString(),
      );
}

// ─── Mock Test Attempt ───────────────────────────────────────────────────────

class MockAttempt {
  final String id;
  final String testId;
  final String examId;
  final String subjectId;
  final String testTitle;
  final DateTime startedAt;
  final DateTime submittedAt;
  final int durationTakenSeconds;
  final Map<String, int?> answers; // questionId -> chosenIndex (null = unattempted)
  final double score;
  final double maxScore;
  final int correct;
  final int wrong;
  final int unattempted;

  const MockAttempt({
    required this.id,
    required this.testId,
    required this.examId,
    required this.subjectId,
    required this.testTitle,
    required this.startedAt,
    required this.submittedAt,
    required this.durationTakenSeconds,
    required this.answers,
    required this.score,
    required this.maxScore,
    required this.correct,
    required this.wrong,
    required this.unattempted,
  });

  double get accuracy {
    final attempted = correct + wrong;
    if (attempted == 0) return 0.0;
    return correct / attempted;
  }

  double get percentage => maxScore == 0 ? 0.0 : (score / maxScore);

  Map<String, dynamic> toJson() => {
        'id': id,
        'test_id': testId,
        'exam_id': examId,
        'subject_id': subjectId,
        'test_title': testTitle,
        'started_at': startedAt.toIso8601String(),
        'submitted_at': submittedAt.toIso8601String(),
        'duration_taken_seconds': durationTakenSeconds,
        'answers': answers,
        'score': score,
        'max_score': maxScore,
        'correct': correct,
        'wrong': wrong,
        'unattempted': unattempted,
      };

  factory MockAttempt.fromJson(Map<String, dynamic> j) => MockAttempt(
        id: (j['id'] ?? '').toString(),
        testId: (j['test_id'] ?? '').toString(),
        examId: (j['exam_id'] ?? '').toString(),
        subjectId: (j['subject_id'] ?? '').toString(),
        testTitle: (j['test_title'] ?? '').toString(),
        startedAt: DateTime.tryParse((j['started_at'] ?? '').toString()) ?? DateTime.now(),
        submittedAt: DateTime.tryParse((j['submitted_at'] ?? '').toString()) ?? DateTime.now(),
        durationTakenSeconds: (j['duration_taken_seconds'] ?? 0) as int,
        answers: ((j['answers'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k.toString(), v is int ? v : null),
        ),
        score: ((j['score'] ?? 0) as num).toDouble(),
        maxScore: ((j['max_score'] ?? 0) as num).toDouble(),
        correct: (j['correct'] ?? 0) as int,
        wrong: (j['wrong'] ?? 0) as int,
        unattempted: (j['unattempted'] ?? 0) as int,
      );
}
