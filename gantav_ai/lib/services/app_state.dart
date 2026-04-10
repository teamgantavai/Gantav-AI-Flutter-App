import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

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

  // Getters
  ThemeMode get themeMode => _themeMode;
  UserProfile? get user => _user;
  String? get profileImagePath => _profileImagePath;
  List<Course> get courses => [..._courses, ..._generatedCourses];
  List<Course> get activeCourses =>
      courses.where((c) => c.isInProgress).toList();
  List<Course> get suggestedCourses =>
      courses.where((c) => !c.isInProgress).toList();
  List<PulseEvent> get pulseEvents => _pulseEvents;
  bool get isLoading => _isLoading;
  int get currentTabIndex => _currentTabIndex;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Dream? get dream => _dream;
  List<Course> get generatedCourses => _generatedCourses;
  bool get hasDream => _dream != null;

  /// Initialize the app state
  Future<void> init() async {
    await _loadThemePreference();
    await _loadDream();
    await _loadGeneratedCourses();
    await refresh();
  }

  /// Set the active bottom nav tab
  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  /// Toggle between dark and light theme
  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
  }

  /// Load saved theme preference
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {
      // Default to dark mode
    }
  }

  /// Set the user's dream/goal
  Future<void> setDream(String dreamText, {String? courseId}) async {
    _dream = Dream(
      text: dreamText,
      createdAt: DateTime.now(),
      generatedCourseId: courseId,
    );
    notifyListeners();
    await _saveDream();
  }

  /// Clear the dream
  Future<void> clearDream() async {
    _dream = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dream');
  }

  /// Add an AI-generated course
  Future<void> addGeneratedCourse(Course course) async {
    _generatedCourses.add(course);
    notifyListeners();
    await _saveGeneratedCourses();
  }

  /// Save dream to SharedPreferences
  Future<void> _saveDream() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_dream != null) {
        await prefs.setString('dream', jsonEncode(_dream!.toJson()));
      }
    } catch (_) {}
  }

  /// Load dream from SharedPreferences
  Future<void> _loadDream() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dreamJson = prefs.getString('dream');
      if (dreamJson != null) {
        _dream = Dream.fromJson(jsonDecode(dreamJson));
      }
    } catch (_) {}
  }

  /// Save generated courses to SharedPreferences
  Future<void> _saveGeneratedCourses() async {
    // For now, generated courses are only in memory
    // Could be persisted with JSON serialization in the future
  }

  /// Load generated courses from SharedPreferences
  Future<void> _loadGeneratedCourses() async {
    // Placeholder for future persistence
  }

  /// Refresh all data — pull to refresh
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    // Parallel fetches with mock fallback
    final results = await Future.wait([
      ApiService.fetchUser('user_001'),
      ApiService.fetchUserCourses('user_001'),
      ApiService.fetchPulse('user_001'),
    ]);

    _user = results[0] as UserProfile;
    _courses = results[1] as List<Course>;
    _pulseEvents = results[2] as List<PulseEvent>;

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
      notifyListeners();
    }
  }

  /// Get greeting based on time of day
  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Get the current pulse event to display (cycles)
  int _pulseIndex = 0;
  PulseEvent? get currentPulseEvent {
    if (_pulseEvents.isEmpty) return null;
    return _pulseEvents[_pulseIndex % _pulseEvents.length];
  }

  void nextPulseEvent() {
    _pulseIndex++;
    notifyListeners();
  }
}
