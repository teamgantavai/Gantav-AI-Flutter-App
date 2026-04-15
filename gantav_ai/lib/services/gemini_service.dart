import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'api_config.dart';
import 'youtube_api_service.dart';

/// Multi-provider AI Service with automatic fallback.
///
/// Provider chain:
///   1. Try the best provider for the task type
///   2. On failure (429/5xx/timeout), fall back to next provider
///   3. If all fail, return mock data
///
/// Task routing:
///   • JSON tasks (courses, quizzes, recs) → Gemini first (best at structured output)
///   • Chat tasks (doubt resolution)     → Groq first (fastest inference)
class GeminiService {
  /// Track rate-limited providers to skip them temporarily
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
    _rateLimitExpirations[provider] = DateTime.now().add(const Duration(minutes: 1));
  }


  // ── Quiz Generation ────────────────────────────────────────────────────────
  static Future<List<QuizQuestion>> generateQuiz({
    required String lessonTitle,
    required String courseTitle,
    required String topic,
    int count = 5,
  }) async {
    if (!ApiConfig.isConfigured) return QuizQuestion.mockQuestions();

    final prompt = '''You are an expert educator creating quiz questions.
Course: $courseTitle
Lesson: $lessonTitle  
Topic: $topic

Generate EXACTLY 5 multiple-choice quiz questions testing deep understanding.

Return ONLY valid JSON array (no markdown):
[{"id":"q_1","question":"...?","options":["A","B","C","D"],"correct_index":0,"explanation":"..."}]''';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.courseGeneration,
        maxTokens: 2048,
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

  // ── Doubt Resolution — conversational AI ──────────────────────────────────
  static Future<String> askDoubt({
    required String question,
    required String lessonTitle,
    required String courseTitle,
    List<ChatMessage> history = const [],
  }) async {
    if (!ApiConfig.isConfigured) {
      return 'Please add at least one AI API key (GEMINI_API_KEY, GROQ_API_KEY, or OPENROUTER_API_KEY) to your .env file.';
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
      final response = await _smartCall(
        prompt,
        task: AITask.chat,
        maxTokens: 512,
      );
      return response ?? 'Sorry, I could not answer that. Please try again.';
    } catch (e) {
      return 'Connection error. Please check your internet and try again.';
    }
  }

  // ── Learning Path Generation ──────────────────────────────────────────────
  static Future<Course?> generateLearningPath({
    required String dream,
    List<YouTubeVideoStats>? preFilteredVideos,
  }) async {
    if (!ApiConfig.isConfigured) return null;

    String verifiedVideosContext = '';
    if (preFilteredVideos != null && preFilteredVideos.isNotEmpty) {
      // Pass stats AND comments to the AI so it can judge quality without making 10 separate calls
      verifiedVideosContext = 'IMPORTANT: Construct the course using ONLY these highly-rated videos. Read their top comments to determine if they are beginner or advanced:\n' +
          preFilteredVideos.map((v) => '''
- ID: ${v.id}
  Title: "${v.title}"
  Duration: ${v.durationText}
  Engagement: ${v.engagementRatio}%
  Comments: ${v.topComments.take(3).join(" | ")}
''').join('\n');
    }

    final prompt = '''You are an expert curriculum designer. Goal: "$dream"
Create a structured learning course. Return ONLY valid JSON. Do not include markdown formatting like ```json.

Rules:
$verifiedVideosContext
- First module is_locked: false. Rest: true.
- Max 3 modules, 3-4 lessons each to keep it concise.

{
  "id": "gen_1",
  "title": "Complete Course",
  "description": "Short description.",
  "category": "Technology",
  "thumbnail_url": "https://img.youtube.com/vi/[FirstVideoId]/maxresdefault.jpg",
  "total_lessons": 10,
  "modules": [
    {
      "id": "mod_1",
      "title": "Basics",
      "lesson_count": 3,
      "is_locked": false,
      "lessons": [
        {
          "id": "les_1",
          "title": "Lesson Title",
          "youtube_video_id": "real_video_id",
          "duration": "15:30",
          "chapters": [{"title": "Intro", "timestamp": "0:00"}]
        }
      ]
    }
  ]
}''';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.courseGeneration,
        maxTokens: 3000, // Reduced to prevent timeout
        temperature: 0.2, // Lower temperature means stricter JSON formatting
      );
      if (response == null) return null;
      
      final jsonStr = extractJson(response);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      return Course.fromJson(data);
    } catch (e) {
      debugPrint('[AI] Course gen error: $e');
      return null;
    }
  }

  // ── Daily Recommendations ─────────────────────────────────────────────────
  static Future<List<Map<String, String>>> generateRecommendations({
    required String? dream,
    required List<String> categories,
    int page = 0,
  }) async {
    if (!ApiConfig.isConfigured) return _mockRecommendations();

    final context = [dream, ...categories]
        .where((s) => s != null && s!.isNotEmpty)
        .join(', ');

    final prompt = '''Recommend 8 educational YouTube videos for someone learning: $context
    
This is Page $page of recommendations. Ensure you do not repeat obvious or introductory suggestions. Provide diverse and deeper content since the user is paginating.

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

Use REAL video IDs. Mix difficulty levels based on the page depth. Prioritize channels: freeCodeCamp, 3Blue1Brown, Fireship, Traversy Media, The Coding Train, Veritasium, Khan Academy.''';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.recommendations,
        maxTokens: 2048,
      );
      if (response == null) return _mockRecommendations();
      final jsonStr = extractJson(response);
      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((j) => Map<String, String>.from(j)).toList();
    } catch (e) {
      return _mockRecommendations();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SMART ROUTING ENGINE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calls the best provider for the task, automatically falling back on error.
  static Future<String?> _smartCall(
    String prompt, {
    required AITask task,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    // Pick the best starting provider based on task type
    AIProvider? provider = ApiConfig.primaryProvider(task);

    int attempts = 0;
    const maxAttempts = 3;

    while (provider != null && attempts < maxAttempts) {
      if (_isRateLimited(provider)) {
        debugPrint('[AI] Skipping ${provider.name} (cooling down)');
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
          debugPrint('[AI] ✓ ${provider.name} responded successfully');
          return result;
        }
      } catch (e) {
        debugPrint('[AI] ✗ ${provider.name} failed: $e');
      }

      // Try next fallback
      provider = ApiConfig.fallbackAfter(provider);
      if (provider != null) {
        debugPrint('[AI] → Falling back to ${provider.name}');
        // Subtle delay before fallback
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    debugPrint('[AI] All providers exhausted for task: ${task.name}');
    return null;
  }

  /// Dispatches to the correct provider implementation with exponential backoff on rate limits
  static Future<String?> _callProviderWithBackoff(
    AIProvider provider,
    String prompt, {
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    int attempts = 0;
    const maxRetries = 3;

    while (attempts < maxRetries) {
      attempts++;
      try {
        return await _callProvider(
          provider,
          prompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      } catch (e) {
        final errorString = e.toString();
        if (errorString.contains('Rate limited') || errorString.contains('429')) {
          if (attempts >= maxRetries) {
            debugPrint('[AI] ${provider.name} rate limited after $maxRetries attempts.');
            _setRateLimited(provider);
            rethrow;
          }
          final delaySeconds = 2 * attempts; // e.g., 2s, 4s
          debugPrint('[AI] ${provider.name} rate limited. Retrying in ${delaySeconds}s (Attempt $attempts/$maxRetries)...');
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Dispatches to the correct provider implementation
  static Future<String?> _callProvider(
    AIProvider provider,
    String prompt, {
    int maxTokens = 2048,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PROVIDER IMPLEMENTATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  // ── 1. Google Gemini ──────────────────────────────────────────────────────
  static Future<String?> _callGemini(
    String prompt, {
    int maxTokens = 2048,
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
        .timeout(const Duration(seconds: 45));

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
      if (response.statusCode == 429) {
        throw Exception('Rate limited');
      }
      if (response.statusCode >= 500) {
        throw Exception('Server error');
      }
    }
    return null;
  }

  // ── 2. Groq (OpenAI-compatible) ───────────────────────────────────────────
  static Future<String?> _callGroq(
    String prompt, {
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    final url = Uri.parse(ApiConfig.groqBaseUrl);

    final body = jsonEncode({
      'model': ApiConfig.groqModel,
      'messages': [
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
      'top_p': 0.8,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${ApiConfig.groqApiKey}',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String?;
      }
    } else {
      debugPrint('[Groq] API status ${response.statusCode}');
      if (response.statusCode == 429) {
        throw Exception('Rate limited');
      }
    }
    return null;
  }

  // ── 3. OpenRouter (OpenAI-compatible) ─────────────────────────────────────
  static Future<String?> _callOpenRouter(
    String prompt, {
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    final url = Uri.parse(ApiConfig.openRouterBaseUrl);

    final body = jsonEncode({
      'model': ApiConfig.openRouterModel,
      'messages': [
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
      'top_p': 0.8,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${ApiConfig.openRouterApiKey}',
        'HTTP-Referer': 'https://gantavai.com',
        'X-Title': 'Gantav AI Learning',
      },
      body: body,
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String?;
      }
    } else {
      if (response.statusCode == 401) {
        debugPrint('[AI] ✗ OpenRouter UNAUTHORIZED (401). Please check if your OPENROUTER_API_KEY in .env is valid.');
      } else {
        debugPrint('[OpenRouter] API status ${response.statusCode}');
      }
      if (response.statusCode == 429) {
        throw Exception('Rate limited');
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API (backward compatibility)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Public method for external callers — routes through smart engine
  static Future<String?> callAI(
    String prompt, {
    required AITask task,
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async {
    return _smartCall(
      prompt,
      task: task,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  /// Backward compatibility
  static Future<String?> callGemini(String prompt) => callAI(prompt, task: AITask.courseGeneration);

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

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
