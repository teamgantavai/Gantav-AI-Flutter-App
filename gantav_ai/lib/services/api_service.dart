import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'gemini_service.dart';
import 'youtube_api_service.dart';
import 'admin_service.dart';

/// API Service with mock fallback — offline-first architecture
class ApiService {
  static const String _baseUrl = 'http://localhost:3000';
  static const Duration _timeout = Duration(seconds: 5);

  /// GET user profile
  static Future<UserProfile> fetchUser(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/users/$userId'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(response.body));
      }
    } catch (_) {
      // Fallback to mock
    }
    return UserProfile.mock();
  }

  /// GET user's courses with progress
  static Future<List<Course>> fetchUserCourses(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/users/$userId/courses'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Course.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback to mock
    }
    return Course.mockCourses();
  }

  /// GET all available courses
  static Future<List<Course>> fetchAllCourses() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/courses'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Course.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback to mock
    }
    return Course.mockCourses();
  }

  /// GET social pulse events
  static Future<List<PulseEvent>> fetchPulse(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/pulse/$userId'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PulseEvent.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback to mock
    }
    return PulseEvent.mockEvents();
  }

  /// POST enroll in a course
  static Future<bool> enrollCourse(String courseId) async {
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/api/courses/$courseId/enroll'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// POST mark lesson as complete
  static Future<bool> completeLesson(String courseId, String lessonId) async {
    try {
      final response = await http
          .post(Uri.parse(
              '$_baseUrl/api/courses/$courseId/lessons/$lessonId/complete'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  static Future<Course?> suggestPath(
    String dream, {
    String language = 'English',
    bool allowCurated = true,
  }) async {
    try {
      // 1. Verified curated courses — only when the caller opts in. Trending
      // card taps disable this so the user never sees an unrelated cached
      // course like "Python for ML" after tapping "Build AI agents".
      if (allowCurated) {
        final verifiedCourses = await AdminService.getVerifiedCourses(dream);
        if (verifiedCourses.isNotEmpty) return verifiedCourses.first;
      }

      // 2. PLAYLIST-FIRST: try to find a single-channel YouTube playlist that
      // covers the whole topic. This gives consistent teaching style and
      // avoids the "mixed random videos from 9 channels" problem.
      final playlist = await YouTubeApiService.findBestPlaylist(
        topic: dream,
        language: language,
      );
      if (playlist != null) {
        final videos =
            await YouTubeApiService.fetchPlaylistVideos(playlist.id);
        if (videos.length >= 3) {
          return _buildCourseFromPlaylist(dream, playlist, videos);
        }
      }

      // 3. If no playlist works, fall back to AI-stitched individual videos.
      final preFilteredVideos = await YouTubeApiService.fetchHighQualityVideos(
        topic: dream,
        language: language,
      );
      final course = await GeminiService.generateLearningPath(
        dream: dream,
        preFilteredVideos: preFilteredVideos,
      );
      if (course != null) return course;

      // 4. Last-resort fallback from raw video list.
      if (preFilteredVideos.isNotEmpty) {
        return _buildFallbackCourse(dream, preFilteredVideos);
      }

      // 5. Genuine failure — return null so the caller can show a clear
      // "try again" toast. We deliberately do NOT fall back to a random
      // verified course here; that produced the "tapped Trending AI Agents,
      // got Python for ML" bug. Unrelated cached content is worse than no
      // course at all.
    } catch (_) {}

    return null;
  }

  /// Build a Course from a single YouTube playlist. Videos are split into
  /// modules of ~3 lessons each while preserving playlist order. All lessons
  /// come from the same channel so the teaching style stays consistent.
  static Course _buildCourseFromPlaylist(
    String dream,
    YouTubePlaylistCandidate playlist,
    List<YouTubeVideoStats> videos,
  ) {
    const lessonsPerModule = 3;
    final moduleCount =
        (videos.length / lessonsPerModule).ceil().clamp(1, 6);
    final modules = <Module>[];
    int vidIdx = 0;
    int totalLessons = 0;

    for (int m = 0; m < moduleCount && vidIdx < videos.length; m++) {
      final lessons = <Lesson>[];
      for (int l = 0;
          l < lessonsPerModule && vidIdx < videos.length;
          l++, vidIdx++) {
        final v = videos[vidIdx];
        lessons.add(Lesson(
          id: 'pl_${playlist.id}_l$vidIdx',
          title: v.title,
          youtubeVideoId: v.id,
          duration: v.durationText,
        ));
        totalLessons++;
      }
      modules.add(Module(
        id: 'pl_${playlist.id}_m$m',
        title: _moduleTitleForIndex(m, moduleCount, dream),
        lessonCount: lessons.length,
        isLocked: m > 0,
        lessons: lessons,
      ));
    }

    final firstThumb =
        videos.isNotEmpty ? 'https://img.youtube.com/vi/${videos.first.id}/maxresdefault.jpg' : playlist.thumbnailUrl;

    final topic = _cleanPromptToTopic(dream);
    final prettyDream = topic.isEmpty
        ? 'Learning'
        : topic
            .split(RegExp(r'\s+'))
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');

    final rawTitle = playlist.title.isNotEmpty
        ? playlist.title
        : 'Complete $prettyDream Course';
    final rawDesc =
        'Full ${prettyDream.isEmpty ? 'course' : prettyDream} course from ${playlist.channelTitle} — ${videos.length} lessons in order.';

    return Course(
      id: 'playlist_${playlist.id}',
      title: _compactTitle(rawTitle),
      description: _compactDescription(rawDesc),
      category: _cleanCategory(dream),
      thumbnailUrl: firstThumb,
      rating: 4.8,
      learnerCount: 128,
      totalLessons: totalLessons,
      estimatedTime: _estimateTotalTime(videos),
      skills: _cleanSkills(dream),
      modules: modules,
    );
  }

  // Cycled phase labels for the middle modules so a 5-module course doesn't
  // read "Module 2 Deep Dive / Module 3 Deep Dive / Module 4 Deep Dive". The
  // first + last modules always read Foundations / Mastery.
  static const List<String> _middleModulePhases = [
    'Core Concepts',
    'Building Blocks',
    'Hands-On Practice',
    'Advanced Patterns',
    'Real-World Projects',
    'Case Studies',
  ];

  static String _moduleTitleForIndex(int index, int total, String dream) {
    if (total == 1) return 'Full Course';
    if (index == 0) return 'Module 1 · Foundations';
    if (index == total - 1) return 'Module ${index + 1} · Mastery';
    final phase = _middleModulePhases[(index - 1) % _middleModulePhases.length];
    return 'Module ${index + 1} · $phase';
  }

  static String _estimateTotalTime(List<YouTubeVideoStats> videos) {
    int totalSeconds = 0;
    for (final v in videos) {
      final parts = v.durationText.split(':');
      try {
        if (parts.length == 3) {
          totalSeconds += int.parse(parts[0]) * 3600 +
              int.parse(parts[1]) * 60 +
              int.parse(parts[2]);
        } else if (parts.length == 2) {
          totalSeconds +=
              int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }
      } catch (_) {}
    }
    final hours = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  static Course _buildFallbackCourse(String dream, List<YouTubeVideoStats> videos) {
    final modules = <Module>[];
    int vidIdx = 0;
    
    // Create 3 modules
    for (int i = 0; i < 3; i++) {
       final lessons = <Lesson>[];
       // 3 videos per module or whatever remains
       for (int j = 0; j < 3 && vidIdx < videos.length; j++) {
         final v = videos[vidIdx];
         lessons.add(Lesson(
           id: 'f_les_$vidIdx',
           title: v.title,
           youtubeVideoId: v.id,
           duration: v.durationText,
         ));
         vidIdx++;
       }
       if (lessons.isNotEmpty) {
         modules.add(Module(
           id: 'f_mod_$i',
           title: _moduleTitleForIndex(i, 3, dream),
           lessonCount: lessons.length,
           isLocked: i > 0,
           lessons: lessons,
         ));
       }
    }

    final topic = _cleanPromptToTopic(dream);
    final prettyDream = topic.isEmpty
        ? 'Learning'
        : topic
            .split(RegExp(r'\s+'))
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');

    return Course(
      id: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      title: _compactTitle('Complete $prettyDream Course'),
      description: _compactDescription(
          'A curated list of high-quality tutorials for $prettyDream'),
      category: _cleanCategory(dream),
      thumbnailUrl: videos.isNotEmpty ? 'https://img.youtube.com/vi/${videos.first.id}/maxresdefault.jpg' : '',
      rating: 4.8,
      learnerCount: 154,
      totalLessons: vidIdx,
      skills: _cleanSkills(dream),
      modules: modules,
    );
  }

  /// Strip the generation metadata (language hint, channel hint) that gets
  /// bolted onto the prompt by explore_screen._buildCoursePrompt, and return
  /// a tight topic string suitable for display in category chips.
  /// Input:  "Python Full Course in Urdu 2024 in English language with videos from ProgrammerType or similar channels"
  /// Output: "Python Full Course in Urdu 2024"
  static String _cleanPromptToTopic(String dream) {
    var s = dream.trim();
    // Trending rotator prefixes the prompt with an "angle. Context: hint" —
    // drop the Context tail so downstream title/category logic sees just the
    // angle, not the 200-char combined blob.
    final ctxIdx = s.toLowerCase().indexOf('. context:');
    if (ctxIdx > 0) s = s.substring(0, ctxIdx).trim();
    // Remove the " with videos from X or similar channels" tail
    s = s.replaceAll(
      RegExp(r'\s*with videos from[^.]*?(or similar channels)?\.?\s*$',
          caseSensitive: false),
      '',
    );
    // Remove " in <Language> language" tail
    s = s.replaceAll(
      RegExp(r'\s*in [a-zA-Z]+ language\.?\s*$', caseSensitive: false),
      '',
    );
    return s.trim();
  }

  /// Hard cap on a course title. Mirrors the compactTitle logic in
  /// Course.fromJson so playlist- and fallback-built courses don't overflow
  /// the card layout. 45 chars matches the FittedBox threshold on home.
  static String _compactTitle(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    const maxChars = 45;
    if (clean.length <= maxChars) return clean;
    final cut = clean.substring(0, maxChars);
    final lastSpace = cut.lastIndexOf(' ');
    final trimmed =
        (lastSpace > 20 ? cut.substring(0, lastSpace) : cut).trim();
    return trimmed.endsWith('…') ? trimmed : '$trimmed…';
  }

  /// Cap description so the "About" box doesn't explode vertically on
  /// trending-generated courses where the description template interpolates
  /// the full prompt.
  static String _compactDescription(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    const maxChars = 160;
    if (clean.length <= maxChars) return clean;
    final cut = clean.substring(0, maxChars);
    final lastSpace = cut.lastIndexOf(' ');
    final trimmed =
        (lastSpace > 80 ? cut.substring(0, lastSpace) : cut).trim();
    return trimmed.endsWith('…') ? trimmed : '$trimmed…';
  }

  static String _cleanCategory(String dream) {
    final topic = _cleanPromptToTopic(dream);
    if (topic.isEmpty) return 'Learning';
    // Keep category readable — 3 words max
    final words = topic.split(RegExp(r'\s+'));
    if (words.length <= 3) return topic;
    return words.take(3).join(' ');
  }

  static List<String> _cleanSkills(String dream) {
    final topic = _cleanPromptToTopic(dream);
    if (topic.isEmpty) return const ['Learning'];
    return [topic];
  }

  /// GET quiz questions — AI-generated via Gemini. Returns an empty list when
  /// AI providers are exhausted so the caller can show a retry UI instead of
  /// silently swapping in hardcoded mock questions (which used to be the bug
  /// — users thought the quiz "wasn't working" because every lesson showed
  /// the same 5 mock questions).
  static Future<List<QuizQuestion>> fetchQuiz(
    String courseId,
    String lessonId, {
    String lessonTitle = '',
    String courseTitle = '',
    String topic = '',
  }) async {
    // 1. AI path (primary)
    if (lessonTitle.isNotEmpty) {
      final aiQuestions = await GeminiService.generateQuiz(
        lessonTitle: lessonTitle,
        courseTitle: courseTitle,
        topic: topic,
      );
      if (aiQuestions.isNotEmpty) return aiQuestions;
    }

    // 2. Dev server fallback (very rare — localhost backend)
    try {
      final response = await http
          .get(Uri.parse(
              '$_baseUrl/api/courses/$courseId/lessons/$lessonId/quiz'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => QuizQuestion.fromJson(json)).toList();
      }
    } catch (_) {}

    // 3. Caller-visible failure — empty list triggers retry UI
    return const [];
  }
}
