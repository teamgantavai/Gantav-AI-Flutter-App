import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/onboarding_service.dart';
import '../services/admin_service.dart';
import '../services/course_roadmap_builder.dart';

import '../models/trending_data.dart';
import 'dart:math' as math;
import 'package:firebase_analytics/firebase_analytics.dart';

enum AuthStatus {
  unauthenticated,
  authenticated,
  skipped,
  needsVerification,
  needsOnboarding
}

/// 12D.3 — Payload emitted when the user earns coins.
/// The UI layer listens and triggers the coin-fly animation.
class CoinEarnedEvent {
  final int coins;
  final String reason; // e.g. "Lesson completed"
  CoinEarnedEvent({required this.coins, required this.reason});
}

/// 12D.2 — Payload emitted when a streak increments so the UI can
/// trigger confetti / flame-pulse without polling.
class StreakBumpEvent {
  final int newStreak;
  StreakBumpEvent(this.newStreak);
}

class AppState extends ChangeNotifier {
  final _analytics = FirebaseAnalytics.instance;
  ThemeMode _themeMode = ThemeMode.dark;
  UserProfile? _user;
  String? _profileImagePath;
  List<Course> _courses = [];
  List<PulseEvent> _pulseEvents = [];
  bool _isLoading = true;
  bool _isInitialLoading = true;
  int _currentTabIndex = 0;
  Dream? _dream;
  final List<Course> _generatedCourses = [];
  AuthStatus _authStatus = AuthStatus.unauthenticated;
  bool _isGeneratingCourse = false;
  bool _isLoadingMore = false;
  int _courseBatchIndex = 0;

  /// Maximum number of AI-generated courses allowed. Prevents runaway API
  /// usage — users should remove old courses before generating new ones.
  static const int maxCourses = 5;
  String? _authError;
  String? _notificationMessage;
  Course? _lastCompletedCourse;

  UserPreferences? _preferences;
  List<Roadmap> _roadmaps = [];
  bool _needsOnboarding = false;
  bool _isGeneratingRoadmap = false;
  final Set<String> _starredLessonIds = {};
  final Set<String> _savedCourseIds = {};

  // ── Quiz Score Tracking ──────────────────────────────────────────────
  /// Maps courseId → best quiz score (0.0 to 1.0). Persisted locally.
  final Map<String, double> _quizScores = {};

  // ── Flip Course Tracking ─────────────────────────────────────────────
  /// Maps courseId → number of flips used (max 3).
  final Map<String, int> _flipCounts = {};
  final Map<String, List<String>> _flipExcludedVideoIds = {};
  /// Maps courseId → list of excluded channel names/IDs from previous flips.
  final Map<String, List<String>> _flipExcludedChannelIds = {};
  static const int maxFlips = 2;

  bool _dreamCollectedInOnboarding = false;
  bool get dreamCollectedInOnboarding => _dreamCollectedInOnboarding;

  /// 12D.3 — latest coin-earned event; UI watches and clears after animating
  CoinEarnedEvent? _coinEarnedEvent;
  CoinEarnedEvent? get coinEarnedEvent => _coinEarnedEvent;

  /// 12D.2 — latest streak-bump event; UI watches and clears after animating
  StreakBumpEvent? _streakBumpEvent;
  StreakBumpEvent? get streakBumpEvent => _streakBumpEvent;

  void clearCoinEarnedEvent() {
    if (_coinEarnedEvent != null) {
      _coinEarnedEvent = null;
      notifyListeners();
    }
  }

  void clearStreakBumpEvent() {
    if (_streakBumpEvent != null) {
      _streakBumpEvent = null;
      notifyListeners();
    }
  }

  /// 12D.5 — per-card language override map: cardId → 'en' | 'hi'
  final Map<String, String> _trendingCardLang = {};

  String trendingCardLang(TrendingCourse t) =>
      _trendingCardLang[t.id] ?? t.defaultLang;

  void setTrendingCardLang(TrendingCourse t, String lang) {
    _trendingCardLang[t.id] = lang;
    notifyListeners();
  }

  final FirestoreService _firestoreService = FirestoreService();

  // Getters
  ThemeMode get themeMode => _themeMode;
  UserProfile? get user => _user;
  String? get profileImagePath => _profileImagePath;

  // Weekly Course Generation Limit
  static const int maxWeeklyGenerations = 5;

  int get weeklyGenerationsLeft {
    if (_user == null) return maxWeeklyGenerations;
    final now = DateTime.now();
    if (_user!.lastGenerationDate == null) return maxWeeklyGenerations;
    
    // Check if the last generation was in the same week
    // We'll use a simple week calculation (ISO week or just days since epoch / 7)
    // For simplicity, we can check if it's within 7 days AND the same week start.
    // Or just use Jiffy or similar if available. But let's use native Dart.
    
    final lastGen = _user!.lastGenerationDate!;
    // Calculate week start for both (Sunday as start)
    final nowWeekStart = now.subtract(Duration(days: now.weekday % 7));
    final lastWeekStart = lastGen.subtract(Duration(days: lastGen.weekday % 7));
    
    final isSameWeek = nowWeekStart.year == lastWeekStart.year &&
                       nowWeekStart.month == lastWeekStart.month &&
                       nowWeekStart.day == lastWeekStart.day;

    if (isSameWeek) {
      final left = maxWeeklyGenerations - _user!.dailyGenerations; // We'll keep the field name for now
      return left > 0 ? left : 0;
    }
    
    // It's a new week, limit resets
    return maxWeeklyGenerations;
  }

  Future<void> _incrementDailyGenerations() async {
    if (_user == null) return;
    
    final now = DateTime.now();
    int newCount = 1;
    
    final lastGen = _user!.lastGenerationDate;
    if (lastGen != null) {
      final nowWeekStart = now.subtract(Duration(days: now.weekday % 7));
      final lastWeekStart = lastGen.subtract(Duration(days: lastGen.weekday % 7));
      
      final isSameWeek = nowWeekStart.year == lastWeekStart.year &&
                         nowWeekStart.month == lastWeekStart.month &&
                         nowWeekStart.day == lastWeekStart.day;
                         
      if (isSameWeek) {
        newCount = _user!.dailyGenerations + 1;
      }
    }
    
    _user = _user!.copyWith(
      dailyGenerations: newCount,
      lastGenerationDate: now,
    );
    notifyListeners();
    await _firestoreService.saveUserProfile(_user!);
  }

  List<Course>? _coursesCache;
  List<Course> get courses {
    final cached = _coursesCache;
    if (cached != null) return cached;
    final seen = <String>{};
    final out = <Course>[];
    for (final c in _courses) {
      if (seen.add(c.id)) out.add(c);
    }
    for (final c in _generatedCourses) {
      if (seen.add(c.id)) out.add(c);
    }
    final result = List<Course>.unmodifiable(out);
    _coursesCache = result;
    return result;
  }

  @override
  void notifyListeners() {
    _coursesCache = null;
    super.notifyListeners();
  }

  List<Course> get activeCourses {
    if (isAuthenticated && _generatedCourses.isNotEmpty) {
      final seen = <String>{};
      final result = <Course>[];
      for (final c in _generatedCourses) {
        if (!seen.add(c.id)) continue;
        final notFullyDone =
            c.totalLessons == 0 || c.completedLessons < c.totalLessons;
        if (notFullyDone) result.add(c);
      }
      for (final c in _courses) {
        if (c.isInProgress && seen.add(c.id)) result.add(c);
      }
      return result;
    }
    return courses.where((c) => c.isInProgress).toList();
  }

  List<Course> get favoriteCourses {
    return courses.where((c) => _savedCourseIds.contains(c.id)).toList();
  }

  bool isCourseSaved(String courseId) => _savedCourseIds.contains(courseId);

  Future<void> toggleSaveCourse(String courseId) async {
    if (_savedCourseIds.contains(courseId)) {
      _savedCourseIds.remove(courseId);
    } else {
      _savedCourseIds.add(courseId);
    }
    await _saveLocalSavedCourses();
    await _firestoreService.saveSavedCourseIds(_savedCourseIds.toList());
    notifyListeners();
  }

  /// Default suggestion data for first-time users who have no courses yet.
  static final List<Course> _defaultSuggestions = [
    Course(
      id: 'default_1', title: 'Python for Beginners', description: 'Start coding with Python',
      category: 'Programming', thumbnailUrl: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=500&q=80', rating: 4.8, learnerCount: 12400,
      totalLessons: 9, skills: ['Variables', 'Functions', 'OOP'], modules: [],
    ),
    Course(
      id: 'default_2', title: 'Web Development Bootcamp', description: 'HTML, CSS, JS',
      category: 'Web Development', thumbnailUrl: 'https://images.unsplash.com/photo-1547658719-da2b51169166?w=500&q=80', rating: 4.7, learnerCount: 9800,
      totalLessons: 12, skills: ['HTML', 'CSS', 'JavaScript'], modules: [],
    ),
    Course(
      id: 'default_3', title: 'Flutter App Development', description: 'Build cross-platform apps',
      category: 'Mobile Development', thumbnailUrl: 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=500&q=80', rating: 4.9, learnerCount: 7600,
      totalLessons: 9, skills: ['Dart', 'Widgets', 'State'], modules: [],
    ),
    Course(
      id: 'default_4', title: 'Machine Learning Basics', description: 'Learn ML fundamentals',
      category: 'AI & ML', thumbnailUrl: 'https://images.unsplash.com/photo-1555949963-ff9fe0c870eb?w=500&q=80', rating: 4.8, learnerCount: 11200,
      totalLessons: 9, skills: ['NumPy', 'Pandas', 'Scikit-learn'], modules: [],
    ),
    Course(
      id: 'default_5', title: 'Data Science with Python', description: 'Analyze and visualize data',
      category: 'Data Science', thumbnailUrl: 'https://images.unsplash.com/photo-1551288049-bbbda536ad4a?w=500&q=80', rating: 4.7, learnerCount: 8500,
      totalLessons: 9, skills: ['Pandas', 'Matplotlib', 'Stats'], modules: [],
    ),
    Course(
      id: 'default_6', title: 'React & Node.js Fullstack', description: 'Full-stack JavaScript',
      category: 'Web Development', thumbnailUrl: 'https://images.unsplash.com/photo-1633356122544-f134324a6cee?w=500&q=80', rating: 4.8, learnerCount: 10300,
      totalLessons: 12, skills: ['React', 'Node.js', 'MongoDB'], modules: [],
    ),
  ];

  List<Course> get suggestedCourses {
    final real = courses.where((c) => !c.isInProgress).toList();
    if (real.isEmpty) return _defaultSuggestions;
    return real;
  }
  List<PulseEvent> get pulseEvents => _pulseEvents;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading;
  int get currentTabIndex => _currentTabIndex;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Dream? get dream => _dream;
  List<Course> get generatedCourses => _generatedCourses;
  bool get hasDream => _dream != null;
  AuthStatus get authStatus => _authStatus;
  bool get isAuthenticated =>
      _authStatus == AuthStatus.authenticated ||
      _authStatus == AuthStatus.skipped;
  bool get isGeneratingCourse => _isGeneratingCourse;
  bool get isLoadingMore => _isLoadingMore;
  String? get authError => _authError;
  String? get notificationMessage => _notificationMessage;
  Course? get lastCompletedCourse => _lastCompletedCourse;

  UserPreferences? get preferences => _preferences;
  List<Roadmap> get roadmaps => _roadmaps;
  bool get needsOnboarding => _needsOnboarding;
  bool get isGeneratingRoadmap => _isGeneratingRoadmap;

  Roadmap? get activeRoadmap =>
      _roadmaps.isNotEmpty ? _roadmaps.first : null;
  RoadmapDay? get todayRoadmapDay => activeRoadmap?.todayDay;
  int get todayCompletedTasks => todayRoadmapDay?.completedTaskCount ?? 0;
  int get todayTotalTasks => todayRoadmapDay?.tasks.length ?? 0;
  bool get isTodayComplete => todayRoadmapDay?.allTasksCompleted ?? false;

  List<Lesson> get starredLessons {
    final List<Lesson> starred = [];
    for (final course in courses) {
      for (final module in course.modules) {
        for (final lesson in module.lessons) {
          if (_starredLessonIds.contains(lesson.id)) {
            starred.add(lesson);
          }
        }
      }
    }
    return starred;
  }

  void clearNotification() {
    if (_notificationMessage != null) {
      _notificationMessage = null;
      _lastCompletedCourse = null;
      notifyListeners();
    }
  }

  void showNotification(String message) {
    _notificationMessage = message;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    _isInitialLoading = true;
    notifyListeners();

    // Start a timer to ensure splash screen shows for at least 2 seconds
    final splashFuture = Future.delayed(const Duration(milliseconds: 2200));

    await _loadThemePreference();
    await _loadAuthStatus();
    await _loadDream();
    await _loadLocalCourses();
    await _loadLocalPreferences();
    await _loadLocalRoadmaps();
    await _loadStarredLessons();
    await _loadSavedCourses();
    await _loadQuizScores();
    await _loadFlipData();

    final firebaseUser = AuthService.currentUser;
    if (firebaseUser != null &&
        _authStatus == AuthStatus.unauthenticated) {
      _authStatus = AuthStatus.authenticated;
      await _loadUserFromFirebase(firebaseUser);
    }

    if (_authStatus != AuthStatus.unauthenticated) {
      await refresh();
    } else {
      _isLoading = false;
    }

    // Wait for the splash timer to complete before hiding the splash screen
    await splashFuture;
    
    _isInitialLoading = false;
    notifyListeners();

    // Surface stale API-key warnings — if a provider's key returned 401 on
    // a previous session, nudge the user to regenerate it. Fire-and-forget
    // so startup never blocks on this.
    // GeminiService.loadAndReportDeadKeys().then((dead) {
    //   if (dead.isEmpty) return;
    //   final pretty = dead
    //       .map((n) => n[0].toUpperCase() + n.substring(1))
    //       .join(', ');
    //   showNotification(
    //       '⚠ $pretty API key looks invalid (401). Regenerate it and update your .env to restore full AI.');
    // }).catchError((_) {});
  }

  Future<void> _loadUserFromFirebase(dynamic firebaseUser) async {
    final firestoreProfile = await _firestoreService.getUserProfile();
    if (firestoreProfile != null) {
      _user = firestoreProfile;
    } else {
      _user = UserProfile(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'Learner',
        handle: (firebaseUser.displayName ?? 'learner')
            .toLowerCase()
            .replaceAll(' ', ''),
        email: firebaseUser.email ?? '',
        gantavScore: 0,
        streakDays: 0,
        lessonsCompleted: 0,
        quizzesPassed: 0,
        weekActivity: List.filled(7, false),
        coins: 0,
      );
    }

    final storedCourses = await _firestoreService.getActiveCourses();
    if (storedCourses.isNotEmpty) {
      _generatedCourses.clear();
      _generatedCourses.addAll(storedCourses);
    }

    final prefs = await _firestoreService.getUserPreferences();
    if (prefs != null) {
      _preferences = prefs;
      _needsOnboarding = false;
    }

    final firestoreRoadmaps = await _firestoreService.getRoadmaps();
    if (firestoreRoadmaps.isNotEmpty) {
      _roadmaps = firestoreRoadmaps;
      await _saveLocalRoadmaps();
    }

    final firestoreStarred = await _firestoreService.getStarredLessonIds();
    if (firestoreStarred.isNotEmpty) {
      _starredLessonIds.addAll(firestoreStarred);
      await _saveLocalStarredLessons();
    }

    final firestoreSaved = await _firestoreService.getSavedCourseIds();
    if (firestoreSaved.isNotEmpty) {
      _savedCourseIds.addAll(firestoreSaved);
      await _saveLocalSavedCourses();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ═══════════════════════════════════════════════════════════════════════

  Future<bool> signInWithGoogle() async {
    _authError = null;
    _isLoading = true;
    notifyListeners();

    final result = await AuthService.signInWithGoogle();

    if (!result.success) {
      _authError = result.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Clear stale local data from a previous account to prevent cross-account
    // leakage (e.g. old profile photo appearing on the new account).
    await _clearAllLocalUserData();

    await _loadUserFromFirebase(result.user);
    await _saveAuthStatus();

    if (result.isNewUser && _user != null) {
      await _firestoreService.saveUserProfile(_user!);
    }
    // Skip the forced roadmap-onboarding flow — users land on the main app
    // after sign-in. Preferences get defaults (dailyStudyMinutes = 30) and the
    // user can tune them from Profile later. Previously we forced everyone
    // through a 3-step onboarding which killed retention.
    _authStatus = AuthStatus.authenticated;
    _needsOnboarding = false;

    _isLoading = false;
    notifyListeners();
    if (_authStatus == AuthStatus.authenticated) {
      await refresh();
    }
    return true;
  }

  Future<bool> signInWithEmail(
      {required String email, required String password}) async {
    _authError = null;
    _isLoading = true;
    notifyListeners();

    final result = await AuthService.signInWithEmail(
        email: email, password: password);

    if (!result.success || result.user == null) {
      _authError = result.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (!result.user!.emailVerified) {
      _authStatus = AuthStatus.needsVerification;
      _isLoading = false;
      notifyListeners();
      return true;
    }

    // Clear stale local data from a previous account to prevent cross-account
    // leakage (e.g. old profile photo appearing on the new account).
    await _clearAllLocalUserData();

    await _loadUserFromFirebase(result.user);
    await _saveAuthStatus();

    // Forced onboarding removed (see Google sign-in path above). Users go
    // straight to main app after verified sign-in.
    _authStatus = AuthStatus.authenticated;
    _needsOnboarding = false;

    _isLoading = false;
    notifyListeners();
    await refresh();
    return true;
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    _authError = null;
    _isLoading = true;
    notifyListeners();

    final result = await AuthService.signUpWithEmail(
        email: email, password: password, name: name);

    if (!result.success || result.user == null) {
      _authError = result.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final verifyResult = await AuthService.sendEmailVerification();
    if (!verifyResult.success) {
      _authError = verifyResult.error ?? 'Account created, but failed to send verification email.';
      // We still proceed so the user can be on the verification screen to hit "Resend"
    }
    _authStatus = AuthStatus.needsVerification;
    _user = UserProfile(
      id: result.user!.uid,
      name: name,
      handle: name.toLowerCase().replaceAll(' ', ''),
      email: email,
      gantavScore: 0,
      streakDays: 0,
      lessonsCompleted: 0,
      quizzesPassed: 0,
      weekActivity: List.filled(7, false),
      coins: 0,
    );

    await _firestoreService.saveUserProfile(_user!);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> checkEmailVerification() async {
    final user = AuthService.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified) {
        await _loadUserFromFirebase(user);
        // Straight into main app — no onboarding gate.
        _authStatus = AuthStatus.authenticated;
        _needsOnboarding = false;
        await _saveAuthStatus();
        await refresh();
      } else {
        _authError = 'Email not yet verified. Please check your inbox.';
      }
      notifyListeners();
    }
  }

  /// Sends a Firebase password-reset email to [email]. Returns null on
  /// success, or a user-facing error string on failure. Called from the
  /// auth screen's "Forgot password?" link.
  Future<String?> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    final validationError = AuthService.validateEmail(trimmed);
    if (validationError != null) return validationError;
    return AuthService.sendPasswordResetEmail(trimmed);
  }

  Future<void> resendVerification() async {
    final result = await AuthService.sendEmailVerification();
    if (result.success) {
      showNotification('Verification email resent! Please check your inbox.');
    } else {
      _authError = result.error;
    }
    notifyListeners();
  }

  Future<void> signInAndGenerate(
      {required String dream, String? name}) async {
    _isLoading = true;
    notifyListeners();

    _authStatus = AuthStatus.authenticated;
    _user = UserProfile(
      id: AuthService.currentUser?.uid ?? 'user_001',
      name: name ?? AuthService.currentUser?.displayName ?? 'Learner',
      handle:
          (name ?? 'learner').toLowerCase().replaceAll(' ', ''),
      email: AuthService.currentUser?.email ?? 'user@gantavai.com',
      gantavScore: 0,
      streakDays: 0,
      lessonsCompleted: 0,
      quizzesPassed: 0,
      weekActivity: List.filled(7, false),
      coins: 0,
    );

    await _saveAuthStatus();
    await setDream(dream);

    _isGeneratingCourse = true;
    _isLoading = false;
    notifyListeners();

    await _generateCourse(dream);
    await refresh();

    _isGeneratingCourse = false;
    notifyListeners();
  }

  Future<void> skipAuth() async {
    _authStatus = AuthStatus.skipped;
    _user = UserProfile.mock();
    await _saveAuthStatus();
    await refresh();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ONBOARDING & ROADMAP
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> completeOnboarding(UserPreferences prefs) async {
    _preferences = prefs;
    _needsOnboarding = false;
    _isGeneratingRoadmap = true;
    _authStatus = AuthStatus.authenticated;
    notifyListeners();

    try {
      await _saveLocalPreferences();
      await _firestoreService.saveUserPreferences(prefs).catchError((_) {});

      final roadmap = await OnboardingService.generateRoadmap(prefs);
      if (roadmap != null) {
        _roadmaps.insert(0, roadmap);
        await _saveLocalRoadmaps();
        await _firestoreService.saveRoadmap(roadmap).catchError((_) {});
      }
    } catch (e) {
      debugPrint('[AppState] Error completing onboarding: $e');
    } finally {
      _isGeneratingRoadmap = false;
      await _saveAuthStatus();
      notifyListeners();
      refresh();
    }
  }

  void markTaskComplete(String roadmapId, int dayNumber, String taskId) {
    final roadmapIdx = _roadmaps.indexWhere((r) => r.id == roadmapId);
    if (roadmapIdx == -1) return;

    final roadmap = _roadmaps[roadmapIdx];
    final dayIdx =
        roadmap.days.indexWhere((d) => d.dayNumber == dayNumber);
    if (dayIdx == -1) return;

    final day = roadmap.days[dayIdx];
    final taskIdx = day.tasks.indexWhere((t) => t.id == taskId);
    if (taskIdx == -1) return;

    day.tasks[taskIdx].isCompleted = true;
    day.tasks[taskIdx].completedAt = DateTime.now();

    if (day.allTasksCompleted) {
      day.isCompleted = true;
      day.completedAt = DateTime.now();
    }

    if (roadmap.isComplete) {
      roadmap.completedAt = DateTime.now();
    }

    _updateUserProgressStats();

    notifyListeners();
    _saveLocalRoadmaps();
    _firestoreService.updateRoadmap(roadmap).catchError((_) {});
  }

  void toggleTaskComplete(
      String roadmapId, int dayNumber, String taskId) {
    final roadmapIdx = _roadmaps.indexWhere((r) => r.id == roadmapId);
    if (roadmapIdx == -1) return;

    final roadmap = _roadmaps[roadmapIdx];
    final dayIdx =
        roadmap.days.indexWhere((d) => d.dayNumber == dayNumber);
    if (dayIdx == -1) return;

    final day = roadmap.days[dayIdx];
    final taskIdx = day.tasks.indexWhere((t) => t.id == taskId);
    if (taskIdx == -1) return;

    final task = day.tasks[taskIdx];
    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;

    day.isCompleted = day.allTasksCompleted;
    day.completedAt = day.isCompleted ? DateTime.now() : null;
    roadmap.completedAt = roadmap.isComplete ? DateTime.now() : null;

    _updateUserProgressStats();

    notifyListeners();
    _saveLocalRoadmaps();
    _firestoreService.updateRoadmap(roadmap).catchError((_) {});
  }

  /// Updates gantav score, streak, week activity, and coins from roadmap data.
  void _updateUserProgressStats() {
    if (_user == null || _roadmaps.isEmpty) return;

    int totalCompletedTasks = 0;
    int completedDays = 0;
    final prevStreak = _user!.streakDays;

    for (final roadmap in _roadmaps) {
      totalCompletedTasks += roadmap.completedTasks;
      completedDays += roadmap.completedDays;
    }

    final newScore = totalCompletedTasks * 10;

    int streak = 0;
    if (_roadmaps.isNotEmpty) {
      final roadmap = _roadmaps.first;
      final today = roadmap.currentDayNumber;
      for (int d = today; d >= 1; d--) {
        try {
          final day = roadmap.days.firstWhere((day) => day.dayNumber == d);
          if (day.isCompleted || (d == today && day.progress > 0)) {
            streak++;
          } else {
            break;
          }
        } catch (_) {
          break;
        }
      }
    }

    final weekActivity = List<bool>.from(_user!.weekActivity);
    final todayWeekday = DateTime.now().weekday - 1;
    if (todayWeekday < 7) {
      final todayRoadmapDay = activeRoadmap?.todayDay;
      weekActivity[todayWeekday] =
          (todayRoadmapDay?.completedTaskCount ?? 0) > 0;
    }

    // 12D.2 — fire streak bump event when streak increments
    if (streak > prevStreak && streak > 0) {
      _streakBumpEvent = StreakBumpEvent(streak);
    }

    _user = UserProfile(
      id: _user!.id,
      name: _user!.name,
      handle: _user!.handle,
      email: _user!.email,
      gantavScore: newScore,
      streakDays: streak,
      lessonsCompleted: completedDays,
      quizzesPassed: _user!.quizzesPassed,
      weekActivity: weekActivity,
      coins: _user!.coins,
    );

    _firestoreService.saveUserProfile(_user!).catchError((_) {});
    _saveAuthStatus();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COURSE GENERATION
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _generateCourse(String dream) async {
    final course = await ApiService.suggestPath(dream, language: _preferredLang);
    if (course != null) {
      _generatedCourses.add(course);
      await _firestoreService.saveActiveCourse(course);
      notifyListeners();
    }
  }

  String get _preferredLang {
    final code = _preferences?.language;
    return code == 'hi' ? 'Hindi' : 'English';
  }

  Future<Roadmap?> buildRoadmapForCourse(
      Course course, int dailyMinutes) async {
    try {
      final roadmap = CourseRoadmapBuilder.buildFromCourse(
        course: course,
        dailyMinutes: dailyMinutes,
        language: _preferences?.language == 'hi' ? 'hi' : 'en',
      );
      _roadmaps.insert(0, roadmap);
      await _saveLocalRoadmaps();
      _firestoreService.saveRoadmap(roadmap).catchError((_) {});
      notifyListeners();
      return roadmap;
    } catch (e) {
      debugPrint('[AppState] buildRoadmapForCourse failed: $e');
      return null;
    }
  }

  Future<Course?> generateCourseFromCategory(String prompt) async {
    if (_generatedCourses.length >= maxCourses) return null;
    try {
      final course = await ApiService.suggestPath(prompt, language: _preferredLang)
          .timeout(const Duration(seconds: 60), onTimeout: () => null);
      if (course != null && _generatedCourses.length < maxCourses) {
        _generatedCourses.add(course);
        await _saveLocalCourses();
        await _firestoreService.saveActiveCourse(course);
      }

      notifyListeners();
      return course;
    } catch (_) {
      notifyListeners();
      return null;
    }
  }

  void cancelGeneration() {
    _isGeneratingCourse = false;
    _isGeneratingRoadmap = false;
    notifyListeners();
  }

  Future<void> generateCourseInBackground(
      String prompt, String dreamTopic,
      {int? dailyMinutes}) async {
    // ── Limits removed per user request ───────────────────────────────
    
    _isGeneratingCourse = true;
    showNotification(
        'AI is creating your learning path in the background. You will be notified when it is ready!');
    notifyListeners();

    try {
      final curated = await AdminService.findMatchingVerifiedCourse(prompt);
      if (curated != null) {
        await addGeneratedCourse(curated);
        await setDream(dreamTopic, courseId: curated.id);
        _lastCompletedCourse = curated;
        _isGeneratingCourse = false;
        showNotification('Found a curated course for $dreamTopic!');
        notifyListeners();
        return;
      }

      final course = await ApiService.suggestPath(prompt, language: _preferredLang)
          .timeout(const Duration(seconds: 60), onTimeout: () => null);
      if (course != null) {
        await addGeneratedCourse(course);
        await setDream(dreamTopic, courseId: course.id);
        _lastCompletedCourse = course;
        final minutes = dailyMinutes ?? _preferences?.dailyStudyMinutes ?? 30;
        await buildRoadmapForCourse(course, minutes);
        await _incrementDailyGenerations();
        showNotification(
            'Success: Your new course "${course.title}" is ready!');
      } else {
        showNotification(
            'Error: Failed to generate course. Please try again.');
      }
    } catch (e) {
      showNotification(
          'Error: Something went wrong generating your course.');
    } finally {
      _isGeneratingCourse = false;
      notifyListeners();
    }
  }

  // ─── Trending angle rotator ───────────────────────────────────────────
  final Map<String, List<int>> _trendingAngleQueue = {};
  final math.Random _trendingRng = math.Random();

  /// 12D.5 — Compose a fresh prompt for a trending card, respecting the
  /// per-card language override.
  String pickTrendingPrompt(TrendingCourse t) {
    if (t.angles.isEmpty) return t.promptHint;
    var queue = _trendingAngleQueue[t.id];
    if (queue == null || queue.isEmpty) {
      queue = List<int>.generate(t.angles.length, (i) => i)..shuffle(_trendingRng);
      _trendingAngleQueue[t.id] = queue;
    }
    final idx = queue.removeAt(0);
    final angle = t.angles[idx];
    return '$angle. Context: ${t.promptHint}';
  }

  /// 12D.5 — Returns 'English' or 'Hindi' for the YouTube search language
  /// for this trending card, respecting the user's per-card toggle.
  String pickTrendingLang(TrendingCourse t) {
    final code = trendingCardLang(t);
    return code == 'hi' ? 'Hindi' : 'English';
  }

  Future<void> generateCourseInBackgroundFromCategory(String promptHint,
      {int? dailyMinutes, bool allowCurated = true, String language = 'English'}) async {
    // ── Limits removed per user request ───────────────────────────────
    
    _isGeneratingCourse = true;
    notifyListeners();

    try {
      if (allowCurated) {
        final curated = await AdminService.findMatchingVerifiedCourse(promptHint);
        if (curated != null) {
          await addGeneratedCourse(curated);
          _isGeneratingCourse = false;
          showNotification('Found a professional curated course for "$promptHint"!');
          notifyListeners();
          return;
        }
      }

      final course = await ApiService.suggestPath(
              promptHint,
              language: language.isNotEmpty ? language : _preferredLang,
              allowCurated: allowCurated)
          .timeout(const Duration(seconds: 60), onTimeout: () => null);
      if (course != null) {
        _generatedCourses.add(course);
        await _saveLocalCourses();
        await _firestoreService.saveActiveCourse(course);
        _lastCompletedCourse = course;
        final minutes = dailyMinutes ?? _preferences?.dailyStudyMinutes ?? 30;
        await buildRoadmapForCourse(course, minutes);
        await _incrementDailyGenerations();
        
        _analytics.logEvent(name: 'course_generated', parameters: {
          'topic': promptHint,
          'category': course.category,
          'lesson_count': course.totalLessons,
        });
        
        showNotification('Success: Your course "${course.title}" is ready!');
      } else {
        showNotification(
            'Error: Could not generate course. AI servers may be busy. Please try again.');
      }
    } catch (e) {
      showNotification(
          'Error: Something went wrong generating your course.');
    } finally {
      _isGeneratingCourse = false;
      notifyListeners();
    }
  }

  /// Remove a course from the user's library. Frees up a slot for new
  /// generations.
  Future<void> deleteCourse(String courseId) async {
    _generatedCourses.removeWhere((c) => c.id == courseId);
    _courses.removeWhere((c) => c.id == courseId);
    _savedCourseIds.remove(courseId);
    
    await _saveLocalCourses();
    await _saveLocalSavedCourses();
    await _firestoreService.deleteCourse(courseId);
    
    _analytics.logEvent(name: 'course_deleted', parameters: {'course_id': courseId});
    
    notifyListeners();
  }

  Future<void> generateNextCourseBatch() async {
    if (_isLoadingMore) return;
    // ── Max course guard ──────────────────────────────────────────────
    if (_generatedCourses.length >= maxCourses) return;

    _isLoadingMore = true;
    notifyListeners();

    _courseBatchIndex++;
    final topics = [
      'Python programming for beginners',
      'Web development with React and Node.js',
      'Mobile app development with Flutter',
      'Machine learning and AI fundamentals',
      'Data science with Python and pandas',
      'Cloud computing with AWS',
      'Cybersecurity essentials',
      'UI/UX design principles',
      'Blockchain and Web3 development',
      'DevOps and CI/CD pipelines',
      'Game development with Unity',
      'iOS development with Swift',
      'Backend development with Go',
      'Full-stack JavaScript development',
      'Database design and SQL mastery',
    ];

    // Only generate 1 course at a time to conserve API quota.
    final topicIdx =
        ((_courseBatchIndex - 1)) % topics.length;
    try {
      final course = await ApiService.suggestPath(
              topics[topicIdx], language: _preferredLang)
          .timeout(const Duration(seconds: 40), onTimeout: () => null);
      if (course != null && _generatedCourses.length < maxCourses) {
        _generatedCourses.add(course);
        await _firestoreService.saveActiveCourse(course);
      }
    } catch (_) {}

    _isLoadingMore = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _saveAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authStatus', _authStatus.name);
      if (_user != null) {
        await prefs.setString('user', jsonEncode(_user!.toJson()));
      }
    } catch (_) {}
  }

  Future<void> _loadAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dreamCollectedInOnboarding =
          prefs.getBool('dream_collected') ?? false;
      final status = prefs.getString('authStatus');
      if (status == AuthStatus.authenticated.name) {
        _authStatus = AuthStatus.authenticated;
        final userJson = prefs.getString('user');
        if (userJson != null) {
          _user = UserProfile.fromJson(jsonDecode(userJson));
        }
      } else if (status == AuthStatus.skipped.name) {
        _authStatus = AuthStatus.skipped;
        _user = UserProfile.mock();
      }
    } catch (_) {}
  }

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setDream(String dreamText, {String? courseId}) async {
    _dream = Dream(
      text: dreamText,
      createdAt: DateTime.now(),
      generatedCourseId: courseId,
    );
    notifyListeners();
    await _saveDream();
  }

  Future<void> clearDream() async {
    _dream = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dream');
  }

  Future<void> _loadLocalCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final coursesJson = prefs.getString('local_courses');
      if (coursesJson != null) {
        final List<dynamic> data = jsonDecode(coursesJson);
        _generatedCourses.clear();
        _generatedCourses.addAll(data.map((j) => Course.fromJson(j)));
      }
    } catch (e) {
      debugPrint('Error loading local courses: $e');
    }
  }

  Future<void> _saveLocalCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data =
          jsonEncode(_generatedCourses.map((c) => c.toJson()).toList());
      await prefs.setString('local_courses', data);
    } catch (e) {
      debugPrint('Error saving local courses: $e');
    }
  }

  Future<void> addGeneratedCourse(Course course) async {
    _generatedCourses.add(course);
    await _saveLocalCourses();
    await _firestoreService.saveActiveCourse(course);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUIZ SCORE TRACKING
  // ═══════════════════════════════════════════════════════════════════════

  /// Record a quiz score for a course. Keeps the best score per course.
  Future<void> recordQuizScore(String courseId, double score) async {
    final current = _quizScores[courseId] ?? 0.0;
    if (score > current) {
      _quizScores[courseId] = score;
      await _saveQuizScores();
      notifyListeners();
    }
  }

  /// Get the best quiz score for a course (0.0 to 1.0). Returns 0.0 if no quiz taken.
  double getQuizProgress(String courseId) => _quizScores[courseId] ?? 0.0;

  /// Whether the user has achieved ≥60% quiz score for the course.
  bool isCertificateUnlocked(String courseId) => getQuizProgress(courseId) >= 0.6;

  Future<void> _saveQuizScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _quizScores.map((k, v) => MapEntry(k, v));
      await prefs.setString('quiz_scores', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadQuizScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('quiz_scores');
      if (json != null) {
        final Map<String, dynamic> data = jsonDecode(json);
        _quizScores.clear();
        data.forEach((k, v) => _quizScores[k] = (v as num).toDouble());
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FLIP COURSE (max 3 — same structure, different YouTube channel)
  // ═══════════════════════════════════════════════════════════════════════

  /// How many flips remain for a course.
  int flipsRemaining(String courseId) => maxFlips - (_flipCounts[courseId] ?? 0);

  /// Flip a course: keep the same topic/structure but search for videos from a
  /// different YouTube channel. Returns the new course, or null if flips exhausted.
  Future<Course?> flipCourse(String courseId) async {
    if (flipsRemaining(courseId) <= 0) return null;

    final idx = _generatedCourses.indexWhere((c) => c.id == courseId);
    if (idx == -1) return null;
    final oldCourse = _generatedCourses[idx];

    _isGeneratingCourse = true;
    notifyListeners();

    try {
      final excludedVideos = _flipExcludedVideoIds[courseId] ?? [];
      final excludedChannels = _flipExcludedChannelIds[courseId] ?? [];

      if (oldCourse.channelId != null && !excludedChannels.contains(oldCourse.channelId)) {
        excludedChannels.add(oldCourse.channelId!);
      }
      for (var mod in oldCourse.modules) {
        for (var les in mod.lessons) {
          if (les.youtubeVideoId.isNotEmpty && !excludedVideos.contains(les.youtubeVideoId)) {
            excludedVideos.add(les.youtubeVideoId);
          }
          if (les.channelId != null && !excludedChannels.contains(les.channelId)) {
            excludedChannels.add(les.channelId!);
          }
        }
      }

      // Use the title (cleaned) as the topic for the flip search, as it's more specific
      // than the category (e.g. "Python for Data Science" vs "Programming").
      // Also ensure we include the category if the title is too generic.
      String topic = oldCourse.title.replaceAll('…', '').replaceAll('Complete', '').replaceAll('Course', '').trim();
      if (topic.length < 5 && oldCourse.category.isNotEmpty) {
        topic = oldCourse.category;
      }

      final newCourse = await ApiService.suggestPath(
        topic,
        language: oldCourse.language,
        allowCurated: false, // Force fresh YouTube search, no curated
        excludedVideoIds: excludedVideos,
        excludedChannelIds: excludedChannels,
      ).timeout(const Duration(seconds: 60), onTimeout: () => null);

      if (newCourse != null) {
        _flipExcludedVideoIds[courseId] = excludedVideos;
        _flipExcludedChannelIds[courseId] = excludedChannels;
        _flipCounts[courseId] = (_flipCounts[courseId] ?? 0) + 1;

        // Replace the course in-place
        _generatedCourses[idx] = newCourse;
        await _saveLocalCourses();
        await _saveFlipData();
        await _firestoreService.saveActiveCourse(newCourse);
        showNotification('Course flipped! New videos from a different source.');
      } else {
        showNotification('Could not flip course. AI servers may be busy.');
      }

      return newCourse;
    } catch (e, st) {
      debugPrint('[AppState] Error flipping course: $e\n$st');
      showNotification('Error flipping course. Please try again.');
      return null;
    } finally {
      _isGeneratingCourse = false;
      notifyListeners();
    }
  }

  Future<void> _saveFlipData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('flip_counts', jsonEncode(_flipCounts));
      await prefs.setString('flip_excluded_vids', jsonEncode(_flipExcludedVideoIds));
      await prefs.setString('flip_excluded_chans', jsonEncode(_flipExcludedChannelIds));
    } catch (_) {}
  }

  Future<void> _loadFlipData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final countsJson = prefs.getString('flip_counts');
      if (countsJson != null) {
        final Map<String, dynamic> data = jsonDecode(countsJson);
        _flipCounts.clear();
        data.forEach((k, v) => _flipCounts[k] = v as int);
      }
      final vidsJson = prefs.getString('flip_excluded_vids');
      if (vidsJson != null) {
        final Map<String, dynamic> data = jsonDecode(vidsJson);
        _flipExcludedVideoIds.clear();
        data.forEach((k, v) => _flipExcludedVideoIds[k] = List<String>.from(v));
      }
      final chansJson = prefs.getString('flip_excluded_chans');
      if (chansJson != null) {
        final Map<String, dynamic> data = jsonDecode(chansJson);
        _flipExcludedChannelIds.clear();
        data.forEach((k, v) => _flipExcludedChannelIds[k] = List<String>.from(v));
      }
    } catch (_) {}
  }

  Future<void> _saveDream() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_dream != null) {
        await prefs.setString('dream', jsonEncode(_dream!.toJson()));
      }
    } catch (_) {}
  }

  Future<void> _loadDream() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dreamJson = prefs.getString('dream');
      if (dreamJson != null) {
        _dream = Dream.fromJson(jsonDecode(dreamJson));
      }
    } catch (_) {}
  }

  Future<void> _saveLocalPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_preferences != null) {
        await prefs.setString(
            'user_preferences', jsonEncode(_preferences!.toJson()));
      }
    } catch (_) {}
  }

  Future<void> _loadLocalPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('user_preferences');
      if (json != null) {
        _preferences = UserPreferences.fromJson(jsonDecode(json));
      }
      _profileImagePath = prefs.getString('profile_image_path');
    } catch (_) {}
  }

  Future<void> _saveLocalRoadmaps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_roadmaps.map((r) => r.toJson()).toList());
      await prefs.setString('local_roadmaps', data);
    } catch (e) {
      debugPrint('Error saving local roadmaps: $e');
    }
  }

  Future<void> _loadLocalRoadmaps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('local_roadmaps');
      if (json != null) {
        final List<dynamic> data = jsonDecode(json);
        _roadmaps = data.map((j) => Roadmap.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('Error loading local roadmaps: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REFRESH & MISC
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    if (_authStatus == AuthStatus.authenticated) {
      final results = await Future.wait<dynamic>([
        _firestoreService.getUserProfile(),
        _firestoreService.getActiveCourses(),
        _firestoreService.getRoadmaps(),
        _firestoreService.getUserPreferences(),
        AdminService.getAllVerifiedCourses(),
        ApiService.fetchPulse('user_001'),
      ]);

      final firestoreProfile = results[0] as UserProfile?;
      final storedCourses = results[1] as List<Course>;
      final firestoreRoadmaps = results[2] as List<Roadmap>;
      final prefs = results[3] as UserPreferences?;
      final verifiedCourses = results[4] as List<Course>;
      final pulseResults = results[5] as List<PulseEvent>;

      if (firestoreProfile != null) _user = firestoreProfile;

      if (storedCourses.isNotEmpty) {
        _generatedCourses.clear();
        _generatedCourses.addAll(storedCourses);
      }

      if (firestoreRoadmaps.isNotEmpty) {
        _roadmaps = firestoreRoadmaps;
        _saveLocalRoadmaps();
      }

      if (prefs != null) _preferences = prefs;

      _pulseEvents = pulseResults;
      _courses = verifiedCourses;
    } else {
      final results = await Future.wait([
        ApiService.fetchUser('user_001'),
        ApiService.fetchUserCourses('user_001'),
        ApiService.fetchPulse('user_001'),
      ]);

      _user = results[0] as UserProfile;
      _courses = results[1] as List<Course>;
      _pulseEvents = results[2] as List<PulseEvent>;
    }

    _isLoading = false;
    _isInitialLoading = false;
    notifyListeners();
  }

  Future<void> updateProfileImage(String path) async {
    try {
      final File sourceFile = File(path);
      if (!await sourceFile.exists()) return;

      final directory = await getApplicationDocumentsDirectory();
      final String fileName = 'profile_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String localPath = '${directory.path}/$fileName';

      // Remove old image if it exists to save space
      if (_profileImagePath != null) {
        final oldFile = File(_profileImagePath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      await sourceFile.copy(localPath);
      _profileImagePath = localPath;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', localPath);
    } catch (e) {
      debugPrint('Error saving profile image locally: $e');
      // Fallback: just use the original path if copy fails
      _profileImagePath = path;
      notifyListeners();
    }
  }

  void updateUserProfile({required String name, required String handle}) {
    if (_user != null) {
      _user = _user!.copyWith(name: name, handle: handle);
      _firestoreService.saveUserProfile(_user!);
      notifyListeners();
    }
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  int _pulseIndex = 0;
  PulseEvent? get currentPulseEvent {
    if (_pulseEvents.isEmpty) return null;
    return _pulseEvents[_pulseIndex % _pulseEvents.length];
  }

  void nextPulseEvent() {
    _pulseIndex++;
    notifyListeners();
  }

  void clearAuthError() {
    _authError = null;
    notifyListeners();
  }

  /// Clears ALL user-specific data from in-memory state AND SharedPreferences.
  /// Called on signOut and before loading a new account to prevent cross-account
  /// data leakage (e.g. profile photo appearing on wrong account).
  Future<void> _clearAllLocalUserData() async {
    // ── In-memory state reset ──────────────────────────────────────────
    _user = null;
    _dream = null;
    _preferences = null;
    _roadmaps = [];
    _generatedCourses.clear();
    _courses = [];
    _pulseEvents = [];
    _starredLessonIds.clear();
    _savedCourseIds.clear();
    _quizScores.clear();
    _flipCounts.clear();
    _flipExcludedVideoIds.clear();
    _flipExcludedChannelIds.clear();
    _notificationMessage = null;
    _lastCompletedCourse = null;
    _notificationMessage = null;
    _coinEarnedEvent = null;
    _streakBumpEvent = null;
    _trendingCardLang.clear();
    _courseBatchIndex = 0;

    // ── Delete profile image file from disk ────────────────────────────
    if (_profileImagePath != null) {
      try {
        final oldFile = File(_profileImagePath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (_) {}
      _profileImagePath = null;
    }

    // ── SharedPreferences cleanup ──────────────────────────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('authStatus'),
        prefs.remove('user'),
        prefs.remove('dream'),
        prefs.remove('dream_collected'),
        prefs.remove('user_preferences'),
        prefs.remove('local_courses'),
        prefs.remove('local_roadmaps'),
        prefs.remove('profile_image_path'),
        prefs.remove('starred_lessons'),
        prefs.remove('saved_courses'),
        prefs.remove('quiz_scores'),
        prefs.remove('flip_counts'),
        prefs.remove('flip_excluded_vids'),
        prefs.remove('flip_excluded_chans'),
      ]);
    } catch (_) {}
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    _authStatus = AuthStatus.unauthenticated;
    await _clearAllLocalUserData();
    notifyListeners();
  }

  /// 12D.1 & 12D.3 — Mark lesson complete, award coins, fire CoinEarnedEvent.
  Future<void> markLessonAsCompleted(String courseId, String moduleId, String lessonId) async {
    List<Course> targetList;
    int courseIdx = _generatedCourses.indexWhere((c) => c.id == courseId);
    if (courseIdx != -1) {
      targetList = _generatedCourses;
    } else {
      courseIdx = _courses.indexWhere((c) => c.id == courseId);
      if (courseIdx == -1) {
        debugPrint(
            '[AppState] markLessonAsCompleted: course $courseId not in state');
        return;
      }
      targetList = _courses;
    }

    final course = targetList[courseIdx];

    // 12D.1 — find the lesson to get its coinValue before rebuilding the tree
    int coinsToAward = 10;
    for (final m in course.modules) {
      if (m.id == moduleId) {
        for (final l in m.lessons) {
          if (l.id == lessonId) {
            coinsToAward = l.coinValue;
          }
        }
      }
    }

    final updatedModules = course.modules.map((m) {
      if (m.id == moduleId) {
        final updatedLessons = m.lessons.map((l) {
          if (l.id == lessonId) {
            return Lesson(
              id: l.id,
              title: l.title,
              youtubeVideoId: l.youtubeVideoId,
              duration: l.duration,
              description: l.description,
              isCompleted: true,
              chapters: l.chapters,
            );
          }
          return l;
        }).toList();

        final compCount = updatedLessons.where((l) => l.isCompleted).length;
        return Module(
          id: m.id,
          title: m.title,
          lessonCount: m.lessonCount,
          completedCount: compCount,
          isLocked: m.isLocked,
          lessons: updatedLessons,
        );
      }
      return m;
    }).toList();

    bool previousCompleted = true;
    final finalModules = updatedModules.map((m) {
      final isLocked = !previousCompleted;
      previousCompleted = m.completedCount >= m.lessonCount && m.lessonCount > 0;
      return Module(
        id: m.id,
        title: m.title,
        lessonCount: m.lessonCount,
        completedCount: m.completedCount,
        isLocked: isLocked,
        lessons: m.lessons,
      );
    }).toList();

    final totalCompleted = finalModules.fold(0, (sum, m) => sum + m.completedCount);

    final updated = Course(
      id: course.id,
      title: course.title,
      description: course.description,
      category: course.category,
      language: course.language,
      thumbnailUrl: course.thumbnailUrl,
      rating: course.rating,
      learnerCount: course.learnerCount,
      totalLessons: course.totalLessons,
      completedLessons: totalCompleted,
      estimatedTime: course.estimatedTime,
      skills: course.skills,
      modules: finalModules,
      isVerified: course.isVerified,
    );
    targetList[courseIdx] = updated;

    // 12D.1 & 12D.3 — award coins to user profile
    if (_user != null) {
      final prevStreak = _user!.streakDays;
      _user = _user!.copyWith(coins: _user!.coins + coinsToAward);
      _coinEarnedEvent = CoinEarnedEvent(
        coins: coinsToAward,
        reason: 'Lesson completed',
      );

      // Update weekly activity for today
      final weekActivity = List<bool>.from(_user!.weekActivity);
      final todayWeekday = DateTime.now().weekday - 1;
      if (todayWeekday >= 0 && todayWeekday < 7) {
        weekActivity[todayWeekday] = true;
      }

      // Simple streak bump: if today wasn't already marked, increment streak
      int newStreak = _user!.streakDays;
      if (todayWeekday >= 0 && todayWeekday < 7 && !_user!.weekActivity[todayWeekday]) {
        newStreak = prevStreak + 1;
        if (newStreak > prevStreak) {
          _streakBumpEvent = StreakBumpEvent(newStreak); // 12D.2
        }
      }

      _user = UserProfile(
        id: _user!.id,
        name: _user!.name,
        handle: _user!.handle,
        email: _user!.email,
        gantavScore: _user!.gantavScore + 5,
        streakDays: newStreak,
        lessonsCompleted: _user!.lessonsCompleted + 1,
        quizzesPassed: _user!.quizzesPassed,
        weekActivity: weekActivity,
        coins: _user!.coins,
      );

      _firestoreService.saveUserProfile(_user!).catchError((_) {});
    }

    await _saveLocalCourses();
    await _firestoreService.saveActiveCourse(updated);
    notifyListeners();
  }

  Future<void> _loadStarredLessons() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('starred_lessons') ?? [];
    _starredLessonIds.addAll(list);
  }

  Future<void> _saveLocalStarredLessons() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('starred_lessons', _starredLessonIds.toList());
  }

  Future<void> toggleStarredLesson(String lessonId) async {
    if (_starredLessonIds.contains(lessonId)) {
      _starredLessonIds.remove(lessonId);
    } else {
      _starredLessonIds.add(lessonId);
    }
    await _saveLocalStarredLessons();
    await _firestoreService.saveStarredLessonIds(_starredLessonIds.toList());
    notifyListeners();
  }

  bool isLessonStarred(String lessonId) => _starredLessonIds.contains(lessonId);

  // ── Saved Courses ─────────────────────────────────────────────────────

  Future<void> _loadSavedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_courses') ?? [];
    _savedCourseIds.addAll(list);
  }

  Future<void> _saveLocalSavedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_courses', _savedCourseIds.toList());
  }
}