import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'api_config.dart';

/// Multi-provider AI Service
/// Uses different free APIs for different tasks to stay within limits
class GeminiService {
  
  // ── Quiz Generation — use Gemini Flash (fast + free) ────────────────────
  static Future<List<QuizQuestion>> generateQuiz({
    required String lessonTitle,
    required String courseTitle,
    required String topic,
    int count = 5,
  }) async {
    if (!ApiConfig.isConfigured) {
      return QuizQuestion.mockQuestions();
    }

    final prompt = '''You are an expert educator creating quiz questions.
Course: $courseTitle
Lesson: $lessonTitle  
Topic: $topic

Generate EXACTLY 5 multiple-choice quiz questions testing deep understanding.

Return ONLY valid JSON array (no markdown):
[{"id":"q_1","question":"...?","options":["A","B","C","D"],"correct_index":0,"explanation":"..."}]''';

    try {
      final response = await _callWithRetry(prompt, maxTokens: 2048);
      if (response == null) return QuizQuestion.mockQuestions();
      final jsonStr = extractJson(response);
      final List<dynamic> data = jsonDecode(jsonStr);
      final questions = data.map((j) => QuizQuestion.fromJson(j)).toList();
      return questions.isNotEmpty ? questions : QuizQuestion.mockQuestions();
    } catch (e) {
      debugPrint('[AI] Quiz error: $e');
      return QuizQuestion.mockQuestions();
    }
  }

  // ── Doubt Resolution — conversational AI ────────────────────────────────
  static Future<String> askDoubt({
    required String question,
    required String lessonTitle,
    required String courseTitle,
    List<ChatMessage> history = const [],
  }) async {
    if (!ApiConfig.isConfigured) {
      return 'Please add GEMINI_API_KEY to your .env file to enable AI features.';
    }

    final historyText = history.takeLast(6).map((m) {
      return '${m.isUser ? "Student" : "Tutor"}: ${m.text}';
    }).join('\n');

    final prompt = '''You are a friendly AI tutor. Be concise and helpful.
Course: $courseTitle | Lesson: $lessonTitle
${historyText.isNotEmpty ? "History:\n$historyText\n" : ""}
Student: $question

Give a clear answer under 150 words. Use examples when helpful.''';

    try {
      final response = await _callWithRetry(prompt, maxTokens: 512);
      return response ?? 'Sorry, I could not answer that. Please try again.';
    } catch (e) {
      return 'Connection error. Please check your internet and try again.';
    }
  }

  // ── Learning Path Generation — primary feature ───────────────────────────
  static Future<Course?> generateLearningPath({required String dream}) async {
    if (!ApiConfig.isConfigured) return null;

    final prompt = '''You are a curriculum designer. Goal: "$dream"

Create a structured YouTube-based learning course. Return ONLY valid JSON:
{
  "id": "gen_${DateTime.now().millisecondsSinceEpoch}",
  "title": "Complete [Topic] Course",
  "description": "Two sentence description of what students will learn.",
  "category": "Machine Learning",
  "thumbnail_url": "https://img.youtube.com/vi/aircAruvnKk/maxresdefault.jpg",
  "rating": 4.7,
  "learner_count": 1234,
  "total_lessons": 20,
  "completed_lessons": 0,
  "estimated_time": "8 weeks",
  "skills": ["Skill1", "Skill2", "Skill3"],
  "modules": [
    {
      "id": "mod_1",
      "title": "Module Title",
      "lesson_count": 5,
      "completed_count": 0,
      "is_locked": false,
      "lessons": [
        {
          "id": "les_1",
          "title": "Lesson Title",
          "youtube_video_id": "aircAruvnKk",
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

Rules:
- Use REAL YouTube video IDs from: 3Blue1Brown(aircAruvnKk), freeCodeCamp(rfscVS0vtbw), Traversy(nu_pCVPKzTk), Fireship(DHjqpvDnNGE), Sentdex(7eh4d6sabA0), Corey Schafer(YYXdXT2l7Tc), TechWithTim(nLRL_NcnK-4)
- First module: is_locked: false. Rest: is_locked: true
- 3-4 modules, 4-6 lessons each
- Total lessons should match sum of module lesson counts''';

    try {
      final response = await _callWithRetry(prompt, maxTokens: 4096, temperature: 0.3);
      if (response == null) return null;
      final jsonStr = extractJson(response);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final course = Course.fromJson(data);
      // Validate course has modules
      if (course.modules.isEmpty) return null;
      return course;
    } catch (e) {
      debugPrint('[AI] Course gen error: $e');
      return null;
    }
  }

  // ── Daily Recommendations ─────────────────────────────────────────────────
  static Future<List<Map<String, String>>> generateRecommendations({
    required String? dream,
    required List<String> categories,
  }) async {
    if (!ApiConfig.isConfigured) return _mockRecommendations();

    final context = [dream, ...categories].where((s) => s != null && s!.isNotEmpty).join(', ');
    
    final prompt = '''Recommend 8 educational YouTube videos for someone learning: $context

Return ONLY valid JSON array:
[
  {
    "title": "Video Title",
    "channel": "Channel Name", 
    "video_id": "realVideoId",
    "duration": "15:30",
    "category": "Category",
    "description": "One line why this is valuable"
  }
]

Use REAL video IDs. Mix difficulty levels. Prioritize channels: freeCodeCamp, 3Blue1Brown, Fireship, Traversy Media, The Coding Train, Veritasium, Khan Academy.''';

    try {
      final response = await _callWithRetry(prompt, maxTokens: 2048);
      if (response == null) return _mockRecommendations();
      final jsonStr = extractJson(response);
      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((j) => Map<String, String>.from(j)).toList();
    } catch (e) {
      return _mockRecommendations();
    }
  }

  // ── Core API call with retry & timeout ───────────────────────────────────
  static Future<String?> _callWithRetry(
    String prompt, {
    int maxTokens = 2048,
    double temperature = 0.7,
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final result = await callGemini(
          prompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
        if (result != null) return result;
        
        // Wait before retry
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      } catch (e) {
        debugPrint('[AI] Attempt ${attempt + 1} failed: $e');
        if (attempt == maxRetries - 1) rethrow;
      }
    }
    return null;
  }

  // ── Public Gemini REST call ────────────────────────────────────────────
  static Future<String?> callGemini(
    String prompt, {
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.geminiBaseUrl}/${ApiConfig.geminiModel}:generateContent?key=${ApiConfig.geminiApiKey}',
    );

    final body = jsonEncode({
      'contents': [{'parts': [{'text': prompt}]}],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        'topP': 0.8,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
      ],
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 45));

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
      
      // Check for safety filter
      final promptFeedback = data['promptFeedback'];
      if (promptFeedback != null) {
        debugPrint('[AI] Prompt blocked: $promptFeedback');
      }
    } else {
      debugPrint('[AI] HTTP ${response.statusCode}: ${response.body.substring(0, 200)}');
      
      // Handle quota exceeded
      if (response.statusCode == 429) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }
    return null;
  }

  static String extractJson(String text) {
    var cleaned = text.trim();
    // Remove markdown code fences
    cleaned = cleaned.replaceAll(RegExp(r'```json\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '');
    
    // Find first [ or {
    final arrayStart = cleaned.indexOf('[');
    final objStart = cleaned.indexOf('{');
    
    if (arrayStart == -1 && objStart == -1) return cleaned;
    
    if (arrayStart != -1 && (objStart == -1 || arrayStart < objStart)) {
      final end = cleaned.lastIndexOf(']');
      if (end != -1) return cleaned.substring(arrayStart, end + 1);
    } else {
      final end = cleaned.lastIndexOf('}');
      if (end != -1) return cleaned.substring(objStart, end + 1);
    }
    
    return cleaned;
  }

  static List<Map<String, String>> _mockRecommendations() => [
    {'title': 'Neural Networks Explained', 'channel': '3Blue1Brown', 'video_id': 'aircAruvnKk', 'duration': '19:13', 'category': 'AI & ML', 'description': 'Beautiful visual explanation of neural networks'},
    {'title': 'JavaScript in 100 Seconds', 'channel': 'Fireship', 'video_id': 'DHjqpvDnNGE', 'duration': '2:17', 'category': 'Web Dev', 'description': 'Quick JS overview'},
    {'title': 'Learn Python - Full Course', 'channel': 'freeCodeCamp', 'video_id': 'rfscVS0vtbw', 'duration': '4:26:51', 'category': 'Python', 'description': 'Complete Python for beginners'},
    {'title': 'React JS Crash Course', 'channel': 'Traversy Media', 'video_id': 'sBws8MSXN7A', 'duration': '1:48:42', 'category': 'React', 'description': 'Build React apps from scratch'},
    {'title': 'Flutter Tutorial for Beginners', 'channel': 'Net Ninja', 'video_id': '1ukSR1GRtMU', 'duration': '15:04', 'category': 'Mobile', 'description': 'Start building Flutter apps'},
    {'title': 'CSS Grid in 20 Minutes', 'channel': 'Traversy Media', 'video_id': 'jV8B24rSN5o', 'duration': '28:05', 'category': 'CSS', 'description': 'Master CSS Grid layout'},
    {'title': 'TypeScript Full Course', 'channel': 'Jack Herrington', 'video_id': 'TNCoGHB7wqY', 'duration': '2:57:17', 'category': 'TypeScript', 'description': 'Complete TypeScript guide'},
    {'title': 'System Design Interview', 'channel': 'ByteByteGo', 'video_id': 'm8Icp_Cid5o', 'duration': '7:38', 'category': 'Architecture', 'description': 'Design scalable systems'},
  ];
}

extension ListExtension<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
