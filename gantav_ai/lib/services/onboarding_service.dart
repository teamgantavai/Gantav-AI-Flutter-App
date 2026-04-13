import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/onboarding_models.dart';
import 'gemini_service.dart';
import 'api_config.dart';
import 'youtube_api_service.dart';

/// Service responsible for generating AI-powered learning roadmaps
/// based on user preferences collected during onboarding.
class OnboardingService {
  /// Generate a personalized learning roadmap from user preferences
  static Future<Roadmap?> generateRoadmap(UserPreferences prefs) async {
    if (!ApiConfig.isConfigured) {
      debugPrint('[Onboarding] No AI provider configured — using template roadmap');
      return _templateRoadmap(prefs);
    }

    final languageInstruction = prefs.language == 'hi'
        ? 'Generate ALL content (titles, descriptions, topics) in Hindi language.'
        : 'Generate all content in English.';

    final teacherHint = prefs.preferredTeacher != null && prefs.preferredTeacher!.isNotEmpty
        ? 'The user prefers learning from "${prefs.preferredTeacher}". Try to include content from this teacher/channel when relevant.'
        : '';
        
    final preFilteredVideos = await YouTubeApiService.fetchHighQualityVideos(topic: prefs.learningGoal);
    final String verifiedVideosContext;
    if (preFilteredVideos.isNotEmpty) {
      verifiedVideosContext = 'IMPORTANT: You MUST use ONLY the following verified YouTube videos for tasks:\n' +
          preFilteredVideos.map((v) => '- Title: "${v.title}", Video ID: ${v.id}, Duration: ${v.durationText}, Channel: ${v.channelTitle}').join('\n');
    } else {
      verifiedVideosContext = 'Use REAL YouTube video IDs from: freeCodeCamp(rfscVS0vtbw), 3Blue1Brown(aircAruvnKk), Traversy(nu_pCVPKzTk), Fireship(DHjqpvDnNGE), Corey Schafer(YYXdXT2l7Tc), TechWithTim(nLRL_NcnK-4), Khan Academy(HvMSRWTE2mI)';
    }

    final prompt = '''You are an expert education curriculum designer.

A student has the following preferences:
- Learning Goal: "${prefs.learningGoal}"
- Daily Study Time: ${prefs.dailyStudyMinutes} minutes per day
- Preferred Teacher/Channel: ${prefs.preferredTeacher ?? 'None specified'}
$teacherHint
$languageInstruction

Create a personalized day-by-day learning roadmap. The roadmap should span 14-21 days.
Each day should have 1-3 tasks that fit within the ${prefs.dailyStudyMinutes}-minute daily budget.
Tasks should be specific and actionable (e.g., "Watch: Introduction to Variables", "Practice: Write 5 programs using loops").
Include highly rated YouTube videos based on the verified list below.

Return ONLY valid JSON (no markdown):
{
  "id": "roadmap_\${DateTime.now().millisecondsSinceEpoch}",
  "title": "Descriptive Roadmap Title",
  "goal": "${prefs.learningGoal}",
  "language": "${prefs.language}",
  "days": [
    {
      "day_number": 1,
      "topic": "Topic Name",
      "description": "Brief description of what will be learned",
      "total_duration_minutes": ${prefs.dailyStudyMinutes},
      "tasks": [
        {
          "id": "task_1_1",
          "title": "Watch: Video Title",
          "description": "Why this is important",
          "duration_minutes": 15,
          "youtube_video_id": "realVideoId",
          "is_completed": false
        },
        {
          "id": "task_1_2",
          "title": "Practice: Exercise description",
          "description": "What to practice",
          "duration_minutes": 15,
          "is_completed": false
        }
      ],
      "is_completed": false
    }
  ]
}

Rules:
- Each day's total duration should be ~${prefs.dailyStudyMinutes} minutes
- $verifiedVideosContext
- Tasks should progress logically from basics to advanced
- Include a mix of watching, practicing, and reviewing
- Day numbers must be sequential starting from 1''';

    try {
      final response = await GeminiService.callAI(
        prompt,
        task: AITask.courseGeneration,
        maxTokens: 4096,
        temperature: 0.4,
      );

      if (response == null) {
        debugPrint('[Onboarding] AI returned null — using template');
        return _templateRoadmap(prefs);
      }

      final jsonStr = GeminiService.extractJson(response);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Ensure created_at is set
      data['created_at'] = DateTime.now().toIso8601String();
      
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
    final isHindi = prefs.language == 'hi';
    final goal = prefs.learningGoal;
    final daily = prefs.dailyStudyMinutes;
    final now = DateTime.now();

    // Create a structured 14-day roadmap based on goal
    final days = List.generate(14, (i) {
      final dayNum = i + 1;
      final phase = dayNum <= 4
          ? (isHindi ? 'मूल बातें' : 'Foundations')
          : dayNum <= 8
              ? (isHindi ? 'मध्यवर्ती' : 'Intermediate')
              : dayNum <= 12
                  ? (isHindi ? 'उन्नत' : 'Advanced')
                  : (isHindi ? 'अभ्यास' : 'Practice & Review');

      final videoIds = [
        'rfscVS0vtbw', 'aircAruvnKk', 'nu_pCVPKzTk', 'DHjqpvDnNGE',
        'YYXdXT2l7Tc', 'nLRL_NcnK-4', 'HvMSRWTE2mI', '7eh4d6sabA0',
        'rAvbpCPgkEI', '9Os0o3wzS_I', 'W8KRzm-HUcc', 'Uh2ebFW8OYM',
        'NIWwJbo-9_8', 'QUT1VHiLmmI',
      ];

      final watchDuration = (daily * 0.6).round();
      final practiceDuration = daily - watchDuration;

      return RoadmapDay(
        dayNumber: dayNum,
        topic: isHindi 
            ? 'दिन $dayNum: $phase — $goal'
            : 'Day $dayNum: $phase — $goal',
        description: isHindi
            ? '$goal के बारे में $phase सीखें'
            : 'Learn $phase concepts about $goal',
        totalDurationMinutes: daily,
        tasks: [
          RoadmapTask(
            id: 'task_${dayNum}_1',
            title: isHindi ? 'देखें: $phase वीडियो' : 'Watch: $phase Video',
            description: isHindi
                ? '$goal से संबंधित वीडियो देखें'
                : 'Watch a video about $goal - $phase',
            durationMinutes: watchDuration,
            youtubeVideoId: videoIds[i % videoIds.length],
          ),
          RoadmapTask(
            id: 'task_${dayNum}_2',
            title: isHindi ? 'अभ्यास: अवधारणाओं को लागू करें' : 'Practice: Apply Concepts',
            description: isHindi
                ? 'जो आपने सीखा उसका अभ्यास करें'
                : 'Practice what you learned today',
            durationMinutes: practiceDuration,
          ),
        ],
      );
    });

    return Roadmap(
      id: 'roadmap_${now.millisecondsSinceEpoch}',
      title: isHindi ? '$goal — सीखने की योजना' : '$goal — Learning Plan',
      goal: goal,
      language: prefs.language,
      days: days,
      createdAt: now,
    );
  }
}
