import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'api_config.dart';

/// Gemini AI Service — Direct REST API client
/// Powers quiz generation, doubt chat, and learning path generation
class GeminiService {
  /// Generate quiz questions for a lesson using Gemini
  static Future<List<QuizQuestion>> generateQuiz({
    required String lessonTitle,
    required String courseTitle,
    required String topic,
    int count = 5,
  }) async {
    if (!ApiConfig.isConfigured) return QuizQuestion.mockQuestions();

    final prompt = '''
You are an expert educator creating quiz questions for a learning app.

Course: $courseTitle
Lesson: $lessonTitle
Topic: $topic

Generate EXACTLY 5 or more multiple-choice quiz questions about this lesson topic. (Minimum 5 questions required).
Each question should test understanding, not just memorization.

Return ONLY valid JSON in this exact format (no markdown, no code fences):
[
  {
    "id": "q_1",
    "question": "Your question here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct_index": 0,
    "explanation": "Brief explanation of the correct answer."
  }
]
''';

    try {
      final response = await _callGemini(prompt);
      if (response == null) return QuizQuestion.mockQuestions();

      final jsonStr = _extractJson(response);
      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((json) => QuizQuestion.fromJson(json)).toList();
    } catch (_) {
      return QuizQuestion.mockQuestions();
    }
  }

  /// Ask a doubt about the current lesson — returns AI response
  static Future<String> askDoubt({
    required String question,
    required String lessonTitle,
    required String courseTitle,
    List<ChatMessage> history = const [],
  }) async {
    if (!ApiConfig.isConfigured) {
      return 'Please configure your Gemini API key in api_config.dart to use AI features.';
    }

    final historyText = history.map((m) {
      final role = m.isUser ? 'Student' : 'AI Tutor';
      return '$role: ${m.text}';
    }).join('\n');

    final prompt = '''
You are an AI tutor helping a student learn. Be concise, friendly, and use examples.

Context:
- Course: $courseTitle
- Current Lesson: $lessonTitle

${historyText.isNotEmpty ? 'Previous conversation:\n$historyText\n' : ''}
Student's question: $question

Provide a clear, helpful answer. Use bullet points or code examples when relevant. Keep it under 200 words.
''';

    try {
      final response = await _callGemini(prompt);
      return response ?? 'Sorry, I could not process your question. Please try again.';
    } catch (_) {
      return 'Something went wrong. Please check your internet connection and try again.';
    }
  }

  /// Generate a complete learning path from a dream/goal
  static Future<Course?> generateLearningPath({
    required String dream,
  }) async {
    if (!ApiConfig.isConfigured) return null;

    final prompt = '''
You are an expert curriculum designer. A student wants to achieve this goal: "$dream"

Create a structured learning path using FREE YouTube content. Design a course with:
- A clear, catchy course title
- A compelling description (2 sentences)
- An appropriate category (e.g., "Machine Learning", "Web Development", "Data Science", "Mobile Development", "Cloud & DevOps", "Computer Science")
- 3-4 modules, each with 4-6 lessons
- Each lesson should reference a REAL, popular YouTube video (provide a realistic video ID)
- Include estimated durations

Return ONLY valid JSON (no markdown, no code fences):
{
  "id": "generated_001",
  "title": "Course Title Here",
  "description": "Course description here.",
  "category": "Category Name",
  "thumbnail_url": "https://img.youtube.com/vi/VIDEO_ID/maxresdefault.jpg",
  "rating": 4.7,
  "learner_count": 0,
  "total_lessons": 18,
  "completed_lessons": 0,
  "estimated_time": "8 weeks",
  "skills": ["Skill1", "Skill2", "Skill3", "Skill4"],
  "modules": [
    {
      "id": "gen_mod_001",
      "title": "Module Title",
      "lesson_count": 5,
      "completed_count": 0,
      "is_locked": false,
      "lessons": [
        {
          "id": "gen_les_001",
          "title": "Lesson Title",
          "youtube_video_id": "dQw4w9WgXcQ",
          "duration": "15:30",
          "is_completed": false,
          "chapters": [
            {"title": "Introduction", "timestamp": "0:00"},
            {"title": "Core Concepts", "timestamp": "5:00"}
          ]
        }
      ]
    }
  ]
}

Important: Use realistic YouTube video IDs from well-known educational channels (3Blue1Brown, freeCodeCamp, Traversy Media, Sentdex, Corey Schafer, etc.). Make the first module unlocked, rest locked.
''';

    try {
      final response = await _callGemini(prompt);
      if (response == null) return null;

      final jsonStr = _extractJson(response);
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      return Course.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Core Gemini API call
  static Future<String?> _callGemini(String prompt) async {
    final url = Uri.parse(
      '${ApiConfig.geminiBaseUrl}/${ApiConfig.geminiModel}:generateContent?key=${ApiConfig.geminiApiKey}',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 4096,
      },
    });

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] as String?;
        }
      }
    }
    return null;
  }

  /// Extract JSON from a response that might contain markdown code fences
  static String _extractJson(String text) {
    // Remove markdown code fences if present
    var cleaned = text.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }
}
