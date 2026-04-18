import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_config.dart';
import 'youtube_api_service.dart';

/// Multi-provider AI Service with automatic fallback, rate limiting, and HuggingFace support.
class GeminiService {
  static final Map<AIProvider, DateTime> _rateLimitExpirations = {};
  static final Map<AIProvider, int> _consecutiveFailures = {};
  static bool _cooldownsLoaded = false;
  static const String _cooldownPrefsKey = 'ai_provider_cooldowns_v1';

  /// Load persisted cooldowns from SharedPreferences on first use.
  /// Without this, every cold start retries already-limited providers and
  /// burns daily quota even though we already know they're limited.
  static Future<void> _ensureCooldownsLoaded() async {
    if (_cooldownsLoaded) return;
    _cooldownsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cooldownPrefsKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now();
      for (final entry in map.entries) {
        final provider = AIProvider.values.firstWhere(
          (p) => p.name == entry.key,
          orElse: () => AIProvider.gemini,
        );
        final expiry = DateTime.tryParse(entry.value.toString());
        if (expiry != null && expiry.isAfter(now)) {
          _rateLimitExpirations[provider] = expiry;
        }
      }
    } catch (_) {}
  }

  static Future<void> _persistCooldowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, String>{};
      _rateLimitExpirations.forEach((provider, expiry) {
        map[provider.name] = expiry.toIso8601String();
      });
      await prefs.setString(_cooldownPrefsKey, jsonEncode(map));
    } catch (_) {}
  }

  static bool _isRateLimited(AIProvider provider) {
    final expiry = _rateLimitExpirations[provider];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      _rateLimitExpirations.remove(provider);
      _consecutiveFailures.remove(provider);
      _persistCooldowns();
      return false;
    }
    return true;
  }

  static void _setRateLimited(AIProvider provider, {int minutes = 2}) {
    debugPrint('[AI] ⚠ ${provider.name} rate limited. Cooling down $minutes min.');
    _rateLimitExpirations[provider] =
        DateTime.now().add(Duration(minutes: minutes));
    _persistCooldowns();
  }

  static void _recordFailure(AIProvider provider) {
    _consecutiveFailures[provider] = (_consecutiveFailures[provider] ?? 0) + 1;
    if ((_consecutiveFailures[provider] ?? 0) >= 3) {
      _setRateLimited(provider, minutes: 5);
    }
  }

  static void _recordSuccess(AIProvider provider) {
    _consecutiveFailures.remove(provider);
  }

  // ── Quiz Generation ──────────────────────────────────────────────────────

  static const String _quizCachePrefix = 'ai_quiz_cache_v1_';
  static const Duration _quizCacheTtl = Duration(days: 7);

  static String _quizCacheKey(String lessonTitle, String courseTitle, String topic) {
    final normalized = '${lessonTitle.trim().toLowerCase()}|'
        '${courseTitle.trim().toLowerCase()}|'
        '${topic.trim().toLowerCase()}';
    return '$_quizCachePrefix${normalized.hashCode}';
  }

  static Future<List<QuizQuestion>?> _readQuizCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(map['saved_at']?.toString() ?? '');
      if (savedAt == null ||
          DateTime.now().difference(savedAt) > _quizCacheTtl) {
        await prefs.remove(key);
        return null;
      }
      final List<dynamic> data = map['questions'] as List;
      return data.map((j) => QuizQuestion.fromJson(j)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeQuizCache(
      String key, List<QuizQuestion> questions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'questions': questions
              .map((q) => {
                    'id': q.id,
                    'question': q.question,
                    'options': q.options,
                    'correct_index': q.correctIndex,
                    'explanation': q.explanation,
                  })
              .toList(),
        }),
      );
    } catch (_) {}
  }

  /// Returns AI-generated quiz questions, or an EMPTY list if all providers
  /// failed. Empty list is the signal to callers — do NOT silently fall back
  /// to mock questions here, because the caller needs to distinguish "AI
  /// couldn't answer" (show retry) from "here's real AI content".
  static Future<List<QuizQuestion>> generateQuiz({
    required String lessonTitle,
    required String courseTitle,
    required String topic,
    int count = 5,
  }) async {
    if (!ApiConfig.isConfigured) return const [];

    final cacheKey = _quizCacheKey(lessonTitle, courseTitle, topic);
    final cached = await _readQuizCache(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      debugPrint('[AI] ✓ quiz cache hit ($lessonTitle)');
      return cached;
    }

    // Clip an overly long topic (can happen when category still holds the
    // full dream prompt) — too-long prompts hurt JSON reliability.
    final safeTopic =
        topic.length > 80 ? topic.substring(0, 80) : topic;

    final prompt =
        'Generate $count MCQ quiz questions for lesson: "$lessonTitle" '
        '(Course: "$courseTitle", Topic: "$safeTopic").\n'
        'Make questions relevant and educational. Return ONLY JSON array, no markdown:\n'
        '[{"id":"q_1","question":"...?","options":["A","B","C","D"],"correct_index":0,"explanation":"..."}]';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.quiz,
        maxTokens: 1500,
        temperature: 0.4,
      );
      if (response == null) return const [];
      final jsonStr = extractJson(response);
      final List<dynamic> data = jsonDecode(jsonStr);
      final questions = data
          .map((j) {
            try {
              return QuizQuestion.fromJson(j as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<QuizQuestion>()
          .toList();
      if (questions.isNotEmpty) {
        await _writeQuizCache(cacheKey, questions);
      }
      return questions;
    } catch (e) {
      debugPrint('[AI] Quiz error: $e');
      return const [];
    }
  }

  // ── Doubt Resolution ─────────────────────────────────────────────────────

  /// Sentinel prefixes that tell callers to render an error bubble + retry
  /// chip instead of a normal AI reply. The doubt chat UI checks for these
  /// prefixes so users can distinguish "AI failed" from "AI answered poorly".
  static const String doubtErrorPrefix = '⚠️ ';

  static Future<String> askDoubt({
    required String question,
    required String lessonTitle,
    required String courseTitle,
    List<ChatMessage> history = const [],
  }) async {
    if (!ApiConfig.isConfigured) {
      return '${doubtErrorPrefix}AI is not configured. '
          'Please add at least one AI API key to your .env file.';
    }

    final historyText = history.takeLast(4).map((m) {
      return '${m.isUser ? "Student" : "Tutor"}: ${m.text}';
    }).join('\n');

    final prompt =
        'You are a helpful tutor. Course: "$courseTitle" | Lesson: "$lessonTitle"\n'
        '${historyText.isNotEmpty ? "History:\n$historyText\n" : ""}'
        'Student: $question\n'
        'Give a clear, concise answer (max 120 words). Use examples if helpful. Reply in plain text, no markdown.';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.chat,
        maxTokens: 400,
        temperature: 0.7,
      );
      if (response == null || _looksLikeProviderNotice(response)) {
        return '${doubtErrorPrefix}All AI providers are busy or rate-limited. '
            'Try again in a minute.';
      }
      return response;
    } catch (e) {
      return '${doubtErrorPrefix}Connection error — '
          'check your internet and tap retry.';
    }
  }

  static bool _looksLikeProviderNotice(String text) {
    final lower = text.toLowerCase();
    const markers = [
      'pollinations', 'legacy text api', 'deprecated for authenticated',
      'migrate to our new service', 'rate limit exceeded', 'upgrade your plan',
      'invalid api key', '401 unauthorized', 'quota exceeded',
    ];
    for (final m in markers) {
      if (lower.contains(m)) return true;
    }
    return false;
  }

  // ── Learning Path Generation ─────────────────────────────────────────────

  static Future<Course?> generateLearningPath({
    required String dream,
    List<YouTubeVideoStats>? preFilteredVideos,
  }) async {
    if (!ApiConfig.isConfigured) return null;

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

    final moduleTopics = _generateModuleTopics(courseName);
    final thumbUrl = firstVideoId.isNotEmpty
        ? 'https://img.youtube.com/vi/$firstVideoId/maxresdefault.jpg'
        : 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg';

    final prompt =
        'Create a complete learning course for: "$courseName"\n'
        '$videoContext'
        'CRITICAL: The course title MUST be exactly "$courseName". Do NOT use \$dream placeholder.\n'
        'Return ONLY valid JSON (no markdown backticks, no extra text):\n'
        '{\n'
        '  "id": "gen_${DateTime.now().millisecondsSinceEpoch}",\n'
        '  "title": "$courseName",\n'
        '  "description": "A comprehensive course on ${courseName.toLowerCase()}",\n'
        '  "category": "$courseCategory",\n'
        '  "thumbnail_url": "$thumbUrl",\n'
        '  "total_lessons": 9,\n'
        '  "rating": 4.8,\n'
        '  "learner_count": 0,\n'
        '  "skills": ["${moduleTopics[0]}", "${moduleTopics[1]}", "${moduleTopics[2]}"],\n'
        '  "modules": [\n'
        '    {"id":"mod_1","title":"${moduleTopics[0]}","lesson_count":3,"is_locked":false,"lessons":[\n'
        '      {"id":"les_1","title":"Introduction to $courseName","youtube_video_id":"VIDEO_ID_1","duration":"15:00"},\n'
        '      {"id":"les_2","title":"Core ${moduleTopics[0]} Concepts","youtube_video_id":"VIDEO_ID_2","duration":"18:00"},\n'
        '      {"id":"les_3","title":"${moduleTopics[0]} in Practice","youtube_video_id":"VIDEO_ID_3","duration":"20:00"}\n'
        '    ]},\n'
        '    {"id":"mod_2","title":"${moduleTopics[1]}","lesson_count":3,"is_locked":true,"lessons":[\n'
        '      {"id":"les_4","title":"${moduleTopics[1]} Fundamentals","youtube_video_id":"VIDEO_ID_4","duration":"22:00"},\n'
        '      {"id":"les_5","title":"Advanced ${moduleTopics[1]}","youtube_video_id":"VIDEO_ID_5","duration":"25:00"},\n'
        '      {"id":"les_6","title":"${moduleTopics[1]} Projects","youtube_video_id":"VIDEO_ID_6","duration":"19:00"}\n'
        '    ]},\n'
        '    {"id":"mod_3","title":"${moduleTopics[2]}","lesson_count":3,"is_locked":true,"lessons":[\n'
        '      {"id":"les_7","title":"${moduleTopics[2]} Deep Dive","youtube_video_id":"VIDEO_ID_7","duration":"23:00"},\n'
        '      {"id":"les_8","title":"Real-world ${moduleTopics[2]}","youtube_video_id":"VIDEO_ID_8","duration":"27:00"},\n'
        '      {"id":"les_9","title":"Final $courseName Project","youtube_video_id":"VIDEO_ID_9","duration":"35:00"}\n'
        '    ]}\n'
        '  ]\n'
        '}\n\n'
        'Rules:\n'
        '1. Replace VIDEO_ID_N with REAL YouTube video IDs from the list above.\n'
        '2. Match each video to its lesson topic.\n'
        '3. Keep title EXACTLY as "$courseName".\n'
        '4. Module 1: is_locked=false, Modules 2-3: is_locked=true.';

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

  static String _extractCourseName(String dream) {
    return dream
        .replaceAll(RegExp(r'I want to learn:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'in \w+ language.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'taught by.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'with videos from.*', caseSensitive: false), '')
        .trim()
        .isNotEmpty
        ? dream
            .replaceAll(
                RegExp(r'I want to learn:\s*', caseSensitive: false), '')
            .replaceAll(
                RegExp(r'in \w+ language.*', caseSensitive: false), '')
            .trim()
        : 'Complete Programming Course';
  }

  static String _extractCategory(String dream) {
    final lower = dream.toLowerCase();
    if (lower.contains('python') || lower.contains('programming')) {
      return 'Programming';
    }
    if (lower.contains('flutter') ||
        lower.contains('mobile') ||
        lower.contains('android') ||
        lower.contains('ios')) {
      return 'Mobile Development';
    }
    if (lower.contains('react') ||
        lower.contains('web') ||
        lower.contains('html') ||
        lower.contains('css') ||
        lower.contains('javascript')) {
      return 'Web Development';
    }
    if (lower.contains('machine learning') ||
        lower.contains('ai') ||
        lower.contains('deep learning')) {
      return 'AI & ML';
    }
    if (lower.contains('data')) return 'Data Science';
    if (lower.contains('cloud') ||
        lower.contains('aws') ||
        lower.contains('devops')) {
      return 'Cloud & DevOps';
    }
    if (lower.contains('design') ||
        lower.contains('ui') ||
        lower.contains('ux')) {
      return 'Design';
    }
    if (lower.contains('video editing') ||
        lower.contains('premiere') ||
        lower.contains('davinci')) {
      return 'Video Editing';
    }
    if (lower.contains('game')) return 'Game Development';
    if (lower.contains('cyber') || lower.contains('security')) {
      return 'Cybersecurity';
    }
    if (lower.contains('blockchain') || lower.contains('web3')) {
      return 'Blockchain';
    }
    return 'Technology';
  }

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
    if (lower.contains('video editing') || lower.contains('premiere') || lower.contains('davinci')) {
      return ['Editing Fundamentals', 'Color Grading & Effects', 'Advanced Techniques & Export'];
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
    final cleanName = courseName
        .replaceAll(RegExp(r'(Complete|Course|Basics|Fundamentals)', caseSensitive: false), '')
        .trim();
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
        'Recommend 6 educational YouTube videos for someone learning: "$context" (page $page, vary each page).\n'
        'Return ONLY JSON array, no markdown:\n'
        '[{"title":"Title","channel":"Channel","video_id":"realYTid","duration":"15:30","category":"Cat","description":"Why it is valuable"}]\n'
        'Use REAL video IDs. Prioritize: freeCodeCamp, 3Blue1Brown, Fireship, Traversy Media, MIT OpenCourseWare.';

    try {
      final response = await _smartCall(
        prompt,
        task: AITask.recommendations,
        maxTokens: 1200,
        temperature: 0.8,
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
  // SMART ROUTING ENGINE — Different AI for different tasks
  // ═══════════════════════════════════════════════════════════════════════

  // In-flight request dedup. If two widgets both call generateQuiz for the
  // same lesson in the same frame (happens on rebuild storms), the second
  // caller should await the first future instead of firing a duplicate API
  // call that burns provider quota.
  static final Map<String, Future<String?>> _inFlight = {};

  static String _inFlightKey(AITask task, String prompt, int maxTokens,
          double temperature) =>
      '${task.name}|$maxTokens|${temperature.toStringAsFixed(2)}|${prompt.hashCode}';

  static Future<String?> _smartCall(
    String prompt, {
    required AITask task,
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    await _ensureCooldownsLoaded();

    final key = _inFlightKey(task, prompt, maxTokens, temperature);
    final existing = _inFlight[key];
    if (existing != null) {
      debugPrint('[AI] ⇆ dedup: joining in-flight ${task.name} request');
      return existing;
    }

    final future = _smartCallInner(
      prompt,
      task: task,
      maxTokens: maxTokens,
      temperature: temperature,
    );
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<String?> _smartCallInner(
    String prompt, {
    required AITask task,
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    // Get ordered provider list for this task
    final providers = _getProvidersForTask(task);

    for (final provider in providers) {
      if (_isRateLimited(provider)) {
        debugPrint('[AI] ⏳ ${provider.name} rate-limited, skipping');
        continue;
      }

      try {
        debugPrint('[AI] → Trying ${provider.name} for ${task.name}...');
        final result = await _callProviderWithRetry(
          provider,
          prompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );

        if (result != null && !_looksLikeProviderNotice(result)) {
          _recordSuccess(provider);
          debugPrint('[AI] ✓ ${provider.name} responded');
          return result;
        }
      } catch (e) {
        debugPrint('[AI] ✗ ${provider.name} failed: $e');
        _recordFailure(provider);
      }
    }

    debugPrint('[AI] ✗ All providers exhausted for: ${task.name}');
    return null;
  }

  /// HuggingFace Inference API does not return CORS headers, so direct
  /// browser calls fail with `ERR_FAILED`. On mobile/desktop it works fine.
  static bool get _huggingFaceUsable => ApiConfig.hasHuggingFace && !kIsWeb;

  /// Returns ordered list of providers for a given task.
  /// Different tasks use different primary providers for load balancing.
  static List<AIProvider> _getProvidersForTask(AITask task) {
    final available = <AIProvider>[];

    switch (task) {
      case AITask.chat:
      // Chat: Groq (fastest) → HuggingFace → OpenRouter → Gemini
        if (ApiConfig.hasGroq) available.add(AIProvider.groq);
        if (_huggingFaceUsable) available.add(AIProvider.huggingFace);
        if (ApiConfig.hasOpenRouter) available.add(AIProvider.openRouter);
        if (ApiConfig.hasGemini) available.add(AIProvider.gemini);
        break;

      case AITask.recommendations:
      // Recommendations: OpenRouter → Groq → HuggingFace → Gemini
        if (ApiConfig.hasOpenRouter) available.add(AIProvider.openRouter);
        if (ApiConfig.hasGroq) available.add(AIProvider.groq);
        if (_huggingFaceUsable) available.add(AIProvider.huggingFace);
        if (ApiConfig.hasGemini) available.add(AIProvider.gemini);
        break;

      case AITask.courseGeneration:
      case AITask.quiz:
      // JSON tasks: Gemini best → Groq → OpenRouter → HuggingFace
        if (ApiConfig.hasGemini) available.add(AIProvider.gemini);
        if (ApiConfig.hasGroq) available.add(AIProvider.groq);
        if (ApiConfig.hasOpenRouter) available.add(AIProvider.openRouter);
        if (_huggingFaceUsable) available.add(AIProvider.huggingFace);
        break;
    }

    // If none available, add all that exist
    if (available.isEmpty) {
      if (ApiConfig.hasGemini) available.add(AIProvider.gemini);
      if (ApiConfig.hasGroq) available.add(AIProvider.groq);
      if (ApiConfig.hasOpenRouter) available.add(AIProvider.openRouter);
      if (_huggingFaceUsable) available.add(AIProvider.huggingFace);
    }

    return available;
  }

  static Future<String?> _callProviderWithRetry(
    AIProvider provider,
    String prompt, {
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    try {
      return await _callProvider(provider, prompt,
          maxTokens: maxTokens, temperature: temperature);
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('429') || errorString.contains('Rate limit')) {
        // Don't retry — the provider is rate-limited. Cool it down and let
        // the fallback chain pick the next provider.
        _setRateLimited(provider, minutes: 4);
        rethrow;
      } else if (errorString.contains('401') ||
          errorString.contains('Unauthorized')) {
        debugPrint('[AI] ✗ ${provider.name} auth failure (401) — check API key');
        _setRateLimited(provider, minutes: 60);
        rethrow;
      } else {
        rethrow;
      }
    }
  }

  static Future<String?> _callProvider(
    AIProvider provider,
    String prompt, {
    int maxTokens = 1500,
    double temperature = 0.7,
  }) {
    switch (provider) {
      case AIProvider.gemini:
        return _callGemini(prompt,
            maxTokens: maxTokens, temperature: temperature);
      case AIProvider.groq:
        return _callGroq(prompt,
            maxTokens: maxTokens, temperature: temperature);
      case AIProvider.openRouter:
        return _callOpenRouter(prompt,
            maxTokens: maxTokens, temperature: temperature);
      case AIProvider.huggingFace:
        return _callHuggingFace(prompt,
            maxTokens: maxTokens, temperature: temperature);
    }
  }

  // ── 1. Google Gemini ─────────────────────────────────────────────────────

  static Future<String?> _callGemini(
    String prompt, {
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    final key = ApiConfig.geminiApiKey;
    if (key.isEmpty) return null;

    final url = Uri.parse(
      '${ApiConfig.geminiBaseUrl}/${ApiConfig.geminiModel}:generateContent?key=$key',
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
      debugPrint('[Gemini] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
      if (response.statusCode == 429) throw Exception('Rate limited');
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Unauthorized');
      }
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
    final key = ApiConfig.groqApiKey;
    if (key.isEmpty) return null;

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
            'Authorization': 'Bearer $key',
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
      debugPrint('[Groq] HTTP ${response.statusCode}');
      if (response.statusCode == 429) throw Exception('Rate limited');
      if (response.statusCode == 401) throw Exception('Unauthorized');
    }
    return null;
  }

  // ── 3. OpenRouter ─────────────────────────────────────────────────────────

  static Future<String?> _callOpenRouter(
    String prompt, {
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    final key = ApiConfig.openRouterApiKey;
    if (key.isEmpty) return null;

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
            'Authorization': 'Bearer $key',
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
      debugPrint('[OpenRouter] HTTP ${response.statusCode}');
      if (response.statusCode == 429) throw Exception('Rate limited');
      if (response.statusCode == 401) throw Exception('Unauthorized');
    }
    return null;
  }

  // ── 4. HuggingFace (Free) ─────────────────────────────────────────────────

  static Future<String?> _callHuggingFace(
    String prompt, {
    int maxTokens = 1000,
    double temperature = 0.7,
  }) async {
    final key = ApiConfig.huggingFaceApiKey;
    if (key.isEmpty) return null;

    // Use Mistral-7B via HuggingFace Inference API (free tier)
    final url = Uri.parse(ApiConfig.huggingFaceBaseUrl);

    final body = jsonEncode({
      'inputs': prompt,
      'parameters': {
        'max_new_tokens': maxTokens.clamp(100, 1000),
        'temperature': temperature,
        'top_p': 0.9,
        'do_sample': true,
        'return_full_text': false,
      },
    });

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        return data[0]['generated_text'] as String?;
      }
      if (data is Map) {
        return data['generated_text'] as String?;
      }
    } else {
      debugPrint('[HuggingFace] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
      if (response.statusCode == 429) throw Exception('Rate limited');
      if (response.statusCode == 401) throw Exception('Unauthorized');
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
    return _smartCall(prompt,
        task: task, maxTokens: maxTokens, temperature: temperature);
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
        if (end > objStart) return cleaned.substring(objStart, end + 1);
      } else if (arrayStart != -1) {
        final end = cleaned.lastIndexOf(']');
        if (end > arrayStart) return cleaned.substring(arrayStart, end + 1);
      }
      return cleaned;
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