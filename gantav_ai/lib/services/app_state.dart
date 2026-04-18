import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/onboarding_service.dart';
import '../services/admin_service.dart';
import '../services/course_roadmap_builder.dart';

enum AuthStatus {
  unauthenticated,
  authenticated,
  skipped,
  needsVerification,
  needsOnboarding
}

class AppState extends ChangeNotifier {
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
  String? _authError;
  String? _notificationMessage;
  Course? _lastCompletedCourse;

  UserPreferences? _preferences;
  List<Roadmap> _roadmaps = [];
  bool _needsOnboarding = false;
  bool _isGeneratingRoadmap = false;
  final Set<String> _starredLessonIds = {};

  bool _dreamCollectedInOnboarding = false;
  bool get dreamCollectedInOnboarding => _dreamCollectedInOnboarding;

  final FirestoreService _firestoreService = FirestoreService();

  // Getters
  ThemeMode get themeMode => _themeMode;
  UserProfile? get user => _user;
  String? get profileImagePath => _profileImagePath;

  // Memoized, deduped union of _courses + _generatedCourses.
  // The getter used to allocate a fresh list every call via spread + where +
  // toList — the home screen alone would hit it 4-6× per rebuild through
  // activeCourses / suggestedCourses, multiplying the cost by N items.
  // Cache invalidates on every notifyListeners() (see override below) so
  // readers always see fresh data after a state change.
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
    _coursesCache = null; // invalidate memoized views
    super.notifyListeners();
  }
  
  /// Courses the user is actively learning.
  /// For authenticated users: include all generated/enrolled courses that are
  /// not yet fully complete, even if no lessons have been completed yet.
  /// For guests: fall back to legacy isInProgress filter on mock data.
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
      // Also include any in-progress verified courses merged from _courses
      for (final c in _courses) {
        if (c.isInProgress && seen.add(c.id)) result.add(c);
      }
      return result;
    }
    return courses.where((c) => c.isInProgress).toList();
  }
      
  List<Course> get favoriteCourses {
    // For now, let's assume courses with high rating or that user marked as starred are favorites
    // Actually, let's add a proper favorite list if we have one.
    // If not, we'll use a local filter for now.
    return courses.where((c) => (c.rating >= 4.9 && c.isVerified)).toList();
  }

  List<Course> get suggestedCourses =>
      courses.where((c) => !c.isInProgress).toList();
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

    await _loadThemePreference();
    await _loadAuthStatus();
    await _loadDream();
    await _loadLocalCourses();
    await _loadLocalPreferences();
    await _loadLocalRoadmaps();
    await _loadStarredLessons();

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
      _isInitialLoading = false;
      notifyListeners();
    }
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
    
    // Load starred from firestore if available
    final firestoreStarred = await _firestoreService.getStarredLessonIds();
    if (firestoreStarred.isNotEmpty) {
      _starredLessonIds.addAll(firestoreStarred);
      await _saveLocalStarredLessons();
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

    await _loadUserFromFirebase(result.user);
    await _saveAuthStatus();

    if (result.isNewUser) {
      if (_user != null) {
        await _firestoreService.saveUserProfile(_user!);
      }
      if (_preferences == null && _dream == null) {
        _authStatus = AuthStatus.needsOnboarding;
        _needsOnboarding = true;
      } else {
        _authStatus = AuthStatus.authenticated;
      }
    } else {
      if (_preferences == null &&
          _dream == null &&
          _generatedCourses.isEmpty) {
        _authStatus = AuthStatus.needsOnboarding;
        _needsOnboarding = true;
      } else {
        _authStatus = AuthStatus.authenticated;
      }
    }

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

    await _loadUserFromFirebase(result.user);
    await _saveAuthStatus();

    if (_preferences == null &&
        _dream == null &&
        _generatedCourses.isEmpty) {
      _authStatus = AuthStatus.needsOnboarding;
      _needsOnboarding = true;
    } else {
      _authStatus = AuthStatus.authenticated;
    }

    _isLoading = false;
    notifyListeners();
    if (_authStatus == AuthStatus.authenticated) {
      await refresh();
    }
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

    await AuthService.sendEmailVerification();

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
        _authStatus = AuthStatus.needsOnboarding;
        _needsOnboarding = true;
        await _saveAuthStatus();
      } else {
        _authError = 'Email not yet verified. Please check your inbox.';
      }
      notifyListeners();
    }
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

    // Bug #7 fix: Update user score and streak when tasks are completed
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

    // Bug #7 fix: update score and streak on toggle
    _updateUserProgressStats();

    notifyListeners();
    _saveLocalRoadmaps();
    _firestoreService.updateRoadmap(roadmap).catchError((_) {});
  }

  /// Bug #7 fix: Recalculate and update gantav score + streak from roadmap data.
  /// Called whenever a task is toggled so the home screen stat chips always show
  /// the correct live value.
  void _updateUserProgressStats() {
    if (_user == null || _roadmaps.isEmpty) return;

    // Count all completed tasks across all roadmaps
    int totalCompletedTasks = 0;
    int completedDays = 0;

    for (final roadmap in _roadmaps) {
      totalCompletedTasks += roadmap.completedTasks;
      completedDays += roadmap.completedDays;
    }

    // Gantav Score: 10 points per completed task
    final newScore = totalCompletedTasks * 10;

    // Streak: count consecutive days from today backwards that have completed tasks
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

    // Update weekly activity (mark today as active if any task done today)
    final weekActivity = List<bool>.from(_user!.weekActivity);
    final todayWeekday = DateTime.now().weekday - 1; // 0=Mon, 6=Sun
    if (todayWeekday < 7) {
      final todayRoadmapDay = activeRoadmap?.todayDay;
      weekActivity[todayWeekday] =
          (todayRoadmapDay?.completedTaskCount ?? 0) > 0;
    }

    // Create updated profile
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
    );

    // Persist to Firestore async
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

  /// The user's preferred content language in the format YouTube API expects
  /// ('English' / 'Hindi'). Falls back to English.
  String get _preferredLang {
    final code = _preferences?.language;
    return code == 'hi' ? 'Hindi' : 'English';
  }

  /// Build a personalized Roadmap for a freshly generated Course using the
  /// user's daily available minutes. Persists to local + Firestore.
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
    try {
      final course = await ApiService.suggestPath(prompt, language: _preferredLang)
          .timeout(const Duration(seconds: 45), onTimeout: () => null);
      if (course != null) {
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
    _isGeneratingCourse = true;
    showNotification(
        'AI is creating your learning path in the background. You will be notified when it is ready!');
    notifyListeners();

    try {
      // 1. First, check if a similar Curated/Verified course exists
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

      // 2. Use playlist-first suggestPath (tries YouTube playlist, then AI).
      //    This guarantees single-channel content when a good playlist exists.
      final course = await ApiService.suggestPath(prompt, language: _preferredLang)
          .timeout(const Duration(seconds: 60), onTimeout: () => null);
      if (course != null) {
        await addGeneratedCourse(course);
        await setDream(dreamTopic, courseId: course.id);
        _lastCompletedCourse = course;
        final minutes = dailyMinutes ?? _preferences?.dailyStudyMinutes ?? 30;
        await buildRoadmapForCourse(course, minutes);
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

  /// Generate course in background from category subcategory tap
  /// Returns immediately, notifies via toast when done
  Future<void> generateCourseInBackgroundFromCategory(String promptHint,
      {int? dailyMinutes}) async {
    _isGeneratingCourse = true;
    notifyListeners();

    try {
      // 1. Check for curated matches first
      final curated = await AdminService.findMatchingVerifiedCourse(promptHint);
      if (curated != null) {
        await addGeneratedCourse(curated);
        _isGeneratingCourse = false;
        showNotification('Found a professional curated course for "$promptHint"!');
        notifyListeners();
        return;
      }

      final course = await ApiService.suggestPath(promptHint, language: _preferredLang)
          .timeout(const Duration(seconds: 60), onTimeout: () => null);
      if (course != null) {
        _generatedCourses.add(course);
        await _saveLocalCourses();
        await _firestoreService.saveActiveCourse(course);
        _lastCompletedCourse = course;
        final minutes = dailyMinutes ?? _preferences?.dailyStudyMinutes ?? 30;
        await buildRoadmapForCourse(course, minutes);
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

  Future<void> generateNextCourseBatch() async {
    if (_isLoadingMore) return;
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

    final startIdx =
        ((_courseBatchIndex - 1) * 2) % topics.length; // Reduced to 2 per batch
    final batch = <Future<Course?>>[];
    for (int i = 0; i < 2; i++) {
      // Reduced from 3 to 2 for speed
      final topicIdx = (startIdx + i) % topics.length;
      batch.add(
        ApiService.suggestPath(topics[topicIdx], language: _preferredLang)
            .timeout(const Duration(seconds: 40), onTimeout: () => null),
      );
    }

    final results = await Future.wait(batch);
    for (final course in results) {
      if (course != null) {
        _generatedCourses.add(course);
        await _firestoreService.saveActiveCourse(course);
      }
    }

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
      final firestoreProfile = await _firestoreService.getUserProfile();
      if (firestoreProfile != null) {
        _user = firestoreProfile;
      }

      final storedCourses = await _firestoreService.getActiveCourses();
      if (storedCourses.isNotEmpty) {
        _generatedCourses.clear();
        _generatedCourses.addAll(storedCourses);
      }

      final firestoreRoadmaps = await _firestoreService.getRoadmaps();
      if (firestoreRoadmaps.isNotEmpty) {
        _roadmaps = firestoreRoadmaps;
        await _saveLocalRoadmaps();
      }

      final prefs = await _firestoreService.getUserPreferences();
      if (prefs != null) {
        _preferences = prefs;
      }

      // Fetch all Gantav Verified courses
      final verifiedCourses = await AdminService.getAllVerifiedCourses();

      // Fetch pulse for internal state but Bug #6 fix:
      // We store them but DON'T show them on home screen anymore.
      final pulseResults = await ApiService.fetchPulse('user_001');
      _pulseEvents = pulseResults;
      
      // Merge verified courses with user's generated/active courses
      // Verified courses should stay at the top or be easily accessible in Explore
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

  void updateProfileImage(String path) {
    _profileImagePath = path;
    notifyListeners();
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

  // Bug #6 fix: pulse index retained internally for any future opt-in feature,
  // but currentPulseEvent is not exposed to home screen anymore.
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

  Future<void> signOut() async {
    await AuthService.signOut();
    _authStatus = AuthStatus.unauthenticated;
    _user = null;
    _dream = null;
    _preferences = null;
    _roadmaps = [];
    _needsOnboarding = false;
    _generatedCourses.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authStatus');
    await prefs.remove('user');
    await prefs.remove('dream');
    await prefs.remove('user_preferences');
    await prefs.remove('local_roadmaps');
    notifyListeners();
  }

  Future<void> markLessonAsCompleted(String courseId, String moduleId, String lessonId) async {
    // Find the course in EITHER list. Previously this only checked
    // _generatedCourses, so lessons inside curated / recommended courses
    // (loaded into _courses from Firestore / mocks) never got their
    // completion status persisted — progress bar stayed at 0 and the user
    // could never unlock the Get Certificate CTA. Fix: look in both lists
    // and update whichever contains the course.
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

    // Re-check locking for all modules sequentially
    bool previousCompleted = true;
    final finalModules = updatedModules.map((m) {
      final isLocked = !previousCompleted;
      previousCompleted = m.completedCount >= m.lessonCount && m.lessonCount > 0;
      return Module(
        id: m.id,
        title: m.title,
        lessonCount: m.lessonCount,
        completedCount: m.completedCount,
        isLocked: isLocked, // Unlock if previous is done
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

    // Persist locally + to Firestore so progress survives app restart
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
}
