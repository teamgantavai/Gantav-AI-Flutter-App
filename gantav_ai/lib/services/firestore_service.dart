import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // -- USER PROFILE --

  Future<void> saveUserProfile(UserProfile user) async {
    if (currentUserId == null) return;
    await _db.collection('users').doc(currentUserId).set(user.toJson());
  }

  Future<UserProfile?> getUserProfile() async {
    if (currentUserId == null) return null;
    final doc = await _db.collection('users').doc(currentUserId).get();
    if (doc.exists) {
      return UserProfile.fromJson(doc.data()!);
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

  Future<List<Course>> getActiveCourses() async {
    if (currentUserId == null) return [];
    final snapshot = await _db
        .collection('users')
        .doc(currentUserId)
        .collection('courses')
        .get();

    return snapshot.docs.map((doc) => Course.fromJson(doc.data())).toList();
  }

  Future<void> completeLesson(String courseId, String lessonId) async {
    if (currentUserId == null) return;
    // For MVP, just updating local appState is enough since it handles the full graph,
    // but in a production app you'd run a transaction here.
  }
}
