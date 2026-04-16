import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/certificate.dart';
import '../models/models.dart';

/// Issues, stores, and retrieves completion certificates for non-exam-prep
/// courses.
class CertificateService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  static String? get _uid => _auth.currentUser?.uid;

  static const String _localKey = 'certificates_local';

  /// Categories that do NOT get certificates. Exam prep courses are really
  /// mock tests; certificates would be misleading.
  static const Set<String> _excludedCategories = {
    'exam preparation',
    'exam prep',
    'competitive exam',
    'ssc',
    'upsc',
    'banking',
    'entrance',
  };

  /// Returns `true` if the given course category is eligible for a certificate.
  static bool isEligible(String? category) {
    if (category == null) return true;
    final c = category.toLowerCase().trim();
    return !_excludedCategories.contains(c);
  }

  /// Issue a fresh certificate for a completed course. Idempotent: if one
  /// already exists for (userId, courseId), returns the existing record.
  static Future<Certificate> issueCertificate({
    required Course course,
    required UserProfile user,
  }) async {
    final uid = _uid ?? user.id;

    // Reuse existing
    final existing = await _findExisting(uid: uid, courseId: course.id);
    if (existing != null) return existing;

    final now = DateTime.now();
    final cert = Certificate(
      id: 'cert_${now.millisecondsSinceEpoch}_${_randomSuffix()}',
      userId: uid,
      userName: user.name.trim().isEmpty ? 'Learner' : user.name,
      courseId: course.id,
      courseTitle: course.title,
      courseCategory: course.category,
      issuedAt: now,
      totalLessons: course.totalLessons,
      verificationCode: _generateVerificationCode(uid, course.id),
    );

    // Persist: Firestore (best-effort) + local fallback
    try {
      await _db
          .collection('certificates')
          .doc(cert.id)
          .set(cert.toJson());
    } catch (e) {
      debugPrint('[CertificateService] firestore write failed: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_localKey) ?? <String>[];
      list.insert(0, jsonEncode(cert.toJson()));
      if (list.length > 50) list.removeRange(50, list.length);
      await prefs.setStringList(_localKey, list);
    } catch (e) {
      debugPrint('[CertificateService] local save failed: $e');
    }

    return cert;
  }

  static Future<Certificate?> _findExisting({
    required String uid,
    required String courseId,
  }) async {
    // Firestore first
    try {
      final snap = await _db
          .collection('certificates')
          .where('user_id', isEqualTo: uid)
          .where('course_id', isEqualTo: courseId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return Certificate.fromJson(snap.docs.first.data());
      }
    } catch (e) {
      debugPrint('[CertificateService] existing lookup error: $e');
    }

    // Local fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_localKey) ?? const <String>[];
      for (final raw in list) {
        try {
          final cert = Certificate.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          if (cert.userId == uid && cert.courseId == courseId) return cert;
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  /// All certificates owned by the current user. Firestore preferred, local
  /// as fallback.
  static Future<List<Certificate>> getMyCertificates() async {
    final uid = _uid;
    if (uid != null) {
      try {
        final snap = await _db
            .collection('certificates')
            .where('user_id', isEqualTo: uid)
            .get();
        final list = snap.docs
            .map((d) => Certificate.fromJson(d.data()))
            .toList()
          ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[CertificateService] fetch error: $e');
      }
    }
    // Local
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_localKey) ?? const <String>[];
      return list
          .map((r) {
            try {
              return Certificate.fromJson(
                jsonDecode(r) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<Certificate>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static String _randomSuffix() {
    final r = Random();
    return List.generate(4, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  static String _generateVerificationCode(String uid, String courseId) {
    // Short, human-readable code. Not cryptographic; public verification is
    // typically backed by the Firestore read above.
    final seed = '${uid.substring(0, min(6, uid.length))}-$courseId-${DateTime.now().millisecondsSinceEpoch}';
    final hash = seed.hashCode.toUnsigned(32).toRadixString(36).toUpperCase();
    return 'GAI-${hash.padLeft(7, '0').substring(0, 7)}';
  }
}
