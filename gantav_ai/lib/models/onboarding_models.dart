/// Data models for Smart Onboarding & AI Roadmap system
library;

/// User preferences collected during onboarding poll
class UserPreferences {
  final String language;         // 'en' or 'hi'
  final String learningGoal;     // e.g. 'Learn coding', 'Prepare for exams'
  final String? preferredTeacher; // Optional teacher/channel name
  final int dailyStudyMinutes;   // 15, 20, 30, 45, 60, 120
  final DateTime createdAt;

  const UserPreferences({
    required this.language,
    required this.learningGoal,
    this.preferredTeacher,
    required this.dailyStudyMinutes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'language': language,
    'learning_goal': learningGoal,
    'preferred_teacher': preferredTeacher,
    'daily_study_minutes': dailyStudyMinutes,
    'created_at': createdAt.toIso8601String(),
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      language: json['language'] ?? 'en',
      learningGoal: json['learning_goal'] ?? '',
      preferredTeacher: json['preferred_teacher'],
      dailyStudyMinutes: json['daily_study_minutes'] ?? 30,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// A single task within a roadmap day
class RoadmapTask {
  final String id;
  final String title;
  final String description;
  final int durationMinutes;
  final String? youtubeVideoId;  // If task involves watching a video
  bool isCompleted;
  DateTime? completedAt;

  RoadmapTask({
    required this.id,
    required this.title,
    this.description = '',
    required this.durationMinutes,
    this.youtubeVideoId,
    this.isCompleted = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'duration_minutes': durationMinutes,
    'youtube_video_id': youtubeVideoId,
    'is_completed': isCompleted,
    'completed_at': completedAt?.toIso8601String(),
  };

  factory RoadmapTask.fromJson(Map<String, dynamic> json) {
    return RoadmapTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      youtubeVideoId: json['youtube_video_id'],
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
    );
  }
}

/// A single day in the learning roadmap
class RoadmapDay {
  final int dayNumber;
  final String topic;
  final String description;
  final int totalDurationMinutes;
  final List<RoadmapTask> tasks;
  bool isCompleted;
  DateTime? completedAt;

  RoadmapDay({
    required this.dayNumber,
    required this.topic,
    this.description = '',
    required this.totalDurationMinutes,
    required this.tasks,
    this.isCompleted = false,
    this.completedAt,
  });

  /// Check whether all tasks in this day are done
  bool get allTasksCompleted => tasks.isNotEmpty && tasks.every((t) => t.isCompleted);

  /// Number of completed tasks
  int get completedTaskCount => tasks.where((t) => t.isCompleted).length;

  /// Progress for this day (0.0 - 1.0)
  double get progress => tasks.isEmpty ? 0.0 : completedTaskCount / tasks.length;

  Map<String, dynamic> toJson() => {
    'day_number': dayNumber,
    'topic': topic,
    'description': description,
    'total_duration_minutes': totalDurationMinutes,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'is_completed': isCompleted,
    'completed_at': completedAt?.toIso8601String(),
  };

  factory RoadmapDay.fromJson(Map<String, dynamic> json) {
    return RoadmapDay(
      dayNumber: json['day_number'] ?? 0,
      topic: json['topic'] ?? '',
      description: json['description'] ?? '',
      totalDurationMinutes: json['total_duration_minutes'] ?? 0,
      tasks: json['tasks'] != null
          ? (json['tasks'] as List).map((t) => RoadmapTask.fromJson(t)).toList()
          : [],
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
    );
  }
}

/// The full AI-generated learning roadmap
class Roadmap {
  final String id;
  final String title;
  final String goal;
  final String language;        // 'en' or 'hi'
  final List<RoadmapDay> days;
  final DateTime createdAt;
  DateTime? completedAt;

  Roadmap({
    required this.id,
    required this.title,
    required this.goal,
    this.language = 'en',
    required this.days,
    required this.createdAt,
    this.completedAt,
  });

  /// Total days in the roadmap
  int get totalDays => days.length;

  /// Number of completed days
  int get completedDays => days.where((d) => d.isCompleted).length;

  /// Overall progress (0.0 - 1.0)
  double get progress => totalDays > 0 ? completedDays / totalDays : 0.0;

  /// Whether the entire roadmap is complete
  bool get isComplete => totalDays > 0 && completedDays == totalDays;

  /// Estimated completion date based on daily pace
  DateTime get estimatedCompletionDate =>
      createdAt.add(Duration(days: totalDays));

  /// Get today's day (based on day count since creation)
  int get currentDayNumber {
    final daysSinceStart = DateTime.now().difference(createdAt).inDays + 1;
    return daysSinceStart.clamp(1, totalDays);
  }

  /// Get today's tasks
  RoadmapDay? get todayDay {
    final dayNum = currentDayNumber;
    try {
      return days.firstWhere((d) => d.dayNumber == dayNum);
    } catch (_) {
      return days.isNotEmpty ? days.last : null;
    }
  }

  /// Total tasks across all days
  int get totalTasks => days.fold(0, (sum, d) => sum + d.tasks.length);

  /// Total completed tasks
  int get completedTasks =>
      days.fold(0, (sum, d) => sum + d.completedTaskCount);

  /// Task-level progress
  double get taskProgress =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'goal': goal,
    'language': language,
    'days': days.map((d) => d.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  factory Roadmap.fromJson(Map<String, dynamic> json) {
    return Roadmap(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      goal: json['goal'] ?? '',
      language: json['language'] ?? 'en',
      days: json['days'] != null
          ? (json['days'] as List).map((d) => RoadmapDay.fromJson(d)).toList()
          : [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
    );
  }
}
