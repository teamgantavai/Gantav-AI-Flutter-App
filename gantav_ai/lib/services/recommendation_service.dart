import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'gemini_service.dart';
import 'api_config.dart';

/// Daily recommendation service
class RecommendationService {
  static const String _cacheKey = 'daily_recommendations';
  static const String _dateKey = 'recommendation_date';

  /// Fetch daily recommendations — cached per day
  static Future<List<RecommendationVideo>> fetchRecommendations({
    required String? dream,
    required List<String> activeCategories,
  }) async {
    try {
      // Check cache
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_dateKey);
      final today = DateTime.now().toIso8601String().substring(0, 10);

      if (cachedDate == today) {
        final cached = prefs.getString(_cacheKey);
        if (cached != null) {
          final List<dynamic> data = jsonDecode(cached);
          return data.map((j) => RecommendationVideo.fromJson(j)).toList();
        }
      }

      // Generate fresh recommendations
      if (!ApiConfig.isConfigured) {
        return RecommendationVideo.mockRecommendations();
      }

      final topics = <String>[
        if (dream != null) dream,
        ...activeCategories,
      ];

      if (topics.isEmpty) {
        topics.addAll(['technology', 'programming', 'science']);
      }

      final recs = await _generateRecommendations(topics);

      // Cache
      await prefs.setString(_cacheKey, jsonEncode(recs.map((r) => r.toJson()).toList()));
      await prefs.setString(_dateKey, today);

      return recs;
    } catch (e) {
      debugPrint('Recommendation fetch error: $e');
      return RecommendationVideo.mockRecommendations();
    }
  }

  static Future<List<RecommendationVideo>> _generateRecommendations(List<String> topics) async {
    // 1. Try real YouTube API if configured
    if (ApiConfig.hasYoutube) {
      try {
        final query = topics.take(2).join(' '); // Search using best topics
        final url = Uri.parse(
          'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=6&q=${Uri.encodeComponent(query)}&type=video&key=${ApiConfig.youtubeApiKey}'
        );
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final items = data['items'] as List<dynamic>? ?? [];
          if (items.isNotEmpty) {
            return items.map((item) {
              final snippet = item['snippet'];
              return RecommendationVideo(
                title: snippet['title'] ?? 'YouTube Video',
                channel: snippet['channelTitle'] ?? 'YouTube',
                youtubeVideoId: item['id']['videoId'] ?? '',
                duration: '10:00', // Duration requires an extra API call in v3, so mock for speed
                category: topics.first,
                reason: 'Based on your interest in ${topics.first}',
              );
            }).toList();
          }
        } else {
          debugPrint('YouTube API Error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('YouTube API exception: $e');
      }
    }

    // 2. Fall back to AI-generated mock IDs if YouTube API is not configured or failed
    final prompt = '''
You are a learning recommendation engine. Based on these learning interests: ${topics.join(', ')}

Recommend 6 educational YouTube videos that would be valuable for someone learning these topics.
Mix between different sub-topics and difficulty levels.

Return ONLY valid JSON (no markdown, no code fences):
[
  {
    "title": "Video Title Here",
    "channel": "Channel Name",
    "youtube_video_id": "real_video_id",
    "duration": "15:30",
    "category": "Category Name",
    "reason": "Why this is recommended"
  }
]

Use REAL YouTube video IDs from popular educational channels like 3Blue1Brown, freeCodeCamp, Fireship, Traversy Media, Sentdex, The Coding Train, etc.
''';

    try {
      final response = await GeminiService.callAI(prompt, task: AITask.recommendations);
      if (response == null) return RecommendationVideo.mockRecommendations();

      final jsonStr = GeminiService.extractJson(response);
      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((j) => RecommendationVideo.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Recommendation generation error: $e');
      return RecommendationVideo.mockRecommendations();
    }
  }
}

/// Recommendation video model
class RecommendationVideo {
  final String title;
  final String channel;
  final String youtubeVideoId;
  final String duration;
  final String category;
  final String reason;

  const RecommendationVideo({
    required this.title,
    required this.channel,
    required this.youtubeVideoId,
    required this.duration,
    required this.category,
    required this.reason,
  });

  String get thumbnailUrl => 'https://img.youtube.com/vi/$youtubeVideoId/mqdefault.jpg';

  factory RecommendationVideo.fromJson(Map<String, dynamic> json) {
    return RecommendationVideo(
      title: json['title'] ?? 'Untitled',
      channel: json['channel'] ?? 'Unknown',
      youtubeVideoId: json['youtube_video_id'] ?? '',
      duration: json['duration'] ?? '10:00',
      category: json['category'] ?? 'General',
      reason: json['reason'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'channel': channel,
    'youtube_video_id': youtubeVideoId,
    'duration': duration,
    'category': category,
    'reason': reason,
  };

  static List<RecommendationVideo> mockRecommendations() => [
    const RecommendationVideo(
      title: 'But what is a neural network?',
      channel: '3Blue1Brown',
      youtubeVideoId: 'aircAruvnKk',
      duration: '19:13',
      category: 'AI & ML',
      reason: 'Essential introduction to neural networks with beautiful visualizations',
    ),
    const RecommendationVideo(
      title: 'JavaScript in 100 Seconds',
      channel: 'Fireship',
      youtubeVideoId: 'DHjqpvDnNGE',
      duration: '2:17',
      category: 'Web Development',
      reason: 'Quick overview of JavaScript fundamentals',
    ),
    const RecommendationVideo(
      title: 'Flutter in 100 Seconds',
      channel: 'Fireship',
      youtubeVideoId: 'lHhRhPV--G0',
      duration: '2:07',
      category: 'Mobile Development',
      reason: 'Quick introduction to Flutter framework',
    ),
    const RecommendationVideo(
      title: 'How do computers read code?',
      channel: 'Tom Scott',
      youtubeVideoId: 'QXjU9qTjl00',
      duration: '9:21',
      category: 'Computer Science',
      reason: 'Understanding how computers interpret programming languages',
    ),
    const RecommendationVideo(
      title: 'Python for Beginners - Learn Python in 1 Hour',
      channel: 'Programming with Mosh',
      youtubeVideoId: 'kqtD5dpn9C8',
      duration: '1:00:05',
      category: 'Programming',
      reason: 'Great starting point for Python beginners',
    ),
    const RecommendationVideo(
      title: 'The Art of Code - Creative Coding',
      channel: 'The Coding Train',
      youtubeVideoId: '4Se0_w0ISYk',
      duration: '25:03',
      category: 'Creative',
      reason: 'Inspiring talk about creative applications of code',
    ),
  ];
}
