import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class YouTubeVideoStats {
  final String id;
  final String title;
  final String channelTitle;
  final String durationText;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final double engagementRatio;
  final List<String> topComments;

  YouTubeVideoStats({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.durationText,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.engagementRatio,
    this.topComments = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'channelTitle': channelTitle,
        'durationText': durationText,
        'viewCount': viewCount,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'engagementRatio': engagementRatio,
        'topComments': topComments,
      };

  factory YouTubeVideoStats.fromJson(Map<String, dynamic> json) =>
      YouTubeVideoStats(
        id: json['id'],
        title: json['title'],
        channelTitle: json['channelTitle'] ?? '',
        durationText: json['durationText'] ?? '',
        viewCount: json['viewCount'],
        likeCount: json['likeCount'],
        commentCount: json['commentCount'],
        engagementRatio: json['engagementRatio'] is int
            ? (json['engagementRatio'] as int).toDouble()
            : (json['engagementRatio'] ?? 0.0),
        topComments: List<String>.from(json['topComments'] ?? []),
      );
}

class YouTubeApiService {
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';
  static const int _cacheDurationDays = 7;

  /// Fetch high-quality YouTube videos for a topic.
  /// [language] — 'Hindi' or 'English' — determines which language videos to prioritize.
  /// This does NOT affect the roadmap UI language; it only changes which videos are fetched.
  static Future<List<YouTubeVideoStats>> fetchHighQualityVideos({
    required String topic,
    String language = 'English',
    int maxResults = 15, // Reduced from 25 for faster response
  }) async {
    if (!ApiConfig.hasYoutube) return [];

    // Build a language-aware search query
    final langQuery = language == 'Hindi' ? '$topic in Hindi tutorial' : '$topic tutorial';
    final cacheKey = 'yt_v3_${langQuery.toLowerCase().replaceAll(' ', '_')}';

    final cachedResult = await _getCachedVideos(cacheKey);
    if (cachedResult != null && cachedResult.isNotEmpty) return cachedResult;

    // 1. Search for IDs with language filter
    final videoIds = await _getVideoIdsFromSearch(
      langQuery,
      maxResults,
      relevanceLanguage: language == 'Hindi' ? 'hi' : 'en',
    );
    if (videoIds.isEmpty) return [];

    // 2. Get Stats — batch call is fast
    final videos = await _getVideoStats(videoIds);

    // 3. Filter by quality (engagement > 1.0% and > 3000 views for wider net)
    final List<YouTubeVideoStats> filtered = videos.where((v) {
      return v.viewCount > 3000 && v.engagementRatio > 1.0;
    }).toList();

    filtered.sort((a, b) => b.engagementRatio.compareTo(a.engagementRatio));
    // Take top 8 — skip comment fetching for speed (comments slow things down a lot)
    final topVideos = filtered.take(8).toList();

    if (topVideos.isNotEmpty) {
      await _cacheVideos(cacheKey, topVideos);
    }

    return topVideos;
  }

  static Future<List<String>> _getVideoIdsFromSearch(
    String query,
    int maxResults, {
    String relevanceLanguage = 'en',
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/search?'
        'part=snippet'
        '&maxResults=$maxResults'
        '&q=${Uri.encodeComponent(query)}'
        '&type=video'
        '&relevanceLanguage=$relevanceLanguage'
        '&key=${ApiConfig.youtubeApiKey}',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items.map((item) => item['id']['videoId'] as String).toList();
      } else {
        debugPrint('[YouTube] Search error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[YouTube] Search exception: $e');
    }
    return [];
  }

  /// Fetch details for a specific video by ID.
  static Future<YouTubeVideoStats?> fetchVideoDetails(String videoId) async {
    if (!ApiConfig.hasYoutube) return null;
    final results = await _getVideoStats([videoId]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<List<YouTubeVideoStats>> _getVideoStats(List<String> videoIds) async {
    try {
      final idString = videoIds.join(',');
      final uri = Uri.parse(
        '$_baseUrl/videos?'
        'part=snippet,statistics,contentDetails'
        '&id=$idString'
        '&key=${ApiConfig.youtubeApiKey}',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        final result = <YouTubeVideoStats>[];

        for (final item in items) {
          final stats = item['statistics'];
          final snippet = item['snippet'];
          final contentDetails = item['contentDetails'];

          final likes = double.tryParse(stats['likeCount']?.toString() ?? '0') ?? 0;
          final views = double.tryParse(stats['viewCount']?.toString() ?? '0') ?? 0;
          final comments = double.tryParse(stats['commentCount']?.toString() ?? '0') ?? 0;

          final ratio = views > 0 ? (likes / views) * 100 : 0.0;
          final durationIso = contentDetails['duration'] as String? ?? 'PT0M0S';

          result.add(YouTubeVideoStats(
            id: item['id'],
            title: snippet['title'] ?? 'Unknown',
            channelTitle: snippet['channelTitle'] ?? '',
            durationText: _parseDuration(durationIso),
            viewCount: views.toInt(),
            likeCount: likes.toInt(),
            commentCount: comments.toInt(),
            engagementRatio: double.parse(ratio.toStringAsFixed(2)),
          ));
        }
        return result;
      }
    } catch (e) {
      debugPrint('[YouTube] Stats exception: $e');
    }
    return [];
  }

  static String _parseDuration(String isoDuration) {
    final regExp = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regExp.firstMatch(isoDuration);
    if (match == null) return '0:00';

    final hStr = match.group(1);
    final mStr = match.group(2);
    final sStr = match.group(3);

    int hours = hStr != null ? int.parse(hStr) : 0;
    int minutes = mStr != null ? int.parse(mStr) : 0;
    int seconds = sStr != null ? int.parse(sStr) : 0;

    String res = '';
    if (hours > 0) {
      res += '$hours:';
      res += '${minutes.toString().padLeft(2, '0')}:';
    } else {
      res += '$minutes:';
    }
    res += seconds.toString().padLeft(2, '0');
    return res;
  }

  static Future<List<YouTubeVideoStats>?> _getCachedVideos(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(key);
      final cacheTime = prefs.getInt('${key}_time');

      if (cacheData != null && cacheTime != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
        if (DateTime.now().difference(cacheDate).inDays < _cacheDurationDays) {
          final List<dynamic> jsonList = json.decode(cacheData);
          return jsonList.map((j) => YouTubeVideoStats.fromJson(j)).toList();
        } else {
          await prefs.remove(key);
          await prefs.remove('${key}_time');
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _cacheVideos(String key, List<YouTubeVideoStats> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = videos.map((v) => v.toJson()).toList();
      await prefs.setString(key, json.encode(jsonList));
      await prefs.setInt('${key}_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
