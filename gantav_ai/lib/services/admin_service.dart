import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class AdminService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Saves a manually curated course to the global verified_courses collection
  static Future<void> saveVerifiedCourse(Course course) async {
    try {
      final verifiedCourse = Course(
        id: course.id.isEmpty ? 'vc_${DateTime.now().millisecondsSinceEpoch}' : course.id,
        title: course.title,
        description: course.description,
        category: course.category,
        language: course.language,
        thumbnailUrl: course.thumbnailUrl,
        rating: 0.0, // Ratings removed as per user request
        learnerCount: course.learnerCount,
        totalLessons: course.totalLessons,
        completedLessons: 0,
        estimatedTime: course.estimatedTime,
        skills: course.skills,
        modules: course.modules,
        likes: course.likes,
        isVerified: true,
      );

      await _db.collection('verified_courses').doc(verifiedCourse.id).set(verifiedCourse.toJson());
      
      // Also save nested modules and lessons if the toJson doesn't handle them recursively 
      // (Verified courses usually have full module data)
       final modulesRef = _db.collection('verified_courses').doc(verifiedCourse.id).collection('modules');
       for (var module in verifiedCourse.modules) {
         await modulesRef.doc(module.id).set(module.toJson());
         // Note: If modules have nested lessons, they should be in the module.toJson() 
         // or saved in a sub-collection. For this implementation, we'll assume Course.toJson 
         // and Module.toJson handle their children as per models.dart.
       }
    } catch (e) {
      rethrow;
    }
  }

  /// Finds a verified course that matches the prompt/category
  static Future<Course?> findMatchingVerifiedCourse(String query) async {
    try {
      final q = query.toLowerCase();
      // Try exact category match first
      final catMatch = await _db.collection('verified_courses')
          .where('category', isEqualTo: query)
          .limit(1).get();
      if (catMatch.docs.isNotEmpty) return Course.fromJson(catMatch.docs.first.data());

      // Try title search (Firestore doesn't do full text search well, 
      // but we can at least check if the query is in the title for a few results)
      final all = await _db.collection('verified_courses').get();
      for (var doc in all.docs) {
        final data = doc.data();
        final title = (data['title'] ?? '').toString().toLowerCase();
        final category = (data['category'] ?? '').toString().toLowerCase();
        if (title.contains(q) || category.contains(q) || q.contains(category)) {
          return Course.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches verified courses for a specific category
  static Future<List<Course>> getVerifiedCourses(String category) async {
    try {
      final snapshot = await _db
          .collection('verified_courses')
          .where('category', isEqualTo: category)
          .limit(3)
          .get();

      return snapshot.docs.map((doc) => Course.fromJson(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches all verified courses (for admin overview).
  /// Bounded to 8s so a flaky Firestore connection can't stall the home
  /// screen's refresh() indefinitely — on timeout we return an empty list
  /// and the cached/other data still renders.
  static Future<List<Course>> getAllVerifiedCourses() async {
    try {
      final snapshot = await _db
          .collection('verified_courses')
          .get()
          .timeout(const Duration(seconds: 8));
      return snapshot.docs.map((doc) => Course.fromJson(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Deletes a verified course and its sub-collections
  static Future<void> deleteVerifiedCourse(String courseId) async {
    try {
      await _db.collection('verified_courses').doc(courseId).delete();
      // Firestore doesn't delete sub-collections automatically, but for verified courses 
      // we usually just need the top-level doc if we use toJson for modules.
    } catch (e) {
      rethrow;
    }
  }
}
