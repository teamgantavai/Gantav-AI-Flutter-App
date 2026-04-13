import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../services/onboarding_service.dart';
import '../services/youtube_api_service.dart';

enum AuthStatus { unauthenticated, authenticated, skipped, needsVerification, needsOnboarding }

/// Global app state using Provider — single source of truth
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

  // ── Onboarding & Roadmap state ────────────────────────────────────────────
  UserPreferences? _preferences;
  List<Roadmap> _roadmaps = [];
  bool _needsOnboarding = false;
  bool _isGeneratingRoadmap = false;

  // Legacy: Track if onboarding dream was collected
  bool _dreamCollectedInOnboarding = false;
  bool get dreamCollectedInOnboarding => _dreamCollectedInOnboarding;

  // Services
  final FirestoreService _firestoreService = FirestoreService();

  // ── Getters ───────────────────────────────────────────────────────────────
  ThemeMode get themeMode => _themeMode;
  UserProfile? get user => _user;
  String? get profileImagePath => _profileImagePath;
  List<Course> get courses => [..._courses, ..._generatedCourses];
  List<Course> get activeCourses => courses.where((c) => c.isInProgress).toList();
  List<Course> get suggestedCourses => courses.where((c) => !c.isInProgress).toList();
  List<PulseEvent> get pulseEvents => _pulseEvents;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading;
  int get currentTabIndex => _currentTabIndex;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Dream? get dream => _dream;
  List<Course> get generatedCourses => _generatedCourses;
  bool get hasDream => _dream != null;
  AuthStatus get authStatus => _authStatus;
  bool get isAuthenticated => _authStatus == AuthStatus.authenticated || _authStatus == AuthStatus.skipped;
  bool get isGeneratingCourse => _isGeneratingCourse;
  bool get isLoadingMore => _isLoadingMore;
  String? get authError => _authError;
  String? get notificationMessage => _notificationMessage;

  // ── Onboarding & Roadmap getters ──────────────────────────────────────────
  UserPreferences? get preferences => _preferences;
  List<Roadmap> get roadmaps => _roadmaps;
  bool get needsOnboarding => _needsOnboarding;
  bool get isGeneratingRoadmap => _isGeneratingRoadmap;

  /// Active roadmap (most recent)
  Roadmap? get activeRoadmap =>
      _roadmaps.isNotEmpty ? _roadmaps.first : null;

  /// Today's tasks from the active roadmap
  RoadmapDay? get todayRoadmapDay => activeRoadmap?.todayDay;

  /// Today's completed task count
  int get todayCompletedTasks => todayRoadmapDay?.completedTaskCount ?? 0;

  /// Today's total task count
  int get todayTotalTasks => todayRoadmapDay?.tasks.length ?? 0;

  /// Whether today's tasks are all done
  bool get isTodayComplete => todayRoadmapDay?.allTasksCompleted ?? false;

  void clearNotification() {
    if (_notificationMessage != null) {
      _notificationMessage = null;
      notifyListeners();
    }
  }

  void showNotification(String message) {
    _notificationMessage = message;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    _isInitialLoading = true;
    notifyListeners();
    
    await _loadThemePreference();
    await _loadAuthStatus();
    await _loadDream();
    await _loadLocalCourses();
    await _loadLocalPreferences();
    await _loadLocalRoadmaps();
    
    final firebaseUser = AuthService.currentUser;
    if (firebaseUser != null && _authStatus == AuthStatus.unauthenticated) {
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
        handle: (firebaseUser.displayName ?? 'learner').toLowerCase().replaceAll(' ', ''),
        email: firebaseUser.email ?? '',
        gantavScore: 0,
        streakDays: 0,
        lessonsCompleted: 0,
        quizzesPassed: 0,
        weekActivity: List.filled(7, false),
      );
    }

    // Load generated courses from Firestore
    final storedCourses = await _firestoreService.getActiveCourses();
    if (storedCourses.isNotEmpty) {
      _generatedCourses.clear();
      _generatedCourses.addAll(storedCourses);
    }

    // Load preferences & roadmaps from Firestore
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
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ═══════════════════════════════════════════════════════════════════════════

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
      // New user needs onboarding — but only if they don't have preferences already
      if (_preferences == null && _dream == null) {
        _authStatus = AuthStatus.needsOnboarding;
        _needsOnboarding = true;
      } else {
        _authStatus = AuthStatus.authenticated;
      }
    } else {
      // Returning user — check if they completed onboarding
      if (_preferences == null && _dream == null && _generatedCourses.isEmpty) {
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

  Future<bool> signInWithEmail({required String email, required String password}) async {
    _authError = null;
    _isLoading = true;
    notifyListeners();

    final result = await AuthService.signInWithEmail(
      email: email,
      password: password,
    );

    if (!result.success || result.user == null) {
      _authError = result.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Check if email is verified
    if (!result.user!.emailVerified) {
      _authStatus = AuthStatus.needsVerification;
      _isLoading = false;
      notifyListeners();
      return true;
    }

    await _loadUserFromFirebase(result.user);
    await _saveAuthStatus();

    // Check if onboarding is needed
    if (_preferences == null && _dream == null && _generatedCourses.isEmpty) {
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
      email: email,
      password: password,
      name: name,
    );

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
        // New sign-up → needs onboarding
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

  /// Sign in and trigger course generation (legacy flow — kept for backward compat)
  Future<void> signInAndGenerate({required String dream, String? name}) async {
    _isLoading = true;
    notifyListeners();

    _authStatus = AuthStatus.authenticated;
    _user = UserProfile(
      id: AuthService.currentUser?.uid ?? 'user_001',
      name: name ?? AuthService.currentUser?.displayName ?? 'Learner',
      handle: (name ?? 'learner').toLowerCase().replaceAll(' ', ''),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // ONBOARDING & ROADMAP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Complete onboarding with user preferences → trigger roadmap generation
  Future<void> completeOnboarding(UserPreferences prefs) async {
    _preferences = prefs;
    _needsOnboarding = false;
    _isGeneratingRoadmap = true;
    _authStatus = AuthStatus.authenticated;
    notifyListeners();

    // Save preferences
    await _saveLocalPreferences();
    await _firestoreService.saveUserPreferences(prefs);

    // Generate the roadmap
    final roadmap = await OnboardingService.generateRoadmap(prefs);
    if (roadmap != null) {
      _roadmaps.insert(0, roadmap);
      await _saveLocalRoadmaps();
      await _firestoreService.saveRoadmap(roadmap);
    }

    _isGeneratingRoadmap = false;
    await _saveAuthStatus();
    notifyListeners();
    await refresh();
  }

  /// Mark a specific task in a roadmap day as completed
  void markTaskComplete(String roadmapId, int dayNumber, String taskId) {
    final roadmapIdx = _roadmaps.indexWhere((r) => r.id == roadmapId);
    if (roadmapIdx == -1) return;

    final roadmap = _roadmaps[roadmapIdx];
    final dayIdx = roadmap.days.indexWhere((d) => d.dayNumber == dayNumber);
    if (dayIdx == -1) return;

    final day = roadmap.days[dayIdx];
    final taskIdx = day.tasks.indexWhere((t) => t.id == taskId);
    if (taskIdx == -1) return;

    day.tasks[taskIdx].isCompleted = true;
    day.tasks[taskIdx].completedAt = DateTime.now();

    // Auto-complete the day if all tasks are done
    if (day.allTasksCompleted) {
      day.isCompleted = true;
      day.completedAt = DateTime.now();
    }

    // Check if entire roadmap is complete
    if (roadmap.isComplete) {
      roadmap.completedAt = DateTime.now();
    }

    notifyListeners();
    _saveLocalRoadmaps();
    _firestoreService.updateRoadmap(roadmap).catchError((_) {});
  }

  /// Toggle a task's completion status
  void toggleTaskComplete(String roadmapId, int dayNumber, String taskId) {
    final roadmapIdx = _roadmaps.indexWhere((r) => r.id == roadmapId);
    if (roadmapIdx == -1) return;

    final roadmap = _roadmaps[roadmapIdx];
    final dayIdx = roadmap.days.indexWhere((d) => d.dayNumber == dayNumber);
    if (dayIdx == -1) return;

    final day = roadmap.days[dayIdx];
    final taskIdx = day.tasks.indexWhere((t) => t.id == taskId);
    if (taskIdx == -1) return;

    final task = day.tasks[taskIdx];
    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;

    // Update day completion
    day.isCompleted = day.allTasksCompleted;
    day.completedAt = day.isCompleted ? DateTime.now() : null;

    // Update roadmap completion
    roadmap.completedAt = roadmap.isComplete ? DateTime.now() : null;

    notifyListeners();
    _saveLocalRoadmaps();
    _firestoreService.updateRoadmap(roadmap).catchError((_) {});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COURSE GENERATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _generateCourse(String dream) async {
    final course = await ApiService.suggestPath(dream);
    if (course != null) {
      _generatedCourses.add(course);
      await _firestoreService.saveActiveCourse(course);
      notifyListeners();
    }
  }

  Future<Course?> generateCourseFromCategory(String prompt) async {
    _isGeneratingCourse = true;
    notifyListeners();

    try {
      final course = await ApiService.suggestPath(prompt)
          .timeout(const Duration(seconds: 60), onTimeout: () => null);
      if (course != null) {
        _generatedCourses.add(course);
        await _firestoreService.saveActiveCourse(course);
      }

      _isGeneratingCourse = false;
      notifyListeners();
      return course;
    } catch (_) {
      _isGeneratingCourse = false;
      notifyListeners();
      return null;
    }
  }

  void cancelGeneration() {
    _isGeneratingCourse = false;
    _isGeneratingRoadmap = false;
    notifyListeners();
  }

  Future<void> generateCourseInBackground(String prompt, String dreamTopic) async {
    _isGeneratingCourse = true;
    showNotification('AI is creating your learning path in the background. You will be notified when it is ready!');
    notifyListeners();

    try {
      final preFilteredVideos = await YouTubeApiService.fetchHighQualityVideos(topic: prompt);
      final course = await GeminiService.generateLearningPath(
        dream: prompt,
        preFilteredVideos: preFilteredVideos,
      );
      if (course != null) {
        await addGeneratedCourse(course);
        await setDream(dreamTopic, courseId: course.id);
        showNotification('Success: Your new course "${course.title}" is ready in My Courses!');
      } else {
        showNotification('Error: Failed to generate course. Please try again.');
      }
    } catch (e) {
      showNotification('Error: Something went wrong generating your course.');
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
      'Kubernetes and container orchestration',
      'Natural Language Processing',
      'Computer vision with OpenCV',
      'Rust programming language',
      'TypeScript advanced patterns',
    ];

    final startIdx = ((_courseBatchIndex - 1) * 3) % topics.length;
    final batch = <Future<Course?>>[];
    for (int i = 0; i < 3; i++) {
      final topicIdx = (startIdx + i) % topics.length;
      batch.add(
        ApiService.suggestPath(topics[topicIdx])
            .timeout(const Duration(seconds: 45), onTimeout: () => null),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════════

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
      _dreamCollectedInOnboarding = prefs.getBool('dream_collected') ?? false;
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
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
      final data = jsonEncode(_generatedCourses.map((c) => c.toJson()).toList());
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

  // ── Local Preferences persistence ─────────────────────────────────────────

  Future<void> _saveLocalPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_preferences != null) {
        await prefs.setString('user_preferences', jsonEncode(_preferences!.toJson()));
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

  // ── Local Roadmaps persistence ────────────────────────────────────────────

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

  // ═══════════════════════════════════════════════════════════════════════════
  // REFRESH & MISC
  // ═══════════════════════════════════════════════════════════════════════════

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

      // Load roadmaps
      final firestoreRoadmaps = await _firestoreService.getRoadmaps();
      if (firestoreRoadmaps.isNotEmpty) {
        _roadmaps = firestoreRoadmaps;
        await _saveLocalRoadmaps();
      }

      // Load preferences
      final prefs = await _firestoreService.getUserPreferences();
      if (prefs != null) {
        _preferences = prefs;
      }

      final pulseResults = await ApiService.fetchPulse('user_001');
      _pulseEvents = pulseResults;
      _courses = [];
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
}
