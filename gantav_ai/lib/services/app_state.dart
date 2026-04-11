import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

enum AuthStatus { unauthenticated, authenticated, skipped }

/// Global app state using Provider — single source of truth
class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  UserProfile? _user;
  String? _profileImagePath;
  List<Course> _courses = [];
  List<PulseEvent> _pulseEvents = [];
  bool _isLoading = true;
  int _currentTabIndex = 0;
  Dream? _dream;
  final List<Course> _generatedCourses = [];
  AuthStatus _authStatus = AuthStatus.unauthenticated;
  bool _isGeneratingCourse = false;
  bool _isLoadingMore = false;
  int _courseBatchIndex = 0;
  String? _authError;
  
  // FIXED: Track if onboarding dream was collected
  bool _dreamCollectedInOnboarding = false;
  bool get dreamCollectedInOnboarding => _dreamCollectedInOnboarding;

  // Services
  final FirestoreService _firestoreService = FirestoreService();

  // Getters
  ThemeMode get themeMode => _themeMode;
  UserProfile? get user => _user;
  String? get profileImagePath => _profileImagePath;
  List<Course> get courses => [..._courses, ..._generatedCourses];
  List<Course> get activeCourses => courses.where((c) => c.isInProgress).toList();
  List<Course> get suggestedCourses => courses.where((c) => !c.isInProgress).toList();
  List<PulseEvent> get pulseEvents => _pulseEvents;
  bool get isLoading => _isLoading;
  int get currentTabIndex => _currentTabIndex;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Dream? get dream => _dream;
  List<Course> get generatedCourses => _generatedCourses;
  bool get hasDream => _dream != null;
  AuthStatus get authStatus => _authStatus;
  bool get isAuthenticated => _authStatus != AuthStatus.unauthenticated;
  bool get isGeneratingCourse => _isGeneratingCourse;
  bool get isLoadingMore => _isLoadingMore;
  String? get authError => _authError;

  /// Initialize the app state
  Future<void> init() async {
    await _loadThemePreference();
    await _loadAuthStatus();
    await _loadDream();
    await _loadLocalCourses(); // NEW: load from local storage first
    
    final firebaseUser = AuthService.currentUser;
    if (firebaseUser != null && _authStatus == AuthStatus.unauthenticated) {
      _authStatus = AuthStatus.authenticated;
      await _loadUserFromFirebase(firebaseUser);
    }

    if (_authStatus != AuthStatus.unauthenticated) {
      await refresh();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load user data from Firebase Auth user object
  Future<void> _loadUserFromFirebase(dynamic firebaseUser) async {
    // Try to load from Firestore first
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
  }

  /// Sign in with Google
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

    _authStatus = AuthStatus.authenticated;
    await _loadUserFromFirebase(result.user);
    await _saveAuthStatus();

    if (result.isNewUser) {
      // Save new user to Firestore
      if (_user != null) {
        await _firestoreService.saveUserProfile(_user!);
      }
    }

    _isLoading = false;
    notifyListeners();
    await refresh();
    return true;
  }

  /// Sign in with email/password
  Future<bool> signInWithEmail({required String email, required String password}) async {
    _authError = null;
    _isLoading = true;
    notifyListeners();

    final result = await AuthService.signInWithEmail(
      email: email,
      password: password,
    );

    if (!result.success) {
      _authError = result.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _authStatus = AuthStatus.authenticated;
    await _loadUserFromFirebase(result.user);
    await _saveAuthStatus();
    _isLoading = false;
    notifyListeners();
    await refresh();
    return true;
  }

  /// Sign up with email/password
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

    if (!result.success) {
      _authError = result.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _authStatus = AuthStatus.authenticated;
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
    await _saveAuthStatus();
    _isLoading = false;
    notifyListeners();
    await refresh();
    return true;
  }

  /// Sign in and trigger course generation (legacy flow)
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

    // Generate course with AI
    _isGeneratingCourse = true;
    _isLoading = false;
    notifyListeners();

    await _generateCourse(dream);
    await refresh();

    _isGeneratingCourse = false;
    notifyListeners();
  }

  /// Skip auth — use app without sign in
  Future<void> skipAuth() async {
    _authStatus = AuthStatus.skipped;
    _user = UserProfile.mock();
    await _saveAuthStatus();
    await refresh();
    notifyListeners();
  }

  Future<void> _generateCourse(String dream) async {
    final course = await ApiService.suggestPath(dream);
    if (course != null) {
      _generatedCourses.add(course);
      // Save to Firestore
      await _firestoreService.saveActiveCourse(course);
      notifyListeners();
    }
  }

  /// Generate and save a course from a category prompt
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

  /// Cancel ongoing course generation
  void cancelGeneration() {
    _isGeneratingCourse = false;
    notifyListeners();
  }

  /// Generate next batch of AI courses for infinite scroll
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

    // Pick 3 topics based on batch index
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

  // NEW: Load courses from local storage (SharedPreferences backup)
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

  // NEW: Save courses to local storage
  Future<void> _saveLocalCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_generatedCourses.map((c) => c.toJson()).toList());
      await prefs.setString('local_courses', data);
    } catch (e) {
      debugPrint('Error saving local courses: $e');
    }
  }

  // Override addGeneratedCourse to also save locally
  Future<void> addGeneratedCourse(Course course) async {
    _generatedCourses.add(course);
    await _saveLocalCourses(); // Save locally
    await _firestoreService.saveActiveCourse(course); // Try Firestore
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

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    if (_authStatus == AuthStatus.authenticated) {
      // Use real Firestore data for authenticated users
      final firestoreProfile = await _firestoreService.getUserProfile();
      if (firestoreProfile != null) {
        _user = firestoreProfile;
      }

      // Load courses from Firestore
      final storedCourses = await _firestoreService.getActiveCourses();
      if (storedCourses.isNotEmpty) {
        _generatedCourses.clear();
        _generatedCourses.addAll(storedCourses);
      }

      // Pulse events are social proof — keep mock for now (no real backend)
      final pulseResults = await ApiService.fetchPulse('user_001');
      _pulseEvents = pulseResults;
      _courses = []; // No mock courses for authenticated users
    } else {
      // Skipped auth — use mock data
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
    _generatedCourses.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authStatus');
    await prefs.remove('user');
    await prefs.remove('dream');
    notifyListeners();
  }
}
