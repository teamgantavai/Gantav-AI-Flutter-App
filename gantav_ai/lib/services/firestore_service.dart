import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Hard ceiling on a single Firestore read. Without this, Firestore's
  /// offline/retry behavior could hang `.get()` for many minutes on flaky
  /// networks — that was the root cause of the "home screen takes 10 min to
  /// load" bug. 8s is long enough for a cold cellular connection but short
  /// enough that the caller can degrade to cached state promptly.
  static const Duration _readTimeout = Duration(seconds: 8);

  // -- USER PROFILE --

  Future<void> saveUserProfile(UserProfile user) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).set(user.toJson());
  }

  Future<UserProfile?> getUserProfile() async {
    if (currentUserId == null) return null;
    try {
      final doc = await _db
          .collection('users')
          .doc(currentUserId)
          .get()
          .timeout(_readTimeout);
      if (doc.exists) {
        return UserProfile.fromJson(doc.data()!);
      }
    } catch (e) {
      // Timeout / offline / permission error — return null so the caller uses
      // cached local state instead of blocking the UI.
      // ignore: avoid_print
      print('[Firestore] getUserProfile failed: $e');
    }
    return null;
  }

  // -- COURSES & ROADMAPS --

  Future<void> saveActiveCourse(Course course) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('courses')
        .doc(course.id)
        .set(course.toJson());
  }

  Future<void> deleteActiveCourse(String courseId) async {
    if (currentUserId == null) return;
    try {
      await _db
          .collection('users')
          .doc(currentUserId)
          .collection('courses')
          .doc(courseId)
          .delete();
    } catch (e) {
      // ignore: avoid_print
      print('[Firestore] deleteActiveCourse failed: $e');
    }
  }

  Future<List<Course>> getActiveCourses() async {
    if (currentUserId == null) return [];
    try {
      final snapshot = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('courses')
          .get()
          .timeout(_readTimeout);
      return snapshot.docs.map((doc) => Course.fromJson(doc.data())).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[Firestore] getActiveCourses failed: $e');
      return [];
    }
  }

  Future<void> completeLesson(String courseId, String lessonId) async {
    if (currentUserId == null) return;
    // For MVP, just updating local appState is enough since it handles the full graph,
    // but in a production app you'd run a transaction here.
  }

  // -- USER PREFERENCES (Onboarding) --

  Future<void> saveUserPreferences(UserPreferences prefs) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('settings')
        .doc('preferences')
        .set(prefs.toJson());
  }

  Future<UserPreferences?> getUserPreferences() async {
    if (currentUserId == null) return null;
    try {
      final doc = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('preferences')
          .get()
          .timeout(_readTimeout);
      if (doc.exists) {
        return UserPreferences.fromJson(doc.data()!);
      }
    } catch (_) {}
    return null;
  }

  // -- ROADMAPS --

  Future<void> saveRoadmap(Roadmap roadmap) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('roadmaps')
        .doc(roadmap.id)
        .set(roadmap.toJson());
  }

  Future<void> updateRoadmap(Roadmap roadmap) async {
    if (currentUserId == null) return;
    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('roadmaps')
        .doc(roadmap.id)
        .update(roadmap.toJson());
  }

  Future<List<Roadmap>> getRoadmaps() async {
    if (currentUserId == null) return [];
    try {
      final snapshot = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('roadmaps')
          .orderBy('created_at', descending: true)
          .get()
          .timeout(_readTimeout);

      return snapshot.docs
          .map((doc) => Roadmap.fromJson(doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Roadmap?> getRoadmap(String roadmapId) async {
    if (currentUserId == null) return null;
    try {
      final doc = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('roadmaps')
          .doc(roadmapId)
          .get()
          .timeout(_readTimeout);
      if (doc.exists) {
        return Roadmap.fromJson(doc.data()!);
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveStarredLessonIds(List<String> ids) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).set({
      'starred_lesson_ids': ids,
    }, SetOptions(merge: true));
  }

  Future<List<String>> getStarredLessonIds() async {
    if (currentUserId == null) return [];
    try {
      final doc = await _db
          .collection('users')
          .doc(currentUserId)
          .get()
          .timeout(_readTimeout);
      if (doc.exists && doc.data()!.containsKey('starred_lesson_ids')) {
        return List<String>.from(doc.data()!['starred_lesson_ids']);
      }
    } catch (_) {}
    return [];
  }
}
