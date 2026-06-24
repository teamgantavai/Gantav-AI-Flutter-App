import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/onboarding_models.dart';
import 'gemini_service.dart';
import 'api_config.dart';
import 'youtube_api_service.dart';

/// Service responsible for generating AI-powered learning roadmaps
/// based on user preferences collected during onboarding.
class OnboardingService {
  /// Generate a personalized learning roadmap from user preferences.
  /// IMPORTANT: Language preference only affects VIDEO SEARCH (Hindi/English channels),
  /// NOT the roadmap content language. The UI/roadmap content is always in English.
  static Future<Roadmap?> generateRoadmap(UserPreferences prefs) async {
    if (!ApiConfig.isConfigured) {
      debugPrint('[Onboarding] No AI provider configured — using template roadmap');
      return _templateRoadmap(prefs);
    }

    // Language only determines which YouTube channels/videos to search.
    // The roadmap structure/text stays in English always.
    final videoSearchLanguage = prefs.language == 'hi' ? 'Hindi' : 'English';
    final teacherHint = prefs.preferredTeacher != null && prefs.preferredTeacher!.isNotEmpty
        ? 'Preferred teacher/channel: "${prefs.preferredTeacher}".'
        : '';

    // Fetch videos tailored to the user's language preference
    final preFilteredVideos = await YouTubeApiService.fetchHighQualityVideos(
      topic: prefs.learningGoal,
      language: videoSearchLanguage,
    );

    final String verifiedVideosContext;
    if (preFilteredVideos.isNotEmpty) {
      // Pass only top 8 videos to keep prompt concise and fast
      final topVideos = preFilteredVideos.take(8).toList();
      verifiedVideosContext =
          'Use ONLY these verified YouTube videos for tasks (match video to task topic):\n'
          '${topVideos.map((v) => '- ID: ${v.id} | Title: "${v.title}" | Duration: ${v.durationText} | Channel: ${v.channelTitle}').join('\n')}';
    } else {
      verifiedVideosContext =
          'Use real YouTube video IDs. Preferred channels for ${videoSearchLanguage}: '
          '${prefs.language == 'hi' ? 'CodeWithHarry(hEfFMFU4eM8), Apna College(6mbwJ2xhgzM), PW Skills, Physics Wallah' : 'freeCodeCamp(rfscVS0vtbw), 3Blue1Brown(aircAruvnKk), Traversy Media, Fireship(DHjqpvDnNGE)'}';
    }

    // Compact prompt for faster AI response
    final prompt = '''Create a 10-day learning roadmap for: "${prefs.learningGoal}"
Daily time: ${prefs.dailyStudyMinutes} minutes. $teacherHint
Video language preference: $videoSearchLanguage videos only.

Return ONLY valid JSON (no markdown):
{
  "id": "roadmap_${DateTime.now().millisecondsSinceEpoch}",
  "title": "10-Day ${prefs.learningGoal} Roadmap",
  "goal": "${prefs.learningGoal}",
  "language": "en",
  "days": [
    {
      "day_number": 1,
      "topic": "Introduction to ${prefs.learningGoal}",
      "description": "Get started with the basics",
      "total_duration_minutes": ${prefs.dailyStudyMinutes},
      "tasks": [
        {
          "id": "task_1_1",
          "title": "Watch: Introduction video",
          "description": "Learn core concepts",
          "duration_minutes": ${(prefs.dailyStudyMinutes * 0.6).round()},
          "youtube_video_id": "USE_ID_FROM_LIST_BELOW",
          "is_completed": false
        },
        {
          "id": "task_1_2",
          "title": "Practice: Apply what you learned",
          "description": "Hands-on exercise",
          "duration_minutes": ${(prefs.dailyStudyMinutes * 0.4).round()},
          "is_completed": false
        }
      ],
      "is_completed": false
    }
  ]
}

Rules:
- Generate exactly 10 days. Roadmap content MUST be in English.
- $verifiedVideosContext
- Match the youtube_video_id to the task topic from the list above.
- Each day: 1-2 tasks totaling ~${prefs.dailyStudyMinutes} minutes.
- Progress from basics (days 1-3) → intermediate (4-7) → advanced (8-10).
- Use "is_completed": false for all tasks.''';

    try {
      final response = await GeminiService.callAI(
        prompt,
        task: AITask.courseGeneration,
        maxTokens: 3000,
        temperature: 0.3,
      );

      if (response == null) {
        debugPrint('[Onboarding] AI returned null — using template');
        return _templateRoadmap(prefs);
      }

      final jsonStr = GeminiService.extractJson(response);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Always force language to 'en' — language pref only affects video search
      data['created_at'] = DateTime.now().toIso8601String();
      data['language'] = 'en'; // Always English UI

      final roadmap = Roadmap.fromJson(data);
      if (roadmap.days.isEmpty) {
        debugPrint('[Onboarding] AI returned empty roadmap — using template');
        return _templateRoadmap(prefs);
      }

      debugPrint('[Onboarding] ✓ Generated roadmap: ${roadmap.title} (${roadmap.totalDays} days)');
      return roadmap;
    } catch (e) {
      debugPrint('[Onboarding] Roadmap generation error: $e');
      return _templateRoadmap(prefs);
    }
  }

  /// Fallback template roadmap when AI is unavailable
  static Roadmap _templateRoadmap(UserPreferences prefs) {
    final goal = prefs.learningGoal;
    final daily = prefs.dailyStudyMinutes;
    final now = DateTime.now();

    // Hindi language users get Hindi channel video IDs for fallback
    final videoIds = prefs.language == 'hi'
        ? [
            'hEfFMFU4eM8', // CodeWithHarry Python
            '6mbwJ2xhgzM', // Apna College
            'T-D1KVIuvjA', // CodeWithHarry Web Dev
            'ORrELERaZ38', // CodeWithHarry DSA
            'fhHParI0d5I', // Apna College Java
            'q3uXXh1sHcI', // PW Skills
            'yRpLlJgoaNY', // Hindi ML
            'eWRfhZUzrAc', // Hindi Data Science
            'XRv7HFNgS_E', // Hindi JavaScript
            'UHjVn6WKNEQ', // Hindi Flutter
          ]
        : [
            'rfscVS0vtbw', // freeCodeCamp Python
            'aircAruvnKk', // 3Blue1Brown Neural Networks
            'nu_pCVPKzTk', // Traversy Web Dev
            'DHjqpvDnNGE', // Fireship JS
            'YYXdXT2l7Tc', // Corey Schafer Python
            'nLRL_NcnK-4', // TechWithTim Python
            'HvMSRWTE2mI', // Khan Academy
            '7eh4d6sabA0', // Python variables
            'rAvbpCPgkEI', // Control flow
            '9Os0o3wzS_I', // Functions
          ];

    final phases = [
      'Introduction & Setup',
      'Core Fundamentals',
      'Core Fundamentals',
      'Building Basics',
      'Intermediate Concepts',
      'Intermediate Concepts',
      'Intermediate Concepts',
      'Advanced Topics',
      'Advanced Topics',
      'Project & Review',
    ];

    final days = List.generate(10, (i) {
      final dayNum = i + 1;
      final phase = phases[i];
      final watchDuration = (daily * 0.6).round();
      final practiceDuration = daily - watchDuration;

      return RoadmapDay(
        dayNumber: dayNum,
        topic: 'Day $dayNum: $phase — $goal',
        description: 'Learn $phase concepts for $goal',
        totalDurationMinutes: daily,
        tasks: [
          RoadmapTask(
            id: 'task_${dayNum}_1',
            title: 'Watch: $phase Video',
            description: 'Watch a tutorial covering $goal - $phase',
            durationMinutes: watchDuration,
            youtubeVideoId: videoIds[i % videoIds.length],
          ),
          RoadmapTask(
            id: 'task_${dayNum}_2',
            title: 'Practice: Apply $phase Concepts',
            description: 'Hands-on practice exercise for $goal',
            durationMinutes: practiceDuration,
          ),
        ],
      );
    });

    return Roadmap(
      id: 'roadmap_${now.millisecondsSinceEpoch}',
      title: '10-Day $goal Learning Plan',
      goal: goal,
      language: 'en', // Always English UI
      days: days,
      createdAt: now,
    );
  }
}
