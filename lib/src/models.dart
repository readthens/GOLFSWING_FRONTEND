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
    this.unitsSystem = 'imperial',
    this.distanceUnit = 'yards',
    this.defaultCaptureMode = 'analysis',
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
      unitsSystem: json['units_system'] as String? ?? 'imperial',
      distanceUnit: json['distance_unit'] as String? ?? 'yards',
      defaultCaptureMode: json['default_capture_mode'] as String? ?? 'analysis',
    );
  }

  final String userId;
  final String? handedness;
  final String? skillLevel;
  final List<String> goals;
  final String? commonMiss;
  final String unitsSystem;
  final String distanceUnit;
  final String defaultCaptureMode;
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

class DashboardAction {
  const DashboardAction({
    required this.id,
    required this.title,
    required this.route,
    this.subtitle,
    this.status,
    this.enabled = true,
  });

  factory DashboardAction.fromJson(Map<String, dynamic> json) {
    return DashboardAction(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      route: json['route'] as String? ?? '/home',
      status: json['status'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  final String id;
  final String title;
  final String route;
  final String? subtitle;
  final String? status;
  final bool enabled;
}

class DashboardItem {
  const DashboardItem({
    required this.type,
    required this.title,
    this.body,
    this.status,
    this.route,
    this.createdAt,
    this.metadata = const {},
  });

  factory DashboardItem.fromJson(Map<String, dynamic> json) {
    return DashboardItem(
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      status: json['status'] as String?,
      route: json['route'] as String?,
      createdAt: _optionalDateTime(json['created_at'] ?? json['createdAt']),
      metadata: _mapFromJson(json['metadata']),
    );
  }

  final String type;
  final String title;
  final String? body;
  final String? status;
  final String? route;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;
}

class DashboardMetric {
  const DashboardMetric({
    required this.label,
    required this.value,
    this.delta,
    this.route,
    this.status,
  });

  factory DashboardMetric.fromJson(Map<String, dynamic> json) {
    return DashboardMetric(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      delta: json['delta'] as String?,
      route: json['route'] as String?,
      status: json['status'] as String?,
    );
  }

  final String label;
  final String value;
  final String? delta;
  final String? route;
  final String? status;
}

class DashboardSection {
  const DashboardSection({
    required this.title,
    this.body,
    this.route,
    this.empty = false,
    this.metrics = const [],
    this.items = const [],
  });

  factory DashboardSection.fromJson(Map<String, dynamic> json) {
    return DashboardSection(
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      route: json['route'] as String?,
      empty: json['empty'] as bool? ?? false,
      metrics: (json['metrics'] as List<dynamic>? ?? const [])
          .map((item) => DashboardMetric.fromJson(item as Map<String, dynamic>))
          .toList(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((item) => DashboardItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String title;
  final String? body;
  final String? route;
  final bool empty;
  final List<DashboardMetric> metrics;
  final List<DashboardItem> items;
}

class HomeDashboard {
  const HomeDashboard({
    required this.user,
    required this.hero,
    required this.quickActions,
    required this.performanceSnapshot,
    required this.todayFocus,
    required this.favoritesPreview,
    required this.recentActivity,
    required this.capabilities,
    this.priorityItem,
  });

  factory HomeDashboard.fromJson(Map<String, dynamic> json) {
    final priority = json['priority_item'] ?? json['priorityItem'];
    final hero = json['hero'] as Map<String, dynamic>? ?? const {};
    final snapshot =
        (json['performance_snapshot'] ?? json['performanceSnapshot'])
            as Map<String, dynamic>? ??
        const {};
    final focus =
        (json['today_focus'] ?? json['todayFocus']) as Map<String, dynamic>? ??
        const {};
    final favorites =
        (json['favorites_preview'] ?? json['favoritesPreview'])
            as List<dynamic>? ??
        const [];
    final recent =
        (json['recent_activity'] ?? json['recentActivity']) as List<dynamic>? ??
        const [];
    final quickActions =
        (json['quick_actions'] ?? json['quickActions']) as List<dynamic>? ??
        const [];
    return HomeDashboard(
      user: _mapFromJson(json['user']),
      priorityItem: priority == null
          ? null
          : DashboardItem.fromJson(priority as Map<String, dynamic>),
      hero: DashboardItem.fromJson(hero),
      quickActions: quickActions
          .map((item) => DashboardAction.fromJson(item as Map<String, dynamic>))
          .toList(),
      performanceSnapshot: DashboardSection.fromJson(snapshot),
      todayFocus: DashboardItem.fromJson(focus),
      favoritesPreview: favorites
          .map((item) => DashboardItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      recentActivity: recent
          .map((item) => DashboardItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      capabilities: (_mapFromJson(
        json['capabilities'],
      )).map((key, value) => MapEntry(key, value == true)),
    );
  }

  final Map<String, dynamic> user;
  final DashboardItem? priorityItem;
  final DashboardItem hero;
  final List<DashboardAction> quickActions;
  final DashboardSection performanceSnapshot;
  final DashboardItem todayFocus;
  final List<DashboardItem> favoritesPreview;
  final List<DashboardItem> recentActivity;
  final Map<String, bool> capabilities;
}

class StatsDashboard {
  const StatsDashboard({
    required this.timeframe,
    required this.title,
    required this.empty,
    required this.metrics,
    required this.sections,
    required this.capabilities,
    this.body,
  });

  factory StatsDashboard.fromJson(Map<String, dynamic> json) {
    return StatsDashboard(
      timeframe: json['timeframe'] as String? ?? 'all_time',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      empty: json['empty'] as bool? ?? false,
      metrics: (json['metrics'] as List<dynamic>? ?? const [])
          .map((item) => DashboardMetric.fromJson(item as Map<String, dynamic>))
          .toList(),
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .map(
            (item) => DashboardSection.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      capabilities: (_mapFromJson(
        json['capabilities'],
      )).map((key, value) => MapEntry(key, value == true)),
    );
  }

  final String timeframe;
  final String title;
  final String? body;
  final bool empty;
  final List<DashboardMetric> metrics;
  final List<DashboardSection> sections;
  final Map<String, bool> capabilities;
}

class ClubBagItem {
  const ClubBagItem({
    required this.id,
    required this.label,
    required this.clubType,
    required this.isActive,
    required this.displayOrder,
    required this.distanceUnit,
    this.carryDistance,
    this.totalDistance,
  });

  factory ClubBagItem.fromJson(Map<String, dynamic> json) {
    return ClubBagItem(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      clubType: json['club_type'] as String? ?? 'club',
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      carryDistance: json['carry_distance'] as int?,
      totalDistance: json['total_distance'] as int?,
      distanceUnit: json['distance_unit'] as String? ?? 'yards',
    );
  }

  final String id;
  final String label;
  final String clubType;
  final bool isActive;
  final int displayOrder;
  final int? carryDistance;
  final int? totalDistance;
  final String distanceUnit;
}

class FavoriteFolder {
  const FavoriteFolder({
    required this.id,
    required this.name,
    required this.displayOrder,
  });

  factory FavoriteFolder.fromJson(Map<String, dynamic> json) {
    return FavoriteFolder(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final int displayOrder;
}

class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.route,
    this.folderId,
    this.body,
    this.note,
    this.metadata = const {},
  });

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      folderId: json['folder_id'] as String?,
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      route: json['route'] as String? ?? '/favorites',
      note: json['note'] as String?,
      metadata: _mapFromJson(json['metadata']),
    );
  }

  final String id;
  final String? folderId;
  final String entityType;
  final String entityId;
  final String title;
  final String? body;
  final String route;
  final String? note;
  final Map<String, dynamic> metadata;
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.isRead,
    required this.createdAt,
    this.body,
    this.route,
    this.metadata = const {},
    this.readAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      route: json['route'] as String?,
      metadata: _mapFromJson(json['metadata']),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: _optionalDateTime(json['read_at']),
    );
  }

  final String id;
  final String type;
  final String title;
  final String? body;
  final String? route;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.analysisComplete,
    required this.tracerReview,
    required this.renderReady,
    required this.uploadFailure,
    required this.billing,
    required this.roundReminders,
    required this.system,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      analysisComplete: json['analysis_complete'] as bool? ?? true,
      tracerReview: json['tracer_review'] as bool? ?? true,
      renderReady: json['render_ready'] as bool? ?? true,
      uploadFailure: json['upload_failure'] as bool? ?? true,
      billing: json['billing'] as bool? ?? true,
      roundReminders: json['round_reminders'] as bool? ?? true,
      system: json['system'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysis_complete': analysisComplete,
      'tracer_review': tracerReview,
      'render_ready': renderReady,
      'upload_failure': uploadFailure,
      'billing': billing,
      'round_reminders': roundReminders,
      'system': system,
    };
  }

  NotificationPreferences copyWith({
    bool? analysisComplete,
    bool? tracerReview,
    bool? renderReady,
    bool? uploadFailure,
    bool? billing,
    bool? roundReminders,
    bool? system,
  }) {
    return NotificationPreferences(
      analysisComplete: analysisComplete ?? this.analysisComplete,
      tracerReview: tracerReview ?? this.tracerReview,
      renderReady: renderReady ?? this.renderReady,
      uploadFailure: uploadFailure ?? this.uploadFailure,
      billing: billing ?? this.billing,
      roundReminders: roundReminders ?? this.roundReminders,
      system: system ?? this.system,
    );
  }

  final bool analysisComplete;
  final bool tracerReview;
  final bool renderReady;
  final bool uploadFailure;
  final bool billing;
  final bool roundReminders;
  final bool system;
}

class RoundSummary {
  const RoundSummary({
    required this.holesCompleted,
    required this.holesPlanned,
    required this.totalPar,
    required this.penalties,
    required this.fairwaysHit,
    required this.fairwaysTotal,
    required this.greensInRegulation,
    required this.greensTotal,
    this.totalStrokes,
    this.scoreToPar,
    this.totalPutts,
  });

  factory RoundSummary.fromJson(Map<String, dynamic> json) {
    return RoundSummary(
      holesCompleted: json['holes_completed'] as int? ?? 0,
      holesPlanned: json['holes_planned'] as int? ?? 0,
      totalStrokes: json['total_strokes'] as int?,
      totalPar: json['total_par'] as int? ?? 0,
      scoreToPar: json['score_to_par'] as int?,
      totalPutts: json['total_putts'] as int?,
      penalties: json['penalties'] as int? ?? 0,
      fairwaysHit: json['fairways_hit'] as int? ?? 0,
      fairwaysTotal: json['fairways_total'] as int? ?? 0,
      greensInRegulation: json['greens_in_regulation'] as int? ?? 0,
      greensTotal: json['greens_total'] as int? ?? 0,
    );
  }

  final int holesCompleted;
  final int holesPlanned;
  final int? totalStrokes;
  final int totalPar;
  final int? scoreToPar;
  final int? totalPutts;
  final int penalties;
  final int fairwaysHit;
  final int fairwaysTotal;
  final int greensInRegulation;
  final int greensTotal;
}

class RoundHole {
  const RoundHole({
    required this.id,
    required this.roundId,
    required this.holeNumber,
    required this.par,
    required this.penalties,
    this.strokes,
    this.putts,
    this.fairwayHit,
    this.greenInRegulation,
    this.notes,
  });

  factory RoundHole.fromJson(Map<String, dynamic> json) {
    return RoundHole(
      id: json['id'] as String,
      roundId: json['round_id'] as String,
      holeNumber: json['hole_number'] as int? ?? 0,
      par: json['par'] as int? ?? 4,
      strokes: json['strokes'] as int?,
      putts: json['putts'] as int?,
      fairwayHit: json['fairway_hit'] as bool?,
      greenInRegulation: json['green_in_regulation'] as bool?,
      penalties: json['penalties'] as int? ?? 0,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String roundId;
  final int holeNumber;
  final int par;
  final int? strokes;
  final int? putts;
  final bool? fairwayHit;
  final bool? greenInRegulation;
  final int penalties;
  final String? notes;
}

class GolfRound {
  const GolfRound({
    required this.id,
    required this.holesPlanned,
    required this.status,
    required this.startedAt,
    required this.holes,
    required this.summary,
    this.title,
    this.courseName,
    this.teeName,
    this.completedAt,
    this.notes,
  });

  factory GolfRound.fromJson(Map<String, dynamic> json) {
    return GolfRound(
      id: json['id'] as String,
      title: json['title'] as String?,
      courseName: json['course_name'] as String?,
      teeName: json['tee_name'] as String?,
      holesPlanned: json['holes_planned'] as int? ?? 18,
      status: json['status'] as String? ?? 'in_progress',
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: _optionalDateTime(json['completed_at']),
      notes: json['notes'] as String?,
      holes: (json['holes'] as List<dynamic>? ?? const [])
          .map((item) => RoundHole.fromJson(item as Map<String, dynamic>))
          .toList(),
      summary: RoundSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String id;
  final String? title;
  final String? courseName;
  final String? teeName;
  final int holesPlanned;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? notes;
  final List<RoundHole> holes;
  final RoundSummary summary;
}

class RevenueCatCustomer {
  const RevenueCatCustomer({
    required this.appUserId,
    required this.entitlementId,
    required this.isEntitled,
    this.activeEntitlements = const [],
  });

  factory RevenueCatCustomer.fromJson(Map<String, dynamic> json) {
    return RevenueCatCustomer(
      appUserId: json['app_user_id'] as String? ?? '',
      entitlementId: json['entitlement_id'] as String? ?? '',
      isEntitled: json['is_entitled'] as bool? ?? false,
      activeEntitlements:
          (json['active_entitlements'] as List<dynamic>? ?? const [])
              .map(
                (item) => RevenueCatEntitlement.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }

  final String appUserId;
  final String entitlementId;
  final bool isEntitled;
  final List<RevenueCatEntitlement> activeEntitlements;
}

class RevenueCatEntitlement {
  const RevenueCatEntitlement({
    required this.entitlementId,
    required this.isActive,
    this.productId,
    this.expiresAt,
    this.store,
  });

  factory RevenueCatEntitlement.fromJson(Map<String, dynamic> json) {
    return RevenueCatEntitlement(
      entitlementId: json['entitlement_id'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      productId: json['product_id'] as String?,
      expiresAt: _optionalDateTime(json['expires_at']),
      store: json['store'] as String?,
    );
  }

  final String entitlementId;
  final bool isActive;
  final String? productId;
  final DateTime? expiresAt;
  final String? store;
}

class PrivacyInventory {
  const PrivacyInventory({
    required this.account,
    required this.profile,
    required this.clubBag,
    required this.favorites,
    required this.rounds,
    required this.notifications,
    required this.uploads,
    required this.swingVideos,
    required this.analysis,
    required this.shotTracer,
    required this.entitlements,
    required this.links,
  });

  factory PrivacyInventory.fromJson(Map<String, dynamic> json) {
    return PrivacyInventory(
      account: _mapFromJson(json['account']),
      profile: _mapFromJson(json['profile']),
      clubBag: _mapFromJson(json['club_bag']),
      favorites: _mapFromJson(json['favorites']),
      rounds: _mapFromJson(json['rounds']),
      notifications: _mapFromJson(json['notifications']),
      uploads: _mapFromJson(json['uploads']),
      swingVideos: _mapFromJson(json['swing_videos']),
      analysis: _mapFromJson(json['analysis']),
      shotTracer: _mapFromJson(json['shot_tracer']),
      entitlements: _mapFromJson(json['entitlements']),
      links: _stringMap(json['links']),
    );
  }

  final Map<String, dynamic> account;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> clubBag;
  final Map<String, dynamic> favorites;
  final Map<String, dynamic> rounds;
  final Map<String, dynamic> notifications;
  final Map<String, dynamic> uploads;
  final Map<String, dynamic> swingVideos;
  final Map<String, dynamic> analysis;
  final Map<String, dynamic> shotTracer;
  final Map<String, dynamic> entitlements;
  final Map<String, String> links;
}

class AppleNonce {
  const AppleNonce({
    required this.nonce,
    required this.nonceSha256,
    required this.expiresInSeconds,
  });

  factory AppleNonce.fromJson(Map<String, dynamic> json) {
    return AppleNonce(
      nonce: json['nonce'] as String? ?? '',
      nonceSha256: json['nonce_sha256'] as String? ?? '',
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 0,
    );
  }

  final String nonce;
  final String nonceSha256;
  final int expiresInSeconds;
}

class Consent {
  const Consent({required this.consentType});

  factory Consent.fromJson(Map<String, dynamic> json) {
    return Consent(consentType: json['consent_type'] as String);
  }

  final String consentType;
}

class UploadRecord {
  const UploadRecord({required this.id});

  factory UploadRecord.fromJson(Map<String, dynamic> json) {
    return UploadRecord(id: json['id'] as String);
  }

  final String id;
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
    this.durationMs,
    this.qualityScore,
    this.qualityStatus,
    this.qualityChecks = const [],
  });

  factory SwingVideo.fromJson(Map<String, dynamic> json) {
    return SwingVideo(
      id: json['id'] as String,
      angle: json['angle'] as String,
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
    required this.sessionType,
    required this.createdAt,
    this.club,
    this.locationType,
    this.videos = const [],
  });

  factory SwingSession.fromJson(Map<String, dynamic> json) {
    return SwingSession(
      id: json['id'] as String,
      status: json['status'] as String,
      sessionType: json['session_type'] as String? ?? 'analysis',
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
  final String sessionType;
  final String? club;
  final String? locationType;
  final DateTime createdAt;
  final List<SwingVideo> videos;
}

class TracerJob {
  const TracerJob({
    required this.id,
    required this.sessionId,
    required this.swingVideoId,
    required this.jobType,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.errorMessage,
    this.rqJobId,
    this.startedAt,
    this.completedAt,
  });

  factory TracerJob.fromJson(Map<String, dynamic> json) {
    return TracerJob(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      swingVideoId: json['swing_video_id'] as String,
      jobType: json['job_type'] as String? ?? 'detect',
      status: json['status'] as String,
      progress: json['progress'] as int? ?? 0,
      errorMessage: json['error_message'] as String?,
      rqJobId: json['rq_job_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: _optionalDateTime(json['started_at']),
      completedAt: _optionalDateTime(json['completed_at']),
    );
  }

  final String id;
  final String sessionId;
  final String swingVideoId;
  final String jobType;
  final String status;
  final int progress;
  final String? errorMessage;
  final String? rqJobId;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isActive => status == 'pending' || status == 'running';
  bool get isFailed => status == 'failed';
  bool get isSucceeded => status == 'succeeded';
}

class TracerResult {
  const TracerResult({
    required this.id,
    required this.jobId,
    required this.sessionId,
    required this.swingVideoId,
    required this.status,
    required this.ballPath,
    required this.metrics,
    required this.style,
    required this.render,
    required this.createdAt,
    required this.updatedAt,
    required this.hasRenderVideo,
    required this.hasThumbnail,
    this.confidence,
  });

  factory TracerResult.fromJson(Map<String, dynamic> json) {
    final render = _mapFromJson(json['render']);
    final hasRender =
        json['has_render_video'] as bool? ??
        render['available'] as bool? ??
        (json['render_video_storage_key'] != null);
    return TracerResult(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      sessionId: json['session_id'] as String,
      swingVideoId: json['swing_video_id'] as String,
      confidence: (json['confidence'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'needs_review',
      ballPath: _listOfMapsFromJson(json['ball_path']),
      metrics: _mapFromJson(json['metrics']),
      render: render,
      hasRenderVideo: hasRender,
      hasThumbnail:
          json['has_thumbnail'] as bool? ??
          (hasRender && json['thumbnail_storage_key'] != null),
      style: _mapFromJson(json['style']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String jobId;
  final String sessionId;
  final String swingVideoId;
  final double? confidence;
  final String status;
  final List<Map<String, dynamic>> ballPath;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> render;
  final bool hasRenderVideo;
  final bool hasThumbnail;
  final Map<String, dynamic> style;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasRender => hasRenderVideo;
  bool get needsReview => status == 'needs_review';
  bool get needsBetterCapture {
    return needsReview || metrics['needs_better_capture'] == true;
  }

  Map<String, dynamic> get tracking => _mapFromJson(metrics['tracking']);
  Map<String, dynamic> get flight => _mapFromJson(metrics['flight']);
  String get pathSource => tracking['path_source'] as String? ?? '';
  String get trackingLabel {
    if (needsBetterCapture) return 'NEEDS BETTER CAPTURE';
    if (pathSource == 'auto_detected') return 'AUTO TRACKED';
    return status.toUpperCase().replaceAll('_', ' ');
  }

  int? get impactTimestampMs {
    final value =
        tracking['impact_timestamp_ms'] ?? tracking['launch_timestamp_ms'];
    return (value as num?)?.toInt();
  }

  int? get apexTimestampMs {
    if (ballPath.isEmpty) return null;
    Map<String, dynamic>? apex;
    for (final point in ballPath) {
      if (apex == null ||
          ((point['y'] as num?)?.toDouble() ?? 1.0) <
              ((apex['y'] as num?)?.toDouble() ?? 1.0)) {
        apex = point;
      }
    }
    return (apex?['timestamp_ms'] as num?)?.toInt();
  }

  int? get landingTimestampMs {
    if (ballPath.isEmpty) return null;
    return (ballPath.last['timestamp_ms'] as num?)?.toInt();
  }

  int get observedPointCount {
    return (tracking['observed_point_count'] as num?)?.toInt() ?? 0;
  }

  int get interpolatedPointCount {
    return (tracking['interpolated_point_count'] as num?)?.toInt() ?? 0;
  }

  int get trackingGapCount {
    return (tracking['gap_count'] as num?)?.toInt() ?? 0;
  }

  List<String> get trackingFailureReasons {
    final raw = tracking['failure_reasons'];
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  Map<String, dynamic> get captureGate =>
      _mapFromJson(tracking['capture_gate']);

  List<Map<String, dynamic>> get failedCaptureGateChecks {
    final raw = captureGate['checks'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .where((item) => item['passed'] != true)
        .toList(growable: false);
  }

  List<String> get failedCaptureGateGuidance {
    return failedCaptureGateChecks
        .map((check) => _captureGateGuidance(check['code'] as String? ?? ''))
        .where((message) => message.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  bool get hasFlightMetrics => flight.isNotEmpty;

  String get flightSummary {
    return flight['summary'] as String? ??
        'Visual flight metrics are not available yet.';
  }

  String get flightStatusLabel {
    final status = flight['status'] as String? ?? '';
    if (status.isEmpty) return 'UNKNOWN';
    return status.toUpperCase().replaceAll('_', ' ');
  }

  String get visualLaunchLabel {
    return _degreeLabel(flight['visual_launch_angle_degrees']);
  }

  String get startDirectionDeltaLabel {
    return _degreeLabel(flight['start_direction_delta_degrees']);
  }

  String get apexRiseLabel {
    final value = (flight['peak_height_norm'] as num?)?.toDouble();
    if (value == null) return 'N/A';
    return '${(value * 100).round()}% FRAME';
  }

  String get curveBiasLabel {
    final strength = flight['curve_strength'] as String? ?? 'unknown';
    final direction = flight['curve_direction'] as String? ?? 'unknown';
    if (strength == 'straight' || direction == 'straight') return 'STRAIGHT';
    return '${strength.toUpperCase()} ${direction.toUpperCase()}';
  }
}

String _degreeLabel(Object? value) {
  final number = (value as num?)?.toDouble();
  if (number == null) return 'N/A';
  return '${number.toStringAsFixed(1)}°';
}

String _captureGateGuidance(String code) {
  switch (code) {
    case 'camera_source':
      return 'Use the guided rear camera instead of gallery import.';
    case 'native_capture_source':
      return 'Record with the native high-FPS tracer camera.';
    case 'native_device_tier':
      return 'Use a device/camera mode that supports high-FPS tracer capture.';
    case 'native_measured_fps':
      return 'Use a high-FPS mode that records at 120 FPS or higher.';
    case 'native_dropped_frames_ok':
      return 'Keep the phone cool and steady so high-FPS recording does not drop frames.';
    case 'rear_camera_active':
      return 'Use the rear camera so ball flight stays visible.';
    case 'capture_guide_active':
      return 'Keep the SwingLens tracer guide active before recording.';
    case 'guide_version_supported':
      return 'Update the app before recording a guided tracer.';
    case 'client_auto_eligible':
      return 'Wait for RANGE READY before recording.';
    case 'not_simulator_or_unverified':
      return 'Record on a real device with verified motion sensors.';
    case 'ball_anchor_set':
      return 'Place the ball marker directly on the golf ball.';
    case 'ball_anchor_launch_zone':
      return 'Keep the ball marker in the lower launch zone of the frame.';
    case 'target_line_set':
      return 'Set a clear target line from the ball toward flight.';
    case 'target_line_forward':
      return 'Point the target arrow forward from the ball toward the flight window.';
    case 'white_ball_confirmed':
      return 'Confirm a visible white ball before recording.';
    case 'phone_level':
      return 'Level the phone before starting capture.';
    case 'phone_stable':
      return 'Hold the phone steady for at least one second.';
    case 'stable_duration_1s':
      return 'Hold the phone still until the one-second stability check passes.';
    case 'ball_visible':
      return 'Frame the ball clearly at address.';
    case 'golfer_in_frame':
      return 'Keep the golfer fully in frame.';
    case 'duration_ok':
      return 'Keep tracer clips between 2 and 15 seconds.';
    case 'fps_ok':
      return 'Record at 24 FPS or higher.';
    case 'resolution_ok':
      return 'Record at 720p or higher.';
    default:
      return '';
  }
}

class TracerEdit {
  const TracerEdit({
    required this.id,
    required this.tracerResultId,
    required this.controlPoints,
    required this.effectivePath,
    required this.reviewedStyle,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TracerEdit.fromJson(Map<String, dynamic> json) {
    return TracerEdit(
      id: json['id'] as String,
      tracerResultId: json['tracer_result_id'] as String,
      controlPoints: _listOfMapsFromJson(json['control_points']),
      effectivePath: _listOfMapsFromJson(json['effective_path']),
      reviewedStyle: _mapFromJson(json['reviewed_style']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String tracerResultId;
  final List<Map<String, dynamic>> controlPoints;
  final List<Map<String, dynamic>> effectivePath;
  final Map<String, dynamic> reviewedStyle;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AnalysisJob {
  const AnalysisJob({
    required this.id,
    required this.sessionId,
    required this.swingVideoId,
    required this.status,
    required this.progress,
    required this.attemptCount,
    required this.maxAttempts,
    required this.createdAt,
    this.errorMessage,
    this.rqJobId,
    this.startedAt,
    this.completedAt,
  });

  factory AnalysisJob.fromJson(Map<String, dynamic> json) {
    return AnalysisJob(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      swingVideoId: json['swing_video_id'] as String,
      status: json['status'] as String,
      progress: json['progress'] as int? ?? 0,
      attemptCount: json['attempt_count'] as int? ?? 0,
      maxAttempts: json['max_attempts'] as int? ?? 1,
      errorMessage: json['error_message'] as String?,
      rqJobId: json['rq_job_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: _optionalDateTime(json['started_at']),
      completedAt: _optionalDateTime(json['completed_at']),
    );
  }

  final String id;
  final String sessionId;
  final String swingVideoId;
  final String status;
  final int progress;
  final int attemptCount;
  final int maxAttempts;
  final String? errorMessage;
  final String? rqJobId;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isActive => status == 'pending' || status == 'running';
  bool get isFailed => status == 'failed';
  bool get isSucceeded => status == 'succeeded';
}

class AnalysisKeyframe {
  const AnalysisKeyframe({
    required this.id,
    required this.phaseCode,
    required this.frameIndex,
    required this.timestampMs,
    required this.createdAt,
    this.confidence,
  });

  factory AnalysisKeyframe.fromJson(Map<String, dynamic> json) {
    return AnalysisKeyframe(
      id: json['id'] as String,
      phaseCode: json['phase_code'] as String,
      frameIndex: json['frame_index'] as int,
      timestampMs: json['timestamp_ms'] as int,
      confidence: (json['confidence'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String phaseCode;
  final int frameIndex;
  final int timestampMs;
  final double? confidence;
  final DateTime createdAt;
}

class AnalysisResult {
  const AnalysisResult({
    required this.id,
    required this.jobId,
    required this.sessionId,
    required this.swingVideoId,
    required this.summary,
    required this.report,
    required this.phases,
    required this.metrics,
    required this.poseSummary,
    required this.keyframes,
    required this.createdAt,
    this.prototypeScore,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      sessionId: json['session_id'] as String,
      swingVideoId: json['swing_video_id'] as String,
      prototypeScore: (json['prototype_score'] as num?)?.toDouble(),
      summary: json['summary'] as String? ?? 'Prototype analysis completed.',
      report: _mapFromJson(json['report']),
      phases: _listOfMapsFromJson(json['phases']),
      metrics: _mapFromJson(json['metrics']),
      poseSummary: _mapFromJson(json['pose_summary']),
      keyframes: (json['keyframes'] as List<dynamic>? ?? const [])
          .map(
            (keyframe) =>
                AnalysisKeyframe.fromJson(keyframe as Map<String, dynamic>),
          )
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String jobId;
  final String sessionId;
  final String swingVideoId;
  final double? prototypeScore;
  final String summary;
  final Map<String, dynamic> report;
  final List<Map<String, dynamic>> phases;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> poseSummary;
  final List<AnalysisKeyframe> keyframes;
  final DateTime createdAt;
}

class PhaseOverride {
  const PhaseOverride({required this.phaseCode, required this.timestampMs});

  Map<String, dynamic> toJson() {
    return {'phase_code': phaseCode, 'timestamp_ms': timestampMs};
  }

  final String phaseCode;
  final int timestampMs;
}

class AnalysisEventReview {
  const AnalysisEventReview({
    required this.id,
    required this.analysisResultId,
    required this.phaseOverrides,
    required this.effectivePhases,
    required this.reviewedMetrics,
    required this.reviewedReport,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnalysisEventReview.fromJson(Map<String, dynamic> json) {
    return AnalysisEventReview(
      id: json['id'] as String,
      analysisResultId: json['analysis_result_id'] as String,
      phaseOverrides: _listOfMapsFromJson(json['phase_overrides']),
      effectivePhases: _listOfMapsFromJson(json['effective_phases']),
      reviewedMetrics: _mapFromJson(json['reviewed_metrics']),
      reviewedReport: _mapFromJson(json['reviewed_report']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String analysisResultId;
  final List<Map<String, dynamic>> phaseOverrides;
  final List<Map<String, dynamic>> effectivePhases;
  final Map<String, dynamic> reviewedMetrics;
  final Map<String, dynamic> reviewedReport;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SwingReport {
  const SwingReport({
    required this.version,
    required this.status,
    required this.source,
    required this.metricCards,
    required this.findings,
    required this.limitations,
    this.score,
  });

  factory SwingReport.fromJson(Map<String, dynamic> json) {
    return SwingReport(
      version: json['version'] as String? ?? '',
      status: json['status'] as String? ?? 'limited',
      source: json['source'] as String? ?? 'detected',
      score: json['score'] as int?,
      metricCards: (json['metric_cards'] as List<dynamic>? ?? const [])
          .map((item) => SwingMetricCard.fromJson(item as Map<String, dynamic>))
          .toList(),
      findings: (json['findings'] as List<dynamic>? ?? const [])
          .map((item) => SwingFinding.fromJson(item as Map<String, dynamic>))
          .toList(),
      limitations: (json['limitations'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  final String version;
  final String status;
  final String source;
  final int? score;
  final List<SwingMetricCard> metricCards;
  final List<SwingFinding> findings;
  final List<String> limitations;
}

class SwingMetricCard {
  const SwingMetricCard({
    required this.code,
    required this.label,
    required this.unit,
    required this.status,
    required this.summary,
    this.value,
    this.evidenceTimestampMs,
  });

  factory SwingMetricCard.fromJson(Map<String, dynamic> json) {
    return SwingMetricCard(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: json['value'],
      unit: json['unit'] as String? ?? '',
      status: json['status'] as String? ?? 'info',
      summary: json['summary'] as String? ?? '',
      evidenceTimestampMs: json['evidence_timestamp_ms'] as int?,
    );
  }

  final String code;
  final String label;
  final Object? value;
  final String unit;
  final String status;
  final String summary;
  final int? evidenceTimestampMs;
}

class SwingFinding {
  const SwingFinding({
    required this.code,
    required this.label,
    required this.severity,
    required this.whatHappened,
    required this.whyItMatters,
    required this.drill,
    required this.nextGoal,
    this.confidence,
    this.evidenceTimestampMs,
  });

  factory SwingFinding.fromJson(Map<String, dynamic> json) {
    return SwingFinding(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? 'Swing pattern',
      severity: json['severity'] as String? ?? 'info',
      confidence: (json['confidence'] as num?)?.toDouble(),
      whatHappened: json['what_happened'] as String? ?? '',
      whyItMatters: json['why_it_matters'] as String? ?? '',
      evidenceTimestampMs: json['evidence_timestamp_ms'] as int?,
      drill: json['drill'] as String? ?? '',
      nextGoal: json['next_goal'] as String? ?? '',
    );
  }

  final String code;
  final String label;
  final String severity;
  final double? confidence;
  final String whatHappened;
  final String whyItMatters;
  final int? evidenceTimestampMs;
  final String drill;
  final String nextGoal;
}

class AnalysisOverlayTrack {
  const AnalysisOverlayTrack({
    required this.resultId,
    required this.swingVideoId,
    required this.coordinateSpace,
    required this.landmarkSchema,
    required this.segments,
    required this.frames,
    required this.checkpoints,
    required this.faultCheckpoints,
    this.durationMs,
    this.resolutionWidth,
    this.resolutionHeight,
  });

  factory AnalysisOverlayTrack.fromJson(Map<String, dynamic> json) {
    return AnalysisOverlayTrack(
      resultId: json['result_id'] as String,
      swingVideoId: json['swing_video_id'] as String,
      durationMs: json['duration_ms'] as int?,
      resolutionWidth: json['resolution_width'] as int?,
      resolutionHeight: json['resolution_height'] as int?,
      coordinateSpace:
          json['coordinate_space'] as String? ?? 'normalized_image',
      landmarkSchema: json['landmark_schema'] as String? ?? 'mediapipe_pose_33',
      segments: (json['segments'] as List<dynamic>? ?? const [])
          .map((item) => OverlaySegment.fromJson(item as Map<String, dynamic>))
          .toList(),
      frames: (json['frames'] as List<dynamic>? ?? const [])
          .map((item) => OverlayFrame.fromJson(item as Map<String, dynamic>))
          .toList(),
      checkpoints: (json['checkpoints'] as List<dynamic>? ?? const [])
          .map(
            (item) => OverlayCheckpoint.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      faultCheckpoints:
          (json['fault_checkpoints'] as List<dynamic>? ?? const [])
              .map(
                (item) => OverlayFaultCheckpoint.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }

  final String resultId;
  final String swingVideoId;
  final int? durationMs;
  final int? resolutionWidth;
  final int? resolutionHeight;
  final String coordinateSpace;
  final String landmarkSchema;
  final List<OverlaySegment> segments;
  final List<OverlayFrame> frames;
  final List<OverlayCheckpoint> checkpoints;
  final List<OverlayFaultCheckpoint> faultCheckpoints;

  int get effectiveDurationMs {
    final explicit = durationMs;
    if (explicit != null && explicit > 0) return explicit;
    if (frames.isEmpty) return 0;
    return frames.last.timestampMs;
  }

  double get aspectRatio {
    final width = resolutionWidth;
    final height = resolutionHeight;
    if (width != null && height != null && width > 0 && height > 0) {
      return (width / height).clamp(0.42, 1.9).toDouble();
    }
    return 16 / 9;
  }
}

class OverlaySegment {
  const OverlaySegment({
    required this.from,
    required this.to,
    required this.style,
  });

  factory OverlaySegment.fromJson(Map<String, dynamic> json) {
    return OverlaySegment(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      style: json['style'] as String? ?? 'skeleton',
    );
  }

  final String from;
  final String to;
  final String style;
}

class OverlayFrame {
  const OverlayFrame({
    required this.frameIndex,
    required this.timestampMs,
    required this.poseDetected,
    required this.points,
    this.averageVisibility,
    this.guideLines = const [],
    this.metrics = const {},
  });

  factory OverlayFrame.fromJson(Map<String, dynamic> json) {
    return OverlayFrame(
      frameIndex: json['frame_index'] as int? ?? 0,
      timestampMs: json['timestamp_ms'] as int? ?? 0,
      poseDetected: json['pose_detected'] as bool? ?? false,
      averageVisibility: (json['average_visibility'] as num?)?.toDouble(),
      points: _pointMapFromJson(json['points']),
      guideLines: _listOfMapsFromJson(json['guide_lines']),
      metrics: _doubleMapFromJson(json['metrics']),
    );
  }

  final int frameIndex;
  final int timestampMs;
  final bool poseDetected;
  final double? averageVisibility;
  final Map<String, Map<String, double>> points;
  final List<Map<String, dynamic>> guideLines;
  final Map<String, double> metrics;

  Map<String, dynamic> toPainterOverlay() {
    return {'points': points, 'guide_lines': guideLines};
  }
}

class OverlayCheckpoint {
  const OverlayCheckpoint({
    required this.phaseCode,
    required this.label,
    required this.timestampMs,
    this.frameIndex,
    this.confidence,
    this.detectionMethod,
    this.detectionStatus,
    this.source = 'detected',
  });

  factory OverlayCheckpoint.fromJson(Map<String, dynamic> json) {
    return OverlayCheckpoint(
      phaseCode: json['phase_code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      timestampMs: json['timestamp_ms'] as int? ?? 0,
      frameIndex: json['frame_index'] as int?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      detectionMethod: json['detection_method'] as String?,
      detectionStatus: json['detection_status'] as String?,
      source: json['source'] as String? ?? 'detected',
    );
  }

  final String phaseCode;
  final String label;
  final int timestampMs;
  final int? frameIndex;
  final double? confidence;
  final String? detectionMethod;
  final String? detectionStatus;
  final String source;
}

class OverlayFaultCheckpoint {
  const OverlayFaultCheckpoint({
    required this.code,
    required this.label,
    required this.timestampMs,
    this.frameIndex,
    this.phaseCode,
    this.confidence,
    this.evidence,
    this.drill,
    this.nextGoal,
    this.isPrimary = false,
  });

  factory OverlayFaultCheckpoint.fromJson(Map<String, dynamic> json) {
    return OverlayFaultCheckpoint(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? 'Swing pattern',
      timestampMs: json['timestamp_ms'] as int? ?? 0,
      frameIndex: json['frame_index'] as int?,
      phaseCode: json['phase_code'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      evidence: json['evidence'] as String?,
      drill: json['drill'] as String?,
      nextGoal: json['next_goal'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }

  final String code;
  final String label;
  final int timestampMs;
  final int? frameIndex;
  final String? phaseCode;
  final double? confidence;
  final String? evidence;
  final String? drill;
  final String? nextGoal;
  final bool isPrimary;
}

DateTime? _optionalDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.parse(value as String);
}

Map<String, dynamic> _mapFromJson(Object? value) {
  if (value == null) return const {};
  return Map<String, dynamic>.from(value as Map);
}

Map<String, String> _stringMap(Object? value) {
  if (value == null) return const {};
  final raw = Map<String, dynamic>.from(value as Map);
  return raw.map((key, item) => MapEntry(key, item.toString()));
}

List<Map<String, dynamic>> _listOfMapsFromJson(Object? value) {
  if (value == null) return const [];
  return (value as List<dynamic>)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}

Map<String, Map<String, double>> _pointMapFromJson(Object? value) {
  if (value == null) return const {};
  final raw = Map<String, dynamic>.from(value as Map);
  return raw.map((key, item) {
    final point = Map<String, dynamic>.from(item as Map);
    return MapEntry(
      key,
      point.map((pointKey, pointValue) {
        return MapEntry(pointKey, (pointValue as num).toDouble());
      }),
    );
  });
}

Map<String, double> _doubleMapFromJson(Object? value) {
  if (value == null) return const {};
  final raw = Map<String, dynamic>.from(value as Map);
  return raw.map((key, item) => MapEntry(key, (item as num).toDouble()));
}
