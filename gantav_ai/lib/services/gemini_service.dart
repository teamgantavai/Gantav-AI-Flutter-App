import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'api_config.dart';
import 'youtube_api_service.dart';

/// Multi-provider AI Service with automatic fallback and performance optimizations.
class GeminiService {
  static final Map<AIProvider, DateTime> _rateLimitExpirations = {};

  static bool _isRateLimited(AIProvider provider) {
    if (!_rateLimitExpirations.containsKey(provider)) return false;
    if (DateTime.now().isAfter(_rateLimitExpirations[provider]!)) {
      _rateLimitExpirations.remove(provider);
      return false;
    }
    return true;
  }

  static void _setRateLimited(AIProvider provider) {
    debugPrint('[AI] ! ${provider.name} rate limited. Cooling down for 1 min.');
    _rateLimitExpirations[provider] =
        DateTime.now().add(const Duration(minutes: 1));
  }

  // ── Quiz Generation ──────────────────────────────────────────────────────
  static Future<List<QuizQuestion>> generateQuiz({
    required String lessonTitle,
    required String courseTitle,
    required String topic,
    int count = 5,
  }) async {
    if (!ApiConfig.isConfigured) return QuizQuestion.mockQuestions();

    final prompt =
        'Generate 5 MCQ quiz questions for lesson: "$lessonTitle" (Course: "$courseTitle").\n'
        'Return ONLY JSON array, no markdown:\n'
        '[{"id":"q_1","question":"...?","options":["A","B","C","D"],"correct_index":0,"explanation":"..."}]';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.courseGeneration,
        maxTokens: 1500,
      );
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

  // ── Doubt Resolution ─────────────────────────────────────────────────────
  static Future<String> askDoubt({
    required String question,
    required String lessonTitle,
    required String courseTitle,
    List<ChatMessage> history = const [],
  }) async {
    if (!ApiConfig.isConfigured) {
      return 'Please add at least one AI API key to your .env file.';
    }

    final historyText = history.takeLast(4).map((m) {
      return '${m.isUser ? "Student" : "Tutor"}: ${m.text}';
    }).join('\n');

    final prompt =
        'You are a helpful tutor. Course: "$courseTitle" | Lesson: "$lessonTitle"\n'
        '${historyText.isNotEmpty ? "History:\n$historyText\n" : ""}'
        'Student: $question\n'
        'Give a clear, concise answer (max 120 words). Use examples if helpful.';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.chat,
        maxTokens: 400,
      );
      return response ?? 'Sorry, I could not answer that. Please try again.';
    } catch (e) {
      return 'Connection error. Please check your internet and try again.';
    }
  }

  // ── Learning Path Generation ─────────────────────────────────────────────
  /// Generates a course with the ACTUAL course name in the title (no $dream placeholder).
  static Future<Course?> generateLearningPath({
    required String dream,
    List<YouTubeVideoStats>? preFilteredVideos,
  }) async {
    if (!ApiConfig.isConfigured) return null;

    // Clean the dream/topic to extract the actual course name
    final courseName = _extractCourseName(dream);
    final courseCategory = _extractCategory(dream);

    String videoContext = '';
    String firstVideoId = '';
    if (preFilteredVideos != null && preFilteredVideos.isNotEmpty) {
      final topVideos = preFilteredVideos.take(9).toList();
      if (topVideos.isNotEmpty) firstVideoId = topVideos.first.id;
      videoContext =
          'Use ONLY these verified YouTube videos (pick the most relevant for each lesson):\n'
          '${topVideos.map((v) => '- ID:${v.id} Title:"${v.title}" Duration:${v.durationText} Channel:${v.channelTitle}').join('\n')}\n';
    }

    // Generate unique module descriptions based on the course topic
    final moduleTopics = _generateModuleTopics(courseName);

    final prompt =
        'Create a complete learning course for: "$courseName"\n'
        '$videoContext'
        'IMPORTANT: The course title MUST be exactly "$courseName" - do NOT use any placeholder like \$dream.\n'
        'Return ONLY valid JSON (no markdown backticks, no extra text):\n'
        '{\n'
        '  "id": "gen_${DateTime.now().millisecondsSinceEpoch}",\n'
        '  "title": "$courseName",\n'
        '  "description": "A comprehensive course covering all aspects of ${courseName.toLowerCase()}",\n'
        '  "category": "$courseCategory",\n'
        '  "thumbnail_url": "${firstVideoId.isNotEmpty ? "https://img.youtube.com/vi/$firstVideoId/maxresdefault.jpg" : "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"}",\n'
        '  "total_lessons": 9,\n'
        '  "rating": 4.8,\n'
        '  "learner_count": 0,\n'
        '  "skills": ["${moduleTopics[0]}", "${moduleTopics[1]}", "${moduleTopics[2]}"],\n'
        '  "modules": [\n'
        '    {"id":"mod_1","title":"${moduleTopics[0]}","lesson_count":3,"is_locked":false,"lessons":[\n'
        '      {"id":"les_1","title":"Introduction to ${courseName}","youtube_video_id":"VIDEO_ID_FROM_LIST","duration":"15:00","chapters":[{"title":"Overview","timestamp":"0:00"}]},\n'
        '      {"id":"les_2","title":"Core ${moduleTopics[0]} Concepts","youtube_video_id":"VIDEO_ID_FROM_LIST","duration":"18:00"},\n'
        '      {"id":"les_3","title":"${moduleTopics[0]} in Practice","youtube_video_id":"VIDEO_ID_FROM_LIST","duration":"20:00"}\n'
        '    ]},\n'
        '    {"id":"mod_2","title":"${moduleTopics[1]}","lesson_count":3,"is_locked":true,"lessons":[\n'
        '      {"id":"les_4","title":"${moduleTopics[1]} Fundamentals","youtube_video_id":"VIDEO_ID_FROM_LIST","duration":"22:00"},\n'
        '      {"id":"les_5","title":"Advanced ${moduleTopics[1]}","youtube_video_id":"VIDEO_ID_FROM_LIST","duration":"25:00"},\n'
        '      {"id":"les_6","title":"${moduleTopics[1]} Projects","youtube_video_id":"VIDEO_ID_FROM_LIST","duration":"19:00"}\n'
        '    ]},\n'
        '    {"id":"mod_3","title":"${moduleTopics[2]}","lesson_count":3,"is_locked":true,"lessons":[\n'
        '      {"id":"les_7","title":"${moduleTopics[2]} Deep Dive","youtube_video_id":"VIDEO_ID_FROM_LIST","duration":"23:00"},\n'
        '      {"id":"les_8","title":"Real-world ${moduleTopics[2]}","youtube_video_id":"VIDEO_ID_FROM_LIST","duration":"27:00"},\n'
        '      {"id":"les_9","title":"Final ${courseName} Project","youtube_video_id":"VIDEO_ID_FROM_LIST","duration":"35:00"}\n'
        '    ]}\n'
        '  ]\n'
        '}\n\n'
        'Rules:\n'
        '1. Replace each VIDEO_ID_FROM_LIST with a REAL YouTube video ID from the provided list above.\n'
        '2. Match video IDs to lesson topics (most relevant video for each lesson).\n'
        '3. Keep the title EXACTLY as "$courseName".\n'
        '4. Each module must have a UNIQUE title describing a different aspect of $courseName.\n'
        '5. Module 1 is_locked:false, modules 2 and 3 is_locked:true.';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.courseGeneration,
        maxTokens: 2500,
        temperature: 0.2,
      );
      if (response == null) return null;

      final jsonStr = extractJson(response);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Ensure title never contains $dream
      if (data['title'] == null || 
          (data['title'] as String).contains('\$dream') || 
          (data['title'] as String).trim().isEmpty) {
        data['title'] = courseName;
      }
      if (data['category'] == null || (data['category'] as String).trim().isEmpty) {
        data['category'] = courseCategory;
      }
      
      return Course.fromJson(data);
    } catch (e) {
      debugPrint('[AI] Course gen error: $e');
      return null;
    }
  }

  /// Extract a clean course name from the prompt
  static String _extractCourseName(String dream) {
    // Remove common prefix patterns
    var name = dream
        .replaceAll(RegExp(r'I want to learn:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'in \w+ language.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'taught by.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'with videos from.*', caseSensitive: false), '')
        .trim();
    
    // Capitalize first letter of each word
    if (name.isEmpty) return 'Complete Programming Course';
    return name;
  }

  /// Extract category from course name
  static String _extractCategory(String dream) {
    final lower = dream.toLowerCase();
    if (lower.contains('python') || lower.contains('programming')) return 'Programming';
    if (lower.contains('flutter') || lower.contains('mobile') || lower.contains('android') || lower.contains('ios')) return 'Mobile Development';
    if (lower.contains('react') || lower.contains('web') || lower.contains('html') || lower.contains('css') || lower.contains('javascript')) return 'Web Development';
    if (lower.contains('machine learning') || lower.contains('ai') || lower.contains('deep learning')) return 'AI & ML';
    if (lower.contains('data')) return 'Data Science';
    if (lower.contains('cloud') || lower.contains('aws') || lower.contains('devops')) return 'Cloud & DevOps';
    if (lower.contains('design') || lower.contains('ui') || lower.contains('ux')) return 'Design';
    if (lower.contains('game')) return 'Game Development';
    if (lower.contains('cyber') || lower.contains('security')) return 'Cybersecurity';
    if (lower.contains('blockchain') || lower.contains('web3')) return 'Blockchain';
    return 'Technology';
  }

  /// Generate unique module topic names for a course
  static List<String> _generateModuleTopics(String courseName) {
    final lower = courseName.toLowerCase();
    
    if (lower.contains('python')) {
      return ['Python Fundamentals', 'Data Structures & OOP', 'Advanced Python & Projects'];
    }
    if (lower.contains('flutter') || lower.contains('mobile')) {
      return ['Flutter Basics & Dart', 'Widgets & State Management', 'Firebase & Deployment'];
    }
    if (lower.contains('react')) {
      return ['React Fundamentals', 'Hooks & State', 'Full-Stack Integration'];
    }
    if (lower.contains('machine learning') || lower.contains('ml')) {
      return ['ML Foundations', 'Supervised Learning', 'Deep Learning & Projects'];
    }
    if (lower.contains('web')) {
      return ['HTML & CSS Basics', 'JavaScript & DOM', 'Backend & Deployment'];
    }
    if (lower.contains('data science')) {
      return ['Python & Pandas', 'Data Visualization', 'Statistical Analysis & ML'];
    }
    if (lower.contains('cloud') || lower.contains('aws')) {
      return ['Cloud Fundamentals', 'Core Services & Architecture', 'DevOps & CI/CD'];
    }
    if (lower.contains('game')) {
      return ['Game Engine Basics', 'Game Mechanics & Physics', 'Advanced Game Systems'];
    }
    if (lower.contains('design') || lower.contains('ui')) {
      return ['Design Principles', 'Figma & Prototyping', 'Design Systems & Case Studies'];
    }
    // Generic fallback
    final cleanName = courseName.replaceAll(RegExp(r'(Complete|Course|Basics|Fundamentals)', caseSensitive: false), '').trim();
    return [
      '$cleanName Foundations',
      'Intermediate $cleanName',
      'Advanced $cleanName & Projects',
    ];
  }

  // ── Daily Recommendations ─────────────────────────────────────────────────
  static Future<List<Map<String, String>>> generateRecommendations({
    required String? dream,
    required List<String> categories,
    int page = 0,
  }) async {
    if (!ApiConfig.isConfigured) return _mockRecommendations();

    final context =
        [dream, ...categories].where((s) => s != null && s.isNotEmpty).join(', ');

    final prompt =
        'Recommend 6 educational YouTube videos for: "$context" (page $page, vary content).\n'
        'Return ONLY JSON array:\n'
        '[{"title":"Title","channel":"Channel","video_id":"realId","duration":"15:30","category":"Cat","description":"Why valuable"}]\n'
        'Use REAL video IDs. Prioritize: freeCodeCamp, 3Blue1Brown, Fireship, Traversy Media.';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.recommendations,
        maxTokens: 1200,
      );
      if (response == null) return _mockRecommendations();
      final jsonStr = extractJson(response);
      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((j) => Map<String, String>.from(j)).toList();
    } catch (e) {
      return _mockRecommendations();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SMART ROUTING ENGINE
  // ═══════════════════════════════════════════════════════════════════════

  static Future<String?> _smartCall(
    String prompt, {
    required AITask task,
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    AIProvider? provider = ApiConfig.primaryProvider(task);

    int attempts = 0;
    const maxAttempts = 3;

    while (provider != null && attempts < maxAttempts) {
      if (_isRateLimited(provider)) {
        provider = ApiConfig.fallbackAfter(provider);
        continue;
      }

      attempts++;
      try {
        debugPrint('[AI] Trying ${provider.name} for ${task.name}...');
        final result = await _callProviderWithBackoff(
          provider,
          prompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
        if (result != null) {
          debugPrint('[AI] ✓ ${provider.name} responded');
          return result;
        }
      } catch (e) {
        debugPrint('[AI] ✗ ${provider.name} failed: $e');
      }

      provider = ApiConfig.fallbackAfter(provider);
      if (provider != null) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    debugPrint('[AI] All providers exhausted for: ${task.name}');
    return null;
  }

  static Future<String?> _callProviderWithBackoff(
    AIProvider provider,
    String prompt, {
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    int attempts = 0;
    const maxRetries = 2;

    while (attempts < maxRetries) {
      attempts++;
      try {
        return await _callProvider(provider, prompt,
            maxTokens: maxTokens, temperature: temperature);
      } catch (e) {
        final errorString = e.toString();
        if (errorString.contains('Rate limited') || errorString.contains('429')) {
          if (attempts >= maxRetries) {
            _setRateLimited(provider);
            rethrow;
          }
          await Future.delayed(Duration(seconds: attempts));
        } else {
          rethrow;
        }
      }
    }
    return null;
  }

  static Future<String?> _callProvider(
    AIProvider provider,
    String prompt, {
    int maxTokens = 1500,
    double temperature = 0.7,
  }) {
    switch (provider) {
      case AIProvider.gemini:
        return _callGemini(prompt, maxTokens: maxTokens, temperature: temperature);
      case AIProvider.groq:
        return _callGroq(prompt, maxTokens: maxTokens, temperature: temperature);
      case AIProvider.openRouter:
        return _callOpenRouter(prompt, maxTokens: maxTokens, temperature: temperature);
    }
  }

  // ── 1. Google Gemini ─────────────────────────────────────────────────────
  static Future<String?> _callGemini(
    String prompt, {
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
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
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        'topP': 0.8,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
      ],
    });

    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        if (content != null) {
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String?;
          }
        }
      }
    } else {
      debugPrint('[Gemini] API status ${response.statusCode}');
      if (response.statusCode == 429) throw Exception('Rate limited');
      if (response.statusCode >= 500) throw Exception('Server error');
    }
    return null;
  }

  // ── 2. Groq ───────────────────────────────────────────────────────────────
  static Future<String?> _callGroq(
    String prompt, {
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    final url = Uri.parse(ApiConfig.groqBaseUrl);

    final body = jsonEncode({
      'model': ApiConfig.groqModel,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
      'top_p': 0.8,
    });

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${ApiConfig.groqApiKey}',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String?;
      }
    } else {
      debugPrint('[Groq] API status ${response.statusCode}');
      if (response.statusCode == 429) throw Exception('Rate limited');
    }
    return null;
  }

  // ── 3. OpenRouter ─────────────────────────────────────────────────────────
  static Future<String?> _callOpenRouter(
    String prompt, {
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    final url = Uri.parse(ApiConfig.openRouterBaseUrl);

    final body = jsonEncode({
      'model': ApiConfig.openRouterModel,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
      'top_p': 0.8,
    });

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${ApiConfig.openRouterApiKey}',
            'HTTP-Referer': 'https://gantavai.com',
            'X-Title': 'Gantav AI Learning',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String?;
      }
    } else {
      debugPrint('[OpenRouter] API status ${response.statusCode}');
      if (response.statusCode == 429) throw Exception('Rate limited');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════

  static Future<String?> callAI(
    String prompt, {
    required AITask task,
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    return _smartCall(prompt, task: task, maxTokens: maxTokens, temperature: temperature);
  }

  static Future<String?> callGemini(String prompt) =>
      callAI(prompt, task: AITask.courseGeneration);

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  static String extractJson(String text) {
    try {
      var cleaned = text.trim();
      if (cleaned.contains('```json')) {
        cleaned = cleaned.split('```json')[1].split('```')[0].trim();
      } else if (cleaned.contains('```')) {
        cleaned = cleaned.split('```')[1].split('```')[0].trim();
      }

      final arrayStart = cleaned.indexOf('[');
      final objStart = cleaned.indexOf('{');

      if (arrayStart == -1 && objStart == -1) return cleaned;

      if (objStart != -1 && (arrayStart == -1 || objStart < arrayStart)) {
        final end = cleaned.lastIndexOf('}');
        return cleaned.substring(objStart, end + 1);
      } else {
        final end = cleaned.lastIndexOf(']');
        return cleaned.substring(arrayStart, end + 1);
      }
    } catch (e) {
      return text;
    }
  }

  static List<Map<String, String>> _mockRecommendations() => [
        {
          'title': 'Neural Networks Explained',
          'channel': '3Blue1Brown',
          'video_id': 'aircAruvnKk',
          'duration': '19:13',
          'category': 'AI & ML',
          'description': 'Beautiful visual explanation of neural networks'
        },
        {
          'title': 'JavaScript in 100 Seconds',
          'channel': 'Fireship',
          'video_id': 'DHjqpvDnNGE',
          'duration': '2:17',
          'category': 'Web Dev',
          'description': 'Quick JS overview'
        },
        {
          'title': 'Learn Python - Full Course',
          'channel': 'freeCodeCamp',
          'video_id': 'rfscVS0vtbw',
          'duration': '4:26:51',
          'category': 'Python',
          'description': 'Complete Python for beginners'
        },
        {
          'title': 'React JS Crash Course',
          'channel': 'Traversy Media',
          'video_id': 'sBws8MSXN7A',
          'duration': '1:48:42',
          'category': 'React',
          'description': 'Build React apps from scratch'
        },
        {
          'title': 'Flutter Tutorial for Beginners',
          'channel': 'Net Ninja',
          'video_id': '1ukSR1GRtMU',
          'duration': '15:04',
          'category': 'Mobile',
          'description': 'Start building Flutter apps'
        },
        {
          'title': 'CSS Grid in 20 Minutes',
          'channel': 'Traversy Media',
          'video_id': '3Xc3CA655Y4',
          'duration': '28:05',
          'category': 'CSS',
          'description': 'Master CSS Grid layout'
        },
      ];
}

extension ListExtension<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}