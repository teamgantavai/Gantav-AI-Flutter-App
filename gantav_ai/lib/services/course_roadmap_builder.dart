import '../models/models.dart';

/// Builds a personalized Roadmap from a generated Course using the user's
/// daily available study time. Total days = ceil(totalCourseMinutes / dailyMinutes),
/// never a fixed "10 days" bucket.
class CourseRoadmapBuilder {
  /// Returns a Roadmap whose days pack lessons back-to-back until the daily
  /// minutes budget is exhausted, then starts a new day. Every lesson becomes
  /// one RoadmapTask carrying the YouTube video id so the Roadmap screen can
  /// deep-link straight into the lesson.
  static Roadmap buildFromCourse({
    required Course course,
    required int dailyMinutes,
    String language = 'en',
  }) {
    final clampedDaily = dailyMinutes.clamp(15, 480);
    final flatLessons = <Lesson>[];
    for (final module in course.modules) {
      flatLessons.addAll(module.lessons);
    }

    final days = <RoadmapDay>[];
    var currentTasks = <RoadmapTask>[];
    var currentDayMinutes = 0;
    var dayNumber = 1;

    void flushDay({bool force = false}) {
      if (currentTasks.isEmpty && !force) return;
      days.add(RoadmapDay(
        dayNumber: dayNumber,
        topic: _topicForDay(dayNumber, course),
        description: _descriptionForDay(currentTasks),
        totalDurationMinutes: currentDayMinutes,
        tasks: currentTasks,
      ));
      dayNumber++;
      currentTasks = <RoadmapTask>[];
      currentDayMinutes = 0;
    }

    for (var i = 0; i < flatLessons.length; i++) {
      final lesson = flatLessons[i];
      final minutes = _lessonMinutes(lesson);

      // If the lesson alone is longer than the daily budget, still place it as
      // a single-task day — the user can split mentally. Otherwise start a new
      // day once the budget would overflow.
      if (currentTasks.isNotEmpty &&
          currentDayMinutes + minutes > clampedDaily) {
        flushDay();
      }

      currentTasks.add(RoadmapTask(
        id: 'r_${course.id}_t_${lesson.id}',
        title: lesson.title,
        description: 'Lesson ${i + 1} of ${flatLessons.length}',
        durationMinutes: minutes,
        youtubeVideoId: lesson.youtubeVideoId.isNotEmpty
            ? lesson.youtubeVideoId
            : null,
      ));
      currentDayMinutes += minutes;
    }
    flushDay();

    // Add a final "Review & Practice" day for retention.
    if (days.isNotEmpty) {
      days.add(RoadmapDay(
        dayNumber: dayNumber,
        topic: 'Review & Practice',
        description: 'Revisit key concepts and try the quizzes again.',
        totalDurationMinutes: (clampedDaily * 0.6).round(),
        tasks: [
          RoadmapTask(
            id: 'r_${course.id}_review',
            title: 'Review top lessons and redo quizzes',
            description: 'Re-watch anything unclear; attempt each quiz once more.',
            durationMinutes: (clampedDaily * 0.6).round(),
          ),
        ],
      ));
    }

    return Roadmap(
      id: 'roadmap_course_${course.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: '${course.title} · ${days.length}-day plan',
      goal: course.category.isEmpty ? course.title : course.category,
      language: language,
      days: days,
      createdAt: DateTime.now(),
    );
  }

  static int _lessonMinutes(Lesson lesson) {
    final parts = lesson.duration.split(':');
    try {
      if (parts.length == 3) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final s = int.parse(parts[2]);
        return (h * 60 + m + (s > 30 ? 1 : 0)).clamp(1, 600);
      }
      if (parts.length == 2) {
        final m = int.parse(parts[0]);
        final s = int.parse(parts[1]);
        return (m + (s > 30 ? 1 : 0)).clamp(1, 600);
      }
    } catch (_) {}
    return 15; // sensible default
  }

  static String _topicForDay(int dayNumber, Course course) {
    if (dayNumber == 1) return 'Day 1 · Kickoff';
    return 'Day $dayNumber · ${course.category.isEmpty ? "Progress" : course.category}';
  }

  static String _descriptionForDay(List<RoadmapTask> tasks) {
    if (tasks.isEmpty) return '';
    if (tasks.length == 1) return tasks.first.title;
    return '${tasks.length} lessons · ${tasks.fold(0, (sum, t) => sum + t.durationMinutes)} min';
  }
}
