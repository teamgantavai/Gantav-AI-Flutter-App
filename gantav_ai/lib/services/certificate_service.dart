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
      id: _generateCertId(uid: uid, courseId: course.id, issuedAt: now),
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
  static Future<List<Certificate>> getMyCertificates({String? userId}) async {
    final uid = userId ?? _uid;
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
          .where((c) => uid == null || c.userId == uid)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Public verification: look up a certificate by its ID in Firestore.
  ///
  /// Returns `null` if no matching document is found or on read error.
  /// Used by the `/verify-certificate` screen.
  static Future<Certificate?> verifyById(String certId) async {
    final normalized = certId.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    try {
      final doc = await _db.collection('certificates').doc(normalized).get();
      if (doc.exists && doc.data() != null) {
        return Certificate.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('[CertificateService] verifyById error: $e');
    }
    // Fallback to local cache for offline self-verify.
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_localKey) ?? const <String>[];
      for (final raw in list) {
        try {
          final cert = Certificate.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          if (cert.id.toUpperCase() == normalized) return cert;
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Produce a stable, shareable certificate ID of the form
  /// `GANTAV-{uid6}-{course8}-{yyyymm}-{checksum4}`.
  ///
  /// Collisions are extremely unlikely in practice because the checksum
  /// folds the full uid + courseId + timestamp.
  static String _generateCertId({
    required String uid,
    required String courseId,
    required DateTime issuedAt,
  }) {
    String slug(String s, int n) {
      final cleaned = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (cleaned.isEmpty) return 'X' * n;
      if (cleaned.length >= n) return cleaned.substring(0, n);
      return cleaned.padRight(n, 'X');
    }

    final uidShort = slug(uid, 6);
    final courseShort = slug(courseId, 8);
    final yyyymm =
        '${issuedAt.year.toString().padLeft(4, '0')}${issuedAt.month.toString().padLeft(2, '0')}';
    final seed = '$uid|$courseId|${issuedAt.millisecondsSinceEpoch}';
    final hash = seed.hashCode.toUnsigned(32).toRadixString(36).toUpperCase();
    final checksum = hash.padLeft(4, '0').substring(0, 4);

    return 'GANTAV-$uidShort-$courseShort-$yyyymm-$checksum';
  }

  static String _generateVerificationCode(String uid, String courseId) {
    // Short, human-readable code. Not cryptographic; public verification is
    // typically backed by the Firestore read above.
    final seed = '${uid.substring(0, min(6, uid.length))}-$courseId-${DateTime.now().millisecondsSinceEpoch}';
    final hash = seed.hashCode.toUnsigned(32).toRadixString(36).toUpperCase();
    return 'GAI-${hash.padLeft(7, '0').substring(0, 7)}';
  }
}
