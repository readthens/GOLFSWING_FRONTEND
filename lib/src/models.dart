class UserProfile {
  const UserProfile({required this.id, required this.email});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
    );
  }

  final String id;
  final String email;
}

class GolferProfile {
  const GolferProfile({
    required this.userId,
    this.handedness,
    this.skillLevel,
    this.goals = const [],
    this.commonMiss,
  });

  factory GolferProfile.fromJson(Map<String, dynamic> json) {
    return GolferProfile(
      userId: json['user_id'] as String,
      handedness: json['handedness'] as String?,
      skillLevel: json['skill_level'] as String?,
      goals: (json['goals'] as List<dynamic>? ?? const [])
          .map((goal) => goal as String)
          .toList(),
      commonMiss: json['common_miss'] as String?,
    );
  }

  final String userId;
  final String? handedness;
  final String? skillLevel;
  final List<String> goals;
  final String? commonMiss;
}

class AuthPayload {
  const AuthPayload({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthPayload.fromJson(Map<String, dynamic> json) {
    return AuthPayload(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final UserProfile user;
}

class MePayload {
  const MePayload({required this.user, this.profile});

  factory MePayload.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    return MePayload(
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
      profile: profile == null
          ? null
          : GolferProfile.fromJson(profile as Map<String, dynamic>),
    );
  }

  final UserProfile user;
  final GolferProfile? profile;
}

class Consent {
  const Consent({required this.consentType});

  factory Consent.fromJson(Map<String, dynamic> json) {
    return Consent(consentType: json['consent_type'] as String);
  }

  final String consentType;
}

class UploadRecord {
  const UploadRecord({required this.id, required this.storageKey});

  factory UploadRecord.fromJson(Map<String, dynamic> json) {
    return UploadRecord(
      id: json['id'] as String,
      storageKey: json['storage_key'] as String,
    );
  }

  final String id;
  final String storageKey;
}

class UploadPresignPayload {
  const UploadPresignPayload({
    required this.upload,
    required this.presignedUrl,
  });

  factory UploadPresignPayload.fromJson(Map<String, dynamic> json) {
    return UploadPresignPayload(
      upload: UploadRecord.fromJson(json['upload'] as Map<String, dynamic>),
      presignedUrl: json['presigned_url'] as String,
    );
  }

  final UploadRecord upload;
  final String presignedUrl;
}

class SwingVideo {
  const SwingVideo({
    required this.id,
    required this.angle,
    required this.storageKey,
    this.durationMs,
    this.qualityScore,
    this.qualityStatus,
    this.qualityChecks = const [],
  });

  factory SwingVideo.fromJson(Map<String, dynamic> json) {
    return SwingVideo(
      id: json['id'] as String,
      angle: json['angle'] as String,
      storageKey: json['storage_key'] as String,
      durationMs: json['duration_ms'] as int?,
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
      qualityStatus: json['quality_status'] as String?,
      qualityChecks: (json['quality_checks'] as List<dynamic>? ?? const [])
          .map(
            (check) =>
                SwingQualityCheck.fromJson(check as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String id;
  final String angle;
  final String storageKey;
  final int? durationMs;
  final double? qualityScore;
  final String? qualityStatus;
  final List<SwingQualityCheck> qualityChecks;
}

class SwingQualityCheck {
  const SwingQualityCheck({
    required this.id,
    required this.severity,
    required this.message,
  });

  factory SwingQualityCheck.fromJson(Map<String, dynamic> json) {
    return SwingQualityCheck(
      id: json['id'] as String? ?? 'quality_check',
      severity: json['severity'] as String? ?? 'warn',
      message: json['message'] as String? ?? 'Quality check recorded.',
    );
  }

  final String id;
  final String severity;
  final String message;
}

class SwingSession {
  const SwingSession({
    required this.id,
    required this.status,
    required this.createdAt,
    this.club,
    this.locationType,
    this.videos = const [],
  });

  factory SwingSession.fromJson(Map<String, dynamic> json) {
    return SwingSession(
      id: json['id'] as String,
      status: json['status'] as String,
      club: json['club'] as String?,
      locationType: json['location_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      videos: (json['videos'] as List<dynamic>? ?? const [])
          .map((video) => SwingVideo.fromJson(video as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String status;
  final String? club;
  final String? locationType;
  final DateTime createdAt;
  final List<SwingVideo> videos;
}
