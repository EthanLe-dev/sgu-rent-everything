class UserSummary {
  const UserSummary({
    required this.id,
    required this.displayName,
    required this.verified,
  });

  final String id;
  final String displayName;
  final bool verified;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        verified: json['verified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'verified': verified,
      };
}

enum UserRole { student, admin }

enum VerificationStatus { unsubmitted, pending, approved, rejected }

class Me extends UserSummary {
  const Me({
    required super.id,
    required super.displayName,
    required super.verified,
    required this.email,
    required this.role,
    required this.verification,
    this.fullName,
    this.studentCode,
    this.className,
    this.faculty,
    this.reviewNote,
  });

  final String email;
  final UserRole role;
  final VerificationStatus verification;
  final String? fullName;
  final String? studentCode;
  final String? className;
  final String? faculty;
  final String? reviewNote;

  bool get isApproved => verification == VerificationStatus.approved;
  bool get isAdmin => role == UserRole.admin;

  String get verificationLabel => switch (verification) {
        VerificationStatus.unsubmitted => 'Chưa nộp hồ sơ',
        VerificationStatus.pending => 'Chờ duyệt trực tiếp',
        VerificationStatus.approved => 'Đã xác minh',
        VerificationStatus.rejected => 'Bị từ chối',
      };

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        verified: json['verified'] as bool? ?? false,
        email: json['email'] as String,
        role: json['role'] == 'admin' ? UserRole.admin : UserRole.student,
        verification: switch (json['verification'] as String? ?? 'unsubmitted') {
          'pending' => VerificationStatus.pending,
          'approved' => VerificationStatus.approved,
          'rejected' => VerificationStatus.rejected,
          _ => VerificationStatus.unsubmitted,
        },
        fullName: json['full_name'] as String?,
        studentCode: json['student_code'] as String?,
        className: json['class_name'] as String?,
        faculty: json['faculty'] as String?,
        reviewNote: json['review_note'] as String?,
      );

  Me copyWith({
    String? displayName,
    bool? verified,
    UserRole? role,
    VerificationStatus? verification,
    String? fullName,
    String? studentCode,
    String? className,
    String? faculty,
    String? reviewNote,
  }) =>
      Me(
        id: id,
        displayName: displayName ?? this.displayName,
        verified: verified ?? this.verified,
        email: email,
        role: role ?? this.role,
        verification: verification ?? this.verification,
        fullName: fullName ?? this.fullName,
        studentCode: studentCode ?? this.studentCode,
        className: className ?? this.className,
        faculty: faculty ?? this.faculty,
        reviewNote: reviewNote ?? this.reviewNote,
      );
}

class OtpChallenge {
  const OtpChallenge({required this.challengeId, required this.expiresAt});

  final String challengeId;
  final String expiresAt;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        challengeId: json['challenge_id'] as String,
        expiresAt: json['expires_at'] as String,
      );
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.me,
  });

  final String accessToken;
  final String expiresAt;
  final Me me;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['access_token'] as String,
        expiresAt: json['expires_at'] as String,
        me: Me.fromJson(json['me'] as Map<String, dynamic>),
      );
}
