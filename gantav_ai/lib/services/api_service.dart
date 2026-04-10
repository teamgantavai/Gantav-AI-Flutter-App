import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'gemini_service.dart';

/// API Service with mock fallback — offline-first architecture
class ApiService {
  static const String _baseUrl = 'http://localhost:3000';
  static const Duration _timeout = Duration(seconds: 5);

  /// GET user profile
  static Future<UserProfile> fetchUser(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/users/$userId'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(response.body));
      }
    } catch (_) {
      // Fallback to mock
    }
    return UserProfile.mock();
  }

  /// GET user's courses with progress
  static Future<List<Course>> fetchUserCourses(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/users/$userId/courses'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Course.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback to mock
    }
    return Course.mockCourses();
  }

  /// GET all available courses
  static Future<List<Course>> fetchAllCourses() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/courses'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Course.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback to mock
    }
    return Course.mockCourses();
  }

  /// GET social pulse events
  static Future<List<PulseEvent>> fetchPulse(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/pulse/$userId'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PulseEvent.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback to mock
    }
    return PulseEvent.mockEvents();
  }

  /// POST enroll in a course
  static Future<bool> enrollCourse(String courseId) async {
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/api/courses/$courseId/enroll'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// POST mark lesson as complete
  static Future<bool> completeLesson(String courseId, String lessonId) async {
    try {
      final response = await http
          .post(Uri.parse(
              '$_baseUrl/api/courses/$courseId/lessons/$lessonId/complete'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// POST get AI-suggested learning path (now powered by Gemini)
  static Future<Course?> suggestPath(String dream) async {
    return GeminiService.generateLearningPath(dream: dream);
  }

  /// GET quiz questions — now AI-generated via Gemini with mock fallback
  static Future<List<QuizQuestion>> fetchQuiz(
    String courseId,
    String lessonId, {
    String lessonTitle = '',
    String courseTitle = '',
    String topic = '',
  }) async {
    // Try AI-generated quiz first
    if (lessonTitle.isNotEmpty) {
      final aiQuestions = await GeminiService.generateQuiz(
        lessonTitle: lessonTitle,
        courseTitle: courseTitle,
        topic: topic,
      );
      if (aiQuestions.isNotEmpty &&
          aiQuestions.first.question != 'What is the output of print(type(42)) in Python?') {
        return aiQuestions;
      }
    }

    // Fallback to server
    try {
      final response = await http
          .get(Uri.parse(
              '$_baseUrl/api/courses/$courseId/lessons/$lessonId/quiz'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => QuizQuestion.fromJson(json)).toList();
      }
    } catch (_) {
      // Fallback to mock
    }
    return QuizQuestion.mockQuestions();
  }
}
