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
  final List<String> topComments; // Added for AI analysis

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

  static Future<List<YouTubeVideoStats>> fetchHighQualityVideos({
    required String topic,
    String level = '',
    int maxResults = 25,
  }) async {
    if (!ApiConfig.hasYoutube) return [];

    final query = '$topic $level tutorial'.trim();
    final cacheKey = 'yt_search_v2_${query.toLowerCase().replaceAll(" ", "_")}';

    final cachedResult = await _getCachedVideos(cacheKey);
    if (cachedResult != null && cachedResult.isNotEmpty) return cachedResult;

    // 1. Search for IDs
    final videoIds = await _getVideoIdsFromSearch(query, maxResults);
    if (videoIds.isEmpty) return [];

    // 2. Get Stats
    final videos = await _getVideoStats(videoIds);

    // 3. Filter strictly by ratio (> 1.5%) and minimum views (> 5000)
    final List<YouTubeVideoStats> filtered = videos.where((v) {
      return v.viewCount > 5000 && v.engagementRatio > 1.5;
    }).toList();

    filtered.sort((a, b) => b.engagementRatio.compareTo(a.engagementRatio));
    final topCandidates = filtered.take(10).toList(); // Take top 10 to save API limits

    // 4. Fetch comments for ONLY the top candidates (reduces quota usage)
    List<YouTubeVideoStats> finalVideosWithComments = [];
    for (var video in topCandidates) {
      final comments = await _getTopComments(video.id);
      finalVideosWithComments.add(YouTubeVideoStats(
        id: video.id,
        title: video.title,
        channelTitle: video.channelTitle,
        durationText: video.durationText,
        viewCount: video.viewCount,
        likeCount: video.likeCount,
        commentCount: video.commentCount,
        engagementRatio: video.engagementRatio,
        topComments: comments,
      ));
    }

    if (finalVideosWithComments.isNotEmpty) {
      await _cacheVideos(cacheKey, finalVideosWithComments);
    }

    return finalVideosWithComments;
  }

  static Future<List<String>> _getTopComments(String videoId) async {
    try {
      final uri = Uri.parse('$_baseUrl/commentThreads?part=snippet&videoId=$videoId&maxResults=5&order=relevance&key=${ApiConfig.youtubeApiKey}');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items.map((item) => item['snippet']['topLevelComment']['snippet']['textOriginal'] as String).toList();
      }
    } catch (e) {
      debugPrint('[YouTube] Comment fetch error: $e');
    }
    return [];
  }

  static Future<List<String>> _getVideoIdsFromSearch(String query, int maxResults) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/search?'
        'part=snippet'
        '&maxResults=$maxResults'
        '&q=${Uri.encodeComponent(query)}'
        '&type=video'
        '&relevanceLanguage=en'
        '&key=${ApiConfig.youtubeApiKey}',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items.map((item) => item['id']['videoId'] as String).toList();
      } else {
        debugPrint('[YouTube] Search error: ${response.body}');
      }
    } catch (e) {
      debugPrint('[YouTube] Search exception: $e');
    }
    return [];
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

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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
    // Basic ISO 8601 duration parser for YouTube (e.g. PT1H2M10S -> 1:02:10)
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

  // ── Local Caching ──────────────────────────────────────────────────────────

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
          // Cache expired
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
