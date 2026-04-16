/// Certificate awarded to a user on course completion.
///
/// Excludes exam-preparation courses per product decision (these are mock
/// tests, not taught courses).
class Certificate {
  final String id;
  final String userId;
  final String userName;
  final String courseId;
  final String courseTitle;
  final String courseCategory;
  final DateTime issuedAt;
  final int totalLessons;
  final String verificationCode;

  const Certificate({
    required this.id,
    required this.userId,
    required this.userName,
    required this.courseId,
    required this.courseTitle,
    required this.courseCategory,
    required this.issuedAt,
    required this.totalLessons,
    required this.verificationCode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'course_id': courseId,
        'course_title': courseTitle,
        'course_category': courseCategory,
        'issued_at': issuedAt.toIso8601String(),
        'total_lessons': totalLessons,
        'verification_code': verificationCode,
      };

  factory Certificate.fromJson(Map<String, dynamic> j) => Certificate(
        id: (j['id'] ?? '').toString(),
        userId: (j['user_id'] ?? '').toString(),
        userName: (j['user_name'] ?? '').toString(),
        courseId: (j['course_id'] ?? '').toString(),
        courseTitle: (j['course_title'] ?? '').toString(),
        courseCategory: (j['course_category'] ?? '').toString(),
        issuedAt: DateTime.tryParse((j['issued_at'] ?? '').toString()) ??
            DateTime.now(),
        totalLessons: (j['total_lessons'] ?? 0) as int,
        verificationCode: (j['verification_code'] ?? '').toString(),
      );
}
