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
  final int durationSeconds; // parsed duration; used to filter out Shorts
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
    this.durationSeconds = 0,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.engagementRatio,
    this.topComments = const [],
  });

  /// A YouTube Short is <= 60 seconds. We treat anything shorter than
  /// [minLongFormSeconds] as unsuitable for a tutorial course.
  bool isShort({int minLongFormSeconds = 90}) =>
      durationSeconds > 0 && durationSeconds < minLongFormSeconds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'channelTitle': channelTitle,
        'durationText': durationText,
        'durationSeconds': durationSeconds,
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
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        viewCount: json['viewCount'],
        likeCount: json['likeCount'],
        commentCount: json['commentCount'],
        engagementRatio: json['engagementRatio'] is int
            ? (json['engagementRatio'] as int).toDouble()
            : (json['engagementRatio'] ?? 0.0),
        topComments: List<String>.from(json['topComments'] ?? []),
      );
}

class YouTubePlaylistCandidate {
  final String id;
  final String title;
  final String channelTitle;
  final String channelId;
  final String description;
  final String thumbnailUrl;
  final int videoCount;
  final double score;

  const YouTubePlaylistCandidate({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.channelId,
    required this.description,
    required this.thumbnailUrl,
    required this.videoCount,
    required this.score,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'channelTitle': channelTitle,
        'channelId': channelId,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'videoCount': videoCount,
        'score': score,
      };

  factory YouTubePlaylistCandidate.fromJson(Map<String, dynamic> json) =>
      YouTubePlaylistCandidate(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        channelTitle: json['channelTitle']?.toString() ?? '',
        channelId: json['channelId']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
        videoCount: (json['videoCount'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
      );
}

class YouTubeApiService {
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';
  static const int _cacheDurationDays = 7;

  // ── YouTube triple-key rotation ───────────────────────────────────────────
  // Three YouTube keys rotate automatically. When one hits 403 (quota
  // exhausted), we switch to the next. Only when ALL are exhausted do we
  // stop hitting the API entirely.
  static DateTime? _ytKey1Expiry;
  static DateTime? _ytKey2Expiry;
  static DateTime? _ytKey3Expiry;

  static bool _isKey1Exhausted() {
    if (_ytKey1Expiry == null) return false;
    if (DateTime.now().isAfter(_ytKey1Expiry!)) {
      _ytKey1Expiry = null;
      return false;
    }
    return true;
  }

  static bool _isKey2Exhausted() {
    if (_ytKey2Expiry == null) return false;
    if (DateTime.now().isAfter(_ytKey2Expiry!)) {
      _ytKey2Expiry = null;
      return false;
    }
    return true;
  }

  static bool _isKey3Exhausted() {
    if (_ytKey3Expiry == null) return false;
    if (DateTime.now().isAfter(_ytKey3Expiry!)) {
      _ytKey3Expiry = null;
      return false;
    }
    return true;
  }

  /// Returns the currently usable YouTube API key, or empty string if all
  /// keys are exhausted.
  static String get _activeYoutubeKey {
    if (ApiConfig.hasYoutube && !_isKey1Exhausted()) return ApiConfig.youtubeApiKey;
    if (ApiConfig.hasYoutube2 && !_isKey2Exhausted()) return ApiConfig.youtubeApiKey2;
    if (ApiConfig.hasYoutube3 && !_isKey3Exhausted()) return ApiConfig.youtubeApiKey3;
    
    // All exhausted — try key 1 again if others don't exist
    if (ApiConfig.hasYoutube && !_isKey1Exhausted()) return ApiConfig.youtubeApiKey;
    return '';
  }

  static bool get _isYoutubeQuotaExhausted => _activeYoutubeKey.isEmpty;

  static void _markYoutubeKeyExhausted(String usedKey) {
    if (usedKey == ApiConfig.youtubeApiKey) {
      debugPrint('[YouTube] ⚠ Key 1 quota exhausted (403). Switching to key 2.');
      _ytKey1Expiry = DateTime.now().add(const Duration(hours: 24));
    } else if (usedKey == ApiConfig.youtubeApiKey2) {
      debugPrint('[YouTube] ⚠ Key 2 quota exhausted (403). Switching to key 3.');
      _ytKey2Expiry = DateTime.now().add(const Duration(hours: 24));
    } else if (usedKey == ApiConfig.youtubeApiKey3) {
      debugPrint('[YouTube] ⚠ Key 3 quota exhausted (403). Switching to key 1.');
      _ytKey3Expiry = DateTime.now().add(const Duration(hours: 24));
    }
    if (_isYoutubeQuotaExhausted) {
      debugPrint('[YouTube] ⚠ ALL keys exhausted. All YouTube requests paused for 24h.');
    }
  }

  /// Fetch high-quality YouTube videos for a topic.
  /// [language] — 'Hindi' or 'English' — determines which language videos to prioritize.
  /// This does NOT affect the roadmap UI language; it only changes which videos are fetched.
  static Future<List<YouTubeVideoStats>> fetchHighQualityVideos({
    required String topic,
    String language = 'English',
    int maxResults = 15,
  }) async {
    if (!ApiConfig.hasYoutube) return [];
    if (_isYoutubeQuotaExhausted) {
      debugPrint('[YouTube] ⏳ quota cooldown active, skipping search');
      return [];
    }

    // Build a language-aware search query
    final langQuery = language == 'Hindi' ? '$topic in Hindi tutorial' : '$topic tutorial';
    // v5 — bumped from v4 when recency + HD filters were introduced so stale
    // pre-filter results get re-fetched instead of served from cache.
    final cacheKey = 'yt_v5_${langQuery.toLowerCase().replaceAll(' ', '_')}';

    final cachedResult = await _getCachedVideos(cacheKey);
    if (cachedResult != null && cachedResult.isNotEmpty) return cachedResult;

    // 1. Search for IDs with language filter.
    //    • `videoDuration=medium` excludes Shorts (<4min) at API level — critical
    //       so trending cards don't build a "course" out of 30s meme clips.
    //    • `publishedAfter` (~18 months) keeps results current. If that yields
    //       nothing (niche topic / recent searches exhausted), we fall back to
    //       the same query WITHOUT a date filter so the user still gets videos —
    //       an old well-ranked tutorial beats an empty list.
    final recentCutoff = DateTime.now().subtract(const Duration(days: 548)); // ~18 months
    final relevanceLang = language == 'Hindi' ? 'hi' : 'en';

    List<String> videoIds = await _getVideoIdsFromSearch(
      langQuery,
      maxResults,
      relevanceLanguage: relevanceLang,
      videoDuration: 'medium',
      publishedAfter: recentCutoff,
      videoDefinition: 'high',
    );

    // Fallback 1: keep the HD filter but drop recency.
    if (videoIds.isEmpty) {
      debugPrint('[YouTube] No recent videos for "$langQuery" — falling back to older HD results');
      videoIds = await _getVideoIdsFromSearch(
        langQuery,
        maxResults,
        relevanceLanguage: relevanceLang,
        videoDuration: 'medium',
        videoDefinition: 'high',
      );
    }
    // Fallback 2: last-resort — drop HD too (rare niche topics).
    if (videoIds.isEmpty) {
      debugPrint('[YouTube] No HD videos for "$langQuery" — widest fallback');
      videoIds = await _getVideoIdsFromSearch(
        langQuery,
        maxResults,
        relevanceLanguage: relevanceLang,
        videoDuration: 'medium',
      );
    }
    if (videoIds.isEmpty) return [];

    // 2. Get Stats — batch call is fast
    final videos = await _getVideoStats(videoIds);

    // 3. Filter by quality AND duration. Drop anything under 90s as a
    //    belt-and-braces guard against Shorts slipping past the API filter.
    final List<YouTubeVideoStats> filtered = videos.where((v) {
      if (v.isShort(minLongFormSeconds: 90)) return false;
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
    // 'any' | 'short' (<4min) | 'medium' (4–20min) | 'long' (>20min).
    // Default 'medium' excludes Shorts; override when you specifically need
    // long tutorials or everything.
    String? videoDuration,
    // RFC 3339 timestamp — only return videos published after this instant.
    // Pass `DateTime.now().subtract(Duration(days: 548))` for ~18-month recency.
    DateTime? publishedAfter,
    // 'any' | 'high' | 'standard' — `high` prefers 720p+ uploads.
    String? videoDefinition,
  }) async {
    try {
      final publishedAfterParam = publishedAfter != null
          // YouTube wants RFC 3339 — toUtc().toIso8601String() already emits it.
          ? '&publishedAfter=${publishedAfter.toUtc().toIso8601String()}'
          : '';
      final definitionParam =
          videoDefinition != null ? '&videoDefinition=$videoDefinition' : '';
      final ytKey = _activeYoutubeKey;
      if (ytKey.isEmpty) return [];
      final uri = Uri.parse(
        '$_baseUrl/search?'
        'part=snippet'
        '&maxResults=$maxResults'
        '&q=${Uri.encodeComponent(query)}'
        '&type=video'
        '&order=relevance'
        '&relevanceLanguage=$relevanceLanguage'
        '${videoDuration != null ? '&videoDuration=$videoDuration' : ''}'
        '$definitionParam'
        '$publishedAfterParam'
        '&key=$ytKey',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items.map((item) => item['id']['videoId'] as String).toList();
      } else {
        debugPrint('[YouTube] Search error: ${response.statusCode}');
        if (response.statusCode == 403) _markYoutubeKeyExhausted(ytKey);
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
      final ytKey = _activeYoutubeKey;
      if (ytKey.isEmpty) return [];
      final uri = Uri.parse(
        '$_baseUrl/videos?'
        'part=snippet,statistics,contentDetails'
        '&id=$idString'
        '&key=$ytKey',
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
            durationSeconds: _parseDurationSeconds(durationIso),
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

  // ═══════════════════════════════════════════════════════════════════════
  // PLAYLIST-FIRST COURSE GENERATION
  // ═══════════════════════════════════════════════════════════════════════

  /// Search for the best YouTube playlist for a topic.
  /// Returns a candidate with id, title, channelTitle, videoCount and
  /// a computed quality score. Picks from a single channel so the whole
  /// course flows in one teaching style.
  ///
  /// Returns null if no suitable playlist found.
  /// Returns up to [max] ranked playlist candidates for [topic]. Used by the
  /// course generator to retry with the next-best playlist when the first one
  /// turns out to have fewer than 3 usable videos (Shorts, private items,
  /// deleted videos). [findBestPlaylist] is kept as a thin compatibility
  /// wrapper.
  static Future<List<YouTubePlaylistCandidate>> findTopPlaylists({
    required String topic,
    String language = 'English',
    int minVideos = 3,
    int maxVideos = 40,
    int max = 3,
  }) async {
    if (!ApiConfig.hasYoutube) return const [];
    if (_isYoutubeQuotaExhausted) {
      debugPrint('[YouTube] ⏳ quota cooldown active, skipping playlist search');
      return const [];
    }

    final langQuery = language == 'Hindi'
        ? '$topic complete course playlist in Hindi'
        : '$topic complete course playlist';

    final playlistIds = await _searchPlaylistIds(
      langQuery,
      relevanceLanguage: language == 'Hindi' ? 'hi' : 'en',
    );
    if (playlistIds.isEmpty) return const [];

    final candidates = await _fetchPlaylistDetails(playlistIds);
    if (candidates.isEmpty) return const [];

    final filtered = candidates
        .where((c) => c.videoCount >= minVideos && c.videoCount <= maxVideos)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return filtered.take(max).toList();
  }

  static Future<YouTubePlaylistCandidate?> findBestPlaylist({
    required String topic,
    String language = 'English',
    int minVideos = 5,
    int maxVideos = 40,
  }) async {
    if (!ApiConfig.hasYoutube) return null;

    final langQuery = language == 'Hindi'
        ? '$topic complete course playlist in Hindi'
        : '$topic complete course playlist';
    final cacheKey =
        'yt_playlist_v2_${langQuery.toLowerCase().replaceAll(' ', '_')}';

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      final cachedTime = prefs.getInt('${cacheKey}_time');
      if (cached != null && cachedTime != null) {
        final age = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(cachedTime));
        if (age.inDays < _cacheDurationDays) {
          return YouTubePlaylistCandidate.fromJson(jsonDecode(cached));
        }
      }
    } catch (_) {}

    // 1. Search playlists
    final playlistIds = await _searchPlaylistIds(
      langQuery,
      relevanceLanguage: language == 'Hindi' ? 'hi' : 'en',
    );
    if (playlistIds.isEmpty) return null;

    // 2. Fetch details + video counts
    final candidates = await _fetchPlaylistDetails(playlistIds);
    if (candidates.isEmpty) return null;

    // 3. Filter: must have between min and max videos (enough content, not
    //    a junk 200-video dump)
    final filtered = candidates
        .where((c) => c.videoCount >= minVideos && c.videoCount <= maxVideos)
        .toList();
    if (filtered.isEmpty) return null;

    // 4. Rank by score (favors higher video count, well-known channels)
    filtered.sort((a, b) => b.score.compareTo(a.score));
    final best = filtered.first;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'yt_playlist_v2_${langQuery.toLowerCase().replaceAll(' ', '_')}',
          jsonEncode(best.toJson()));
      await prefs.setInt(
          'yt_playlist_v2_${langQuery.toLowerCase().replaceAll(' ', '_')}_time',
          DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}

    return best;
  }

  static Future<List<String>> _searchPlaylistIds(
    String query, {
    String relevanceLanguage = 'en',
    int maxResults = 10,
  }) async {
    try {
      final ytKey = _activeYoutubeKey;
      if (ytKey.isEmpty) return [];
      final uri = Uri.parse(
        '$_baseUrl/search?'
        'part=snippet'
        '&maxResults=$maxResults'
        '&q=${Uri.encodeComponent(query)}'
        '&type=playlist'
        '&relevanceLanguage=$relevanceLanguage'
        '&key=$ytKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items
            .map((item) => item['id']?['playlistId'] as String?)
            .whereType<String>()
            .toList();
      } else {
        debugPrint('[YouTube] Playlist search error: ${response.statusCode}');
        if (response.statusCode == 403) _markYoutubeKeyExhausted(ytKey);
      }
    } catch (e) {
      debugPrint('[YouTube] Playlist search exception: $e');
    }
    return [];
  }

  static Future<List<YouTubePlaylistCandidate>> _fetchPlaylistDetails(
      List<String> playlistIds) async {
    try {
      final ytKey = _activeYoutubeKey;
      if (ytKey.isEmpty) return [];
      final idString = playlistIds.join(',');
      final uri = Uri.parse(
        '$_baseUrl/playlists?'
        'part=snippet,contentDetails'
        '&id=$idString'
        '&maxResults=50'
        '&key=$ytKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final items = data['items'] as List;
      final out = <YouTubePlaylistCandidate>[];
      for (final item in items) {
        final snippet = item['snippet'] ?? {};
        final details = item['contentDetails'] ?? {};
        final videoCount = (details['itemCount'] as num?)?.toInt() ?? 0;
        final title = snippet['title']?.toString() ?? '';
        final channel = snippet['channelTitle']?.toString() ?? '';
        final channelId = snippet['channelId']?.toString() ?? '';
        final description = snippet['description']?.toString() ?? '';
        final thumb = (snippet['thumbnails']?['high']?['url'] ??
                snippet['thumbnails']?['default']?['url'] ??
                '')
            .toString();

        // Score: favor reasonable length (8-25 videos is sweet spot for a
        // course), penalize extremes, prefer titles that look course-like.
        double score = 0;
        if (videoCount >= 8 && videoCount <= 25) {
          score += 30;
        } else if (videoCount >= 5) {
          score += 15;
        }
        final lowerTitle = title.toLowerCase();
        if (lowerTitle.contains('complete') ||
            lowerTitle.contains('full course') ||
            lowerTitle.contains('tutorial') ||
            lowerTitle.contains('bootcamp')) {
          score += 10;
        }
        // Hard penalty for Shorts-style playlists — "shorts", "#shorts",
        // "reels", "edshorts" etc. should never win over a real tutorial list.
        if (lowerTitle.contains('short') ||
            lowerTitle.contains('#short') ||
            lowerTitle.contains('reel')) {
          score -= 50;
        }
        score += videoCount.clamp(0, 30).toDouble() * 0.5;

        out.add(YouTubePlaylistCandidate(
          id: item['id']?.toString() ?? '',
          title: title,
          channelTitle: channel,
          channelId: channelId,
          description: description,
          thumbnailUrl: thumb,
          videoCount: videoCount,
          score: score,
        ));
      }
      return out;
    } catch (e) {
      debugPrint('[YouTube] Playlist details exception: $e');
      return [];
    }
  }

  /// Fetch all videos from a playlist in order. Single channel guaranteed
  /// because playlists are owned by one channel. Returns videos with full
  /// stats so caller can build lessons.
  static Future<List<YouTubeVideoStats>> fetchPlaylistVideos(
      String playlistId,
      {int maxVideos = 30}) async {
    if (!ApiConfig.hasYoutube || playlistId.isEmpty) return [];

    final cacheKey = 'yt_playlist_items_v2_$playlistId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      final cachedTime = prefs.getInt('${cacheKey}_time');
      if (cached != null && cachedTime != null) {
        final age = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(cachedTime));
        if (age.inDays < _cacheDurationDays) {
          final List<dynamic> list = jsonDecode(cached);
          return list.map((j) => YouTubeVideoStats.fromJson(j)).toList();
        }
      }
    } catch (_) {}

    final ids = <String>[];
    String? pageToken;
    int safety = 0;
    while (ids.length < maxVideos && safety < 3) {
      safety++;
      try {
        final ytKey = _activeYoutubeKey;
        if (ytKey.isEmpty) break;
        final uri = Uri.parse(
          '$_baseUrl/playlistItems?'
          'part=contentDetails'
          '&maxResults=50'
          '&playlistId=$playlistId'
          '${pageToken != null ? '&pageToken=$pageToken' : ''}'
          '&key=$ytKey',
        );
        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) break;
        final data = json.decode(response.body);
        final items = (data['items'] as List? ?? []);
        for (final item in items) {
          final vid = item['contentDetails']?['videoId']?.toString();
          if (vid != null && vid.isNotEmpty) ids.add(vid);
          if (ids.length >= maxVideos) break;
        }
        pageToken = data['nextPageToken']?.toString();
        if (pageToken == null || pageToken.isEmpty) break;
      } catch (e) {
        debugPrint('[YouTube] Playlist items exception: $e');
        break;
      }
    }

    if (ids.isEmpty) return [];

    // Stats fetch supports up to 50 ids per call; we capped maxVideos anyway.
    final stats = await _getVideoStats(ids);
    // Preserve the playlist ordering (stats call may reorder) AND drop
    // Shorts — some channels bundle 30s trailers into their course playlists.
    final byId = {for (final s in stats) s.id: s};
    final ordered = ids
        .map((id) => byId[id])
        .whereType<YouTubeVideoStats>()
        .where((v) => !v.isShort(minLongFormSeconds: 90))
        .toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey,
          jsonEncode(ordered.map((v) => v.toJson()).toList()));
      await prefs.setInt(
          '${cacheKey}_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}

    return ordered;
  }

  /// Convert ISO 8601 duration (`PT4M32S`, `PT1H5M`, `PT45S`) to seconds.
  /// Returns 0 on parse failure so unknown durations are conservatively
  /// treated as non-Shorts (we'd rather include a tutorial than drop one).
  static int _parseDurationSeconds(String isoDuration) {
    final regExp = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regExp.firstMatch(isoDuration);
    if (match == null) return 0;
    final h = int.tryParse(match.group(1) ?? '') ?? 0;
    final m = int.tryParse(match.group(2) ?? '') ?? 0;
    final s = int.tryParse(match.group(3) ?? '') ?? 0;
    return h * 3600 + m * 60 + s;
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
