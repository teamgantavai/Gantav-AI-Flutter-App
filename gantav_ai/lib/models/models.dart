/// Data models for Gantav AI
library;

export 'onboarding_models.dart';

class UserProfile {
  final String id;
  final String name;
  final String handle;
  final String email;
  final int gantavScore;
  final int streakDays;
  final int lessonsCompleted;
  final int quizzesPassed;
  final List<bool> weekActivity; // 7 days Mon-Sun

  const UserProfile({
    required this.id,
    required this.name,
    required this.handle,
    required this.email,
    this.gantavScore = 0,
    this.streakDays = 0,
    this.lessonsCompleted = 0,
    this.quizzesPassed = 0,
    this.weekActivity = const [false, false, false, false, false, false, false],
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  UserProfile copyWith({
    String? name,
    String? handle,
    String? email,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      email: email ?? this.email,
      gantavScore: gantavScore,
      streakDays: streakDays,
      lessonsCompleted: lessonsCompleted,
      quizzesPassed: quizzesPassed,
      weekActivity: weekActivity,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      handle: json['handle'] ?? '',
      email: json['email'] ?? '',
      gantavScore: json['gantav_score'] ?? 0,
      streakDays: json['streak_days'] ?? 0,
      lessonsCompleted: json['lessons_completed'] ?? 0,
      quizzesPassed: json['quizzes_passed'] ?? 0,
      weekActivity: json['week_activity'] != null
          ? List<bool>.from(json['week_activity'])
          : const [false, false, false, false, false, false, false],
    );
  }

  /// Mock user for offline-first experience
  static UserProfile mock() {
    return const UserProfile(
      id: 'user_001',
      name: 'Rahul Sharma',
      handle: 'rahulsharma',
      email: 'rahul@example.com',
      gantavScore: 1250,
      streakDays: 7,
      lessonsCompleted: 34,
      quizzesPassed: 28,
      weekActivity: [true, true, true, true, true, false, true],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'handle': handle,
      'email': email,
      'gantav_score': gantavScore,
      'streak_days': streakDays,
      'lessons_completed': lessonsCompleted,
      'quizzes_passed': quizzesPassed,
      'week_activity': weekActivity,
    };
  }
}

class Course {
  final String id;
  final String title;
  final String description;
  final String category;
  final String language;
  final String thumbnailUrl;
  final double rating;
  final int learnerCount;
  final int totalLessons;
  final int completedLessons;
  final String estimatedTime;
  final List<String> skills;
  final List<Module> modules;
  final int likes;

  final bool isVerified;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.language = 'English',
    required this.thumbnailUrl,
    this.rating = 0.0,
    this.learnerCount = 0,
    this.totalLessons = 0,
    this.completedLessons = 0,
    this.estimatedTime = '',
    this.skills = const [],
    this.modules = const [],
    this.likes = 0,
    this.isVerified = false,
  });

  double get progress =>
      totalLessons > 0 ? completedLessons / totalLessons : 0.0;

  bool get isInProgress => completedLessons > 0 && completedLessons < totalLessons;

  factory Course.fromJson(Map<String, dynamic> json) {
    final rawCategory = (json['category'] ?? '').toString();
    final rawTitle = (json['title'] ?? '').toString();
    final rawDesc = (json['description'] ?? '').toString();
    final fallbackName = rawCategory.trim().isEmpty ? 'Learning' : rawCategory;
    String sanitize(String s) => s
        .replaceAll(r'${dream}', fallbackName)
        .replaceAll(r'$dream', fallbackName)
        .replaceAll('Complete  Course', 'Complete $fallbackName Course');
    return Course(
      id: json['id'] ?? '',
      title: sanitize(rawTitle),
      description: sanitize(rawDesc),
      category: rawCategory,
      language: json['language'] ?? 'English',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      learnerCount: json['learner_count'] ?? 0,
      totalLessons: json['total_lessons'] ?? 0,
      completedLessons: json['completed_lessons'] ?? 0,
      estimatedTime: json['estimated_time'] ?? '',
      likes: json['likes'] ?? 0,
      skills: json['skills'] != null
          ? List<String>.from(json['skills'])
          : const [],
      modules: json['modules'] != null
          ? (json['modules'] as List)
              .map((m) => Module.fromJson(m))
              .toList()
          : const [],
      isVerified: json['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'language': language,
      'thumbnail_url': thumbnailUrl,
      'rating': rating,
      'learner_count': learnerCount,
      'total_lessons': totalLessons,
      'completed_lessons': completedLessons,
      'estimated_time': estimatedTime,
      'likes': likes,
      'skills': skills,
      'modules': modules.map((m) => m.toJson()).toList(),
      'is_verified': isVerified,
    };
  }

  /// Mock courses for offline-first experience
  static List<Course> mockCourses() {
    return [
      Course(
        id: 'course_001',
        title: 'Python for Machine Learning',
        description:
            'Master Python fundamentals and essential libraries like NumPy, Pandas, and Scikit-learn. Build real ML projects from scratch.',
        category: 'Machine Learning',
        thumbnailUrl: 'https://img.youtube.com/vi/7eh4d6sabA0/maxresdefault.jpg',
        rating: 4.8,
        learnerCount: 2841,
        totalLessons: 24,
        completedLessons: 14,
        estimatedTime: '8 weeks',
        skills: ['Python', 'NumPy', 'Pandas', 'Scikit-learn'],
        modules: [
          Module(
            id: 'mod_001',
            title: 'Python Fundamentals',
            lessonCount: 6,
            completedCount: 6,
            isLocked: false,
            lessons: [
              Lesson(
                id: 'les_001',
                title: 'Variables & Data Types',
                youtubeVideoId: '7eh4d6sabA0',
                duration: '18:32',
                isCompleted: true,
                chapters: [
                  Chapter(title: 'Introduction', timestamp: '0:00'),
                  Chapter(title: 'Variables', timestamp: '2:15'),
                  Chapter(title: 'Data Types', timestamp: '8:30'),
                  Chapter(title: 'Type Casting', timestamp: '14:00'),
                ],
              ),
              Lesson(
                id: 'les_002',
                title: 'Control Flow & Loops',
                youtubeVideoId: 'rAvbpCPgkEI',
                duration: '22:14',
                isCompleted: true,
                chapters: [
                  Chapter(title: 'If/Else Statements', timestamp: '0:00'),
                  Chapter(title: 'For Loops', timestamp: '7:30'),
                  Chapter(title: 'While Loops', timestamp: '14:00'),
                  Chapter(title: 'Nested Loops', timestamp: '18:45'),
                ],
              ),
              Lesson(
                id: 'les_003',
                title: 'Functions & Modules',
                youtubeVideoId: '9Os0o3wzS_I',
                duration: '25:08',
                isCompleted: true,
                chapters: [
                  Chapter(title: 'Defining Functions', timestamp: '0:00'),
                  Chapter(title: 'Parameters', timestamp: '5:20'),
                  Chapter(title: 'Return Values', timestamp: '12:00'),
                  Chapter(title: 'Modules & Import', timestamp: '18:30'),
                ],
              ),
              Lesson(
                id: 'les_004',
                title: 'Lists & Dictionaries',
                youtubeVideoId: 'W8KRzm-HUcc',
                duration: '20:45',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_005',
                title: 'File Handling',
                youtubeVideoId: 'Uh2ebFW8OYM',
                duration: '16:20',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_006',
                title: 'Error Handling',
                youtubeVideoId: 'NIWwJbo-9_8',
                duration: '14:55',
                isCompleted: true,
              ),
            ],
          ),
          Module(
            id: 'mod_002',
            title: 'NumPy & Data Manipulation',
            lessonCount: 6,
            completedCount: 5,
            isLocked: false,
            lessons: [
              Lesson(
                id: 'les_007',
                title: 'NumPy Arrays',
                youtubeVideoId: 'QUT1VHiLmmI',
                duration: '19:30',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_008',
                title: 'Array Operations',
                youtubeVideoId: 'lLRBYKaxX7o',
                duration: '21:15',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_009',
                title: 'Broadcasting & Vectorization',
                youtubeVideoId: 'wVDSAsfEbGQ',
                duration: '17:45',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_010',
                title: 'Pandas DataFrames',
                youtubeVideoId: 'vmEHCJofslg',
                duration: '24:00',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_011',
                title: 'Data Cleaning',
                youtubeVideoId: 'bDhvCp3_lYw',
                duration: '22:30',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_012',
                title: 'Data Visualization with Matplotlib',
                youtubeVideoId: '3Xc3CA655Y4',
                duration: '26:10',
                isCompleted: false,
                chapters: [
                  Chapter(title: 'Setting Up Matplotlib', timestamp: '0:00'),
                  Chapter(title: 'Line Charts', timestamp: '4:20'),
                  Chapter(title: 'Bar Charts', timestamp: '10:15'),
                  Chapter(title: 'Scatter Plots', timestamp: '16:00'),
                  Chapter(title: 'Customization', timestamp: '21:30'),
                ],
              ),
            ],
          ),
          Module(
            id: 'mod_003',
            title: 'Machine Learning Basics',
            lessonCount: 6,
            completedCount: 3,
            isLocked: false,
            lessons: [
              Lesson(
                id: 'les_013',
                title: 'Introduction to ML',
                youtubeVideoId: 'ukzFI9rgwfU',
                duration: '20:00',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_014',
                title: 'Linear Regression',
                youtubeVideoId: 'nk2CQITm_eo',
                duration: '28:15',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_015',
                title: 'Logistic Regression',
                youtubeVideoId: 'yIYKR4sgzI8',
                duration: '25:00',
                isCompleted: true,
              ),
              Lesson(
                id: 'les_016',
                title: 'Decision Trees',
                youtubeVideoId: 'ZVR2Way4nwQ',
                duration: '23:40',
                isCompleted: false,
              ),
              Lesson(
                id: 'les_017',
                title: 'Random Forests',
                youtubeVideoId: 'J4Wdy0Wc_xQ',
                duration: '22:10',
                isCompleted: false,
              ),
              Lesson(
                id: 'les_018',
                title: 'Model Evaluation',
                youtubeVideoId: '85dtiMz9tSo',
                duration: '19:55',
                isCompleted: false,
              ),
            ],
          ),
          Module(
            id: 'mod_004',
            title: 'Advanced ML & Projects',
            lessonCount: 6,
            completedCount: 0,
            isLocked: true,
            lessons: [
              Lesson(
                id: 'les_019',
                title: 'Neural Network Fundamentals',
                youtubeVideoId: 'aircAruvnKk',
                duration: '30:00',
                isCompleted: false,
              ),
              Lesson(
                id: 'les_020',
                title: 'Deep Learning with TensorFlow',
                youtubeVideoId: 'tPYj3fFJGjk',
                duration: '35:20',
                isCompleted: false,
              ),
              Lesson(
                id: 'les_021',
                title: 'Convolutional Neural Networks',
                youtubeVideoId: 'YRhxdVk_sIs',
                duration: '28:45',
                isCompleted: false,
              ),
              Lesson(
                id: 'les_022',
                title: 'Natural Language Processing',
                youtubeVideoId: 'WmGOIRq2tYU',
                duration: '32:15',
                isCompleted: false,
              ),
              Lesson(
                id: 'les_023',
                title: 'Project: Image Classifier',
                youtubeVideoId: 'IZDUGGnQgFU',
                duration: '45:00',
                isCompleted: false,
              ),
              Lesson(
                id: 'les_024',
                title: 'Project: Sentiment Analysis',
                youtubeVideoId: 'M7SWr5xObkA',
                duration: '40:30',
                isCompleted: false,
              ),
            ],
          ),
        ],
      ),
      Course(
        id: 'course_002',
        title: 'Full-Stack Web Development',
        description:
            'Build modern web applications with React, Node.js, and PostgreSQL. From frontend design to backend APIs.',
        category: 'Web Development',
        thumbnailUrl: 'https://img.youtube.com/vi/nu_pCVPKzTk/maxresdefault.jpg',
        rating: 4.7,
        learnerCount: 3567,
        totalLessons: 30,
        completedLessons: 8,
        estimatedTime: '10 weeks',
        skills: ['React', 'Node.js', 'PostgreSQL', 'TypeScript'],
        modules: [
          Module(
            id: 'mod_005',
            title: 'HTML & CSS Foundations',
            lessonCount: 6,
            completedCount: 6,
            isLocked: false,
            lessons: [],
          ),
          Module(
            id: 'mod_006',
            title: 'JavaScript Essentials',
            lessonCount: 6,
            completedCount: 2,
            isLocked: false,
            lessons: [],
          ),
          Module(
            id: 'mod_007',
            title: 'React & State Management',
            lessonCount: 6,
            completedCount: 0,
            isLocked: false,
            lessons: [],
          ),
          Module(
            id: 'mod_008',
            title: 'Node.js & Express',
            lessonCount: 6,
            completedCount: 0,
            isLocked: true,
            lessons: [],
          ),
          Module(
            id: 'mod_009',
            title: 'Database & Deployment',
            lessonCount: 6,
            completedCount: 0,
            isLocked: true,
            lessons: [],
          ),
        ],
      ),
      Course(
        id: 'course_003',
        title: 'Data Structures & Algorithms',
        description:
            'Master DSA concepts with visual explanations and coding practice. Perfect for technical interview prep.',
        category: 'Computer Science',
        thumbnailUrl: 'https://img.youtube.com/vi/8hly31xKli0/maxresdefault.jpg',
        rating: 4.9,
        learnerCount: 5120,
        totalLessons: 36,
        completedLessons: 0,
        estimatedTime: '12 weeks',
        skills: ['Arrays', 'Trees', 'Graphs', 'Dynamic Programming'],
        modules: [
          Module(
            id: 'mod_010',
            title: 'Arrays & Strings',
            lessonCount: 6,
            completedCount: 0,
            isLocked: false,
            lessons: [],
          ),
          Module(
            id: 'mod_011',
            title: 'Linked Lists & Stacks',
            lessonCount: 6,
            completedCount: 0,
            isLocked: true,
            lessons: [],
          ),
          Module(
            id: 'mod_012',
            title: 'Trees & Graphs',
            lessonCount: 6,
            completedCount: 0,
            isLocked: true,
            lessons: [],
          ),
        ],
      ),
      Course(
        id: 'course_004',
        title: 'Flutter App Development',
        description:
            'Build beautiful cross-platform mobile apps with Flutter and Dart. From basics to publishing on App Store & Play Store.',
        category: 'Mobile Development',
        thumbnailUrl: 'https://img.youtube.com/vi/VPvVD8t02U8/maxresdefault.jpg',
        rating: 4.6,
        learnerCount: 1892,
        totalLessons: 28,
        completedLessons: 0,
        estimatedTime: '9 weeks',
        skills: ['Dart', 'Flutter', 'Firebase', 'REST APIs'],
        modules: [
          Module(
            id: 'mod_013',
            title: 'Dart Language Basics',
            lessonCount: 7,
            completedCount: 0,
            isLocked: false,
            lessons: [],
          ),
          Module(
            id: 'mod_014',
            title: 'Flutter Widgets',
            lessonCount: 7,
            completedCount: 0,
            isLocked: true,
            lessons: [],
          ),
          Module(
            id: 'mod_015',
            title: 'State Management',
            lessonCount: 7,
            completedCount: 0,
            isLocked: true,
            lessons: [],
          ),
          Module(
            id: 'mod_016',
            title: 'Firebase & Publishing',
            lessonCount: 7,
            completedCount: 0,
            isLocked: true,
            lessons: [],
          ),
        ],
      ),
      Course(
        id: 'course_005',
        title: 'DevOps & Cloud Engineering',
        description:
            'Learn Docker, Kubernetes, CI/CD pipelines, and AWS. Deploy applications at scale with industry best practices.',
        category: 'Cloud & DevOps',
        thumbnailUrl: 'https://img.youtube.com/vi/3c-iBn73dDE/maxresdefault.jpg',
        rating: 4.5,
        learnerCount: 1243,
        totalLessons: 20,
        completedLessons: 0,
        estimatedTime: '7 weeks',
        skills: ['Docker', 'Kubernetes', 'AWS', 'CI/CD'],
        modules: [],
      ),
    ];
  }
}

class Module {
  final String id;
  final String title;
  final int lessonCount;
  final int completedCount;
  final bool isLocked;
  final List<Lesson> lessons;

  const Module({
    required this.id,
    required this.title,
    required this.lessonCount,
    this.completedCount = 0,
    this.isLocked = false,
    this.lessons = const [],
  });

  double get progress =>
      lessonCount > 0 ? completedCount / lessonCount : 0.0;

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      lessonCount: json['lesson_count'] ?? 0,
      completedCount: json['completed_count'] ?? 0,
      isLocked: json['is_locked'] ?? false,
      lessons: json['lessons'] != null
          ? (json['lessons'] as List)
              .map((l) => Lesson.fromJson(l))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lesson_count': lessonCount,
      'completed_count': completedCount,
      'is_locked': isLocked,
      'lessons': lessons.map((l) => l.toJson()).toList(),
    };
  }
}

class Lesson {
  final String id;
  final String title;
  final String youtubeVideoId;
  final String duration;
  final String description;
  final bool isCompleted;
  final List<Chapter> chapters;

  const Lesson({
    required this.id,
    required this.title,
    required this.youtubeVideoId,
    this.duration = '',
    this.description = '',
    this.isCompleted = false,
    this.chapters = const [],
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      youtubeVideoId: json['youtube_video_id'] ?? '',
      duration: json['duration'] ?? '',
      description: json['description'] ?? '',
      isCompleted: json['is_completed'] ?? false,
      chapters: json['chapters'] != null
          ? (json['chapters'] as List)
              .map((c) => Chapter.fromJson(c))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'youtube_video_id': youtubeVideoId,
      'duration': duration,
      'description': description,
      'is_completed': isCompleted,
      'chapters': chapters.map((c) => c.toJson()).toList(),
    };
  }
}

class Chapter {
  final String title;
  final String timestamp;

  const Chapter({
    required this.title,
    required this.timestamp,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      title: json['title'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'timestamp': timestamp,
    };
  }
}

class PulseEvent {
  final String id;
  final String userName;
  final String action;
  final String courseName;
  final String timeAgo;

  const PulseEvent({
    required this.id,
    required this.userName,
    required this.action,
    required this.courseName,
    required this.timeAgo,
  });

  factory PulseEvent.fromJson(Map<String, dynamic> json) {
    return PulseEvent(
      id: json['id'] ?? '',
      userName: json['user_name'] ?? '',
      action: json['action'] ?? '',
      courseName: json['course_name'] ?? '',
      timeAgo: json['time_ago'] ?? '',
    );
  }

  /// Mock pulse events for social FOMO
  static List<PulseEvent> mockEvents() {
    return const [
      PulseEvent(
        id: 'pulse_001',
        userName: 'Priya',
        action: 'completed',
        courseName: 'Python Basics',
        timeAgo: '2m ago',
      ),
      PulseEvent(
        id: 'pulse_002',
        userName: 'Arjun',
        action: 'started',
        courseName: 'ML Fundamentals',
        timeAgo: '5m ago',
      ),
      PulseEvent(
        id: 'pulse_003',
        userName: 'Sneha',
        action: 'scored 95% on',
        courseName: 'Data Visualization Quiz',
        timeAgo: '8m ago',
      ),
      PulseEvent(
        id: 'pulse_004',
        userName: 'Vikram',
        action: 'hit a 14-day streak in',
        courseName: 'Web Development',
        timeAgo: '12m ago',
      ),
      PulseEvent(
        id: 'pulse_005',
        userName: 'Ananya',
        action: 'enrolled in',
        courseName: 'Flutter App Development',
        timeAgo: '15m ago',
      ),
    ];
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options:
          json['options'] != null ? List<String>.from(json['options']) : const [],
      correctIndex: json['correct_index'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }

  /// Mock quiz questions for offline-first experience
  static List<QuizQuestion> mockQuestions() {
    return const [
      QuizQuestion(
        id: 'q_001',
        question: 'What is the output of print(type(42)) in Python?',
        options: [
          "<class 'int'>",
          "<class 'float'>",
          "<class 'str'>",
          "<class 'number'>",
        ],
        correctIndex: 0,
        explanation:
            'In Python, integers are of type int. The type() function returns the class of the object.',
      ),
      QuizQuestion(
        id: 'q_002',
        question:
            'Which NumPy function creates an array of evenly spaced values?',
        options: [
          'np.zeros()',
          'np.linspace()',
          'np.random()',
          'np.full()',
        ],
        correctIndex: 1,
        explanation:
            'np.linspace() creates an array of evenly spaced values over a specified interval.',
      ),
      QuizQuestion(
        id: 'q_003',
        question: 'What does the Pandas .describe() method return?',
        options: [
          'Column names',
          'Data types of each column',
          'Summary statistics of numerical columns',
          'Number of null values',
        ],
        correctIndex: 2,
        explanation:
            '.describe() generates descriptive statistics including count, mean, std, min, max, and quartiles.',
      ),
    ];
  }
}

/// Chat message for AI doubt resolution
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// User's dream/goal
class Dream {
  final String text;
  final DateTime createdAt;
  final String? generatedCourseId;

  const Dream({
    required this.text,
    required this.createdAt,
    this.generatedCourseId,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'created_at': createdAt.toIso8601String(),
        'generated_course_id': generatedCourseId,
      };

  factory Dream.fromJson(Map<String, dynamic> json) {
    return Dream(
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      generatedCourseId: json['generated_course_id'],
    );
  }
}
