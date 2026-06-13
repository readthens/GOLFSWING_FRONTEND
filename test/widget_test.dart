import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import 'package:swinglens_ai/src/api/api_client.dart';
import 'package:swinglens_ai/src/app.dart';
import 'package:swinglens_ai/src/auth/auth_controller.dart';
import 'package:swinglens_ai/src/capture/native_capture_bridge.dart';
import 'package:swinglens_ai/src/capture/tracer_readiness.dart';
import 'package:swinglens_ai/src/screens/home_screens.dart';
import 'package:swinglens_ai/src/offline/offline_queue.dart';
import 'package:swinglens_ai/src/screens/settings_screens.dart';
import 'package:swinglens_ai/src/screens/swing_film_room.dart';
import 'package:swinglens_ai/src/screens/upload_screens.dart';
import 'package:swinglens_ai/src/theme/app_theme.dart';
import 'package:swinglens_ai/src/models.dart';

class OnboardingTestAuthController extends AuthController {
  OnboardingTestAuthController()
    : super(ApiClient(baseUrl: 'http://localhost:8000')) {
    state = const AuthState(
      user: UserProfile(id: 'local-test-user', email: 'local-test@example.com'),
      accessToken: 'local-access-token',
      refreshToken: 'local-refresh-token',
    );
  }

  int updateProfileCalls = 0;

  @override
  Future<void> updateProfile(Map<String, dynamic> payload) async {
    updateProfileCalls += 1;
    state = state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    await Future<void>.value();

    final current = state.profile;
    state = state.copyWith(
      isLoading: false,
      profile: GolferProfile(
        userId: state.user!.id,
        handedness: payload['handedness'] as String? ?? current?.handedness,
        skillLevel: payload['skill_level'] as String? ?? current?.skillLevel,
        goals:
            (payload['goals'] as List<dynamic>?)?.cast<String>() ??
            current?.goals ??
            const [],
        commonMiss: payload['common_miss'] as String? ?? current?.commonMiss,
        unitsSystem:
            payload['units_system'] as String? ??
            current?.unitsSystem ??
            'imperial',
        distanceUnit:
            payload['distance_unit'] as String? ??
            current?.distanceUnit ??
            'yards',
        defaultCaptureMode:
            payload['default_capture_mode'] as String? ??
            current?.defaultCaptureMode ??
            'analysis',
      ),
    );
    notifyListeners();
  }
}

class FailingRegisterApiClient extends ApiClient {
  FailingRegisterApiClient({required this.statusCode, required this.data})
    : super(baseUrl: 'http://localhost:8000');

  final int statusCode;
  final Object data;

  @override
  Future<AuthPayload> register({
    required String email,
    required String password,
  }) async {
    final requestOptions = RequestOptions(path: '/v1/auth/register');
    throw DioException(
      requestOptions: requestOptions,
      response: Response(
        requestOptions: requestOptions,
        statusCode: statusCode,
        data: data,
      ),
    );
  }
}

class ReturningUserApiClient extends ApiClient {
  ReturningUserApiClient() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<AuthPayload> login({
    required String email,
    required String password,
  }) async {
    return AuthPayload.fromJson({
      'access_token': 'returning-access-token',
      'refresh_token': 'returning-refresh-token',
      'user': {
        'id': 'returning-user',
        'email': email,
        'auth_provider': 'password',
        'created_at': '2026-06-06T00:00:00Z',
      },
    });
  }

  @override
  Future<MePayload> getMe(String accessToken) async {
    return MePayload.fromJson({
      'user': {
        'id': 'returning-user',
        'email': 'returning@example.com',
        'auth_provider': 'password',
        'created_at': '2026-06-06T00:00:00Z',
      },
      'profile': {
        'user_id': 'returning-user',
        'handedness': 'right',
        'skill_level': 'intermediate',
        'goals': ['clean_contact'],
      },
    });
  }

  @override
  Future<List<Consent>> getConsents(String accessToken) async {
    return [
      Consent.fromJson({'consent_type': 'video_processing'}),
    ];
  }
}

class HydrationFailingLoginApiClient extends ApiClient {
  HydrationFailingLoginApiClient() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<AuthPayload> login({
    required String email,
    required String password,
  }) async {
    return AuthPayload.fromJson({
      'access_token': 'temporary-access-token',
      'refresh_token': 'temporary-refresh-token',
      'user': {
        'id': 'hydration-user',
        'email': email,
        'auth_provider': 'password',
        'created_at': '2026-06-06T00:00:00Z',
      },
    });
  }

  @override
  Future<MePayload> getMe(String accessToken) async {
    throw DioException(requestOptions: RequestOptions(path: '/v1/me'));
  }
}

class ReadyTestAuthController extends AuthController {
  ReadyTestAuthController()
    : super(ApiClient(baseUrl: 'http://localhost:8000')) {
    state = const AuthState(
      user: UserProfile(id: 'local-test-user', email: 'local-test@example.com'),
      profile: GolferProfile(
        userId: 'local-test-user',
        handedness: 'right',
        skillLevel: 'intermediate',
        goals: ['clean_contact'],
      ),
      accessToken: 'local-access-token',
      refreshToken: 'local-refresh-token',
      hasVideoConsent: true,
    );
  }
}

class NoConsentTestAuthController extends AuthController {
  NoConsentTestAuthController()
    : super(ApiClient(baseUrl: 'http://localhost:8000')) {
    state = const AuthState(
      user: UserProfile(id: 'local-test-user', email: 'local-test@example.com'),
      accessToken: 'local-access-token',
      refreshToken: 'local-refresh-token',
    );
  }
}

class SwingDetailApiClient extends ApiClient {
  SwingDetailApiClient({
    this.analysisResult,
    this.analysisResultAfterStart,
    this.startJob,
    this.polledJob,
    this.pollFails = false,
    this.tracerSession = false,
    this.tracerResult,
    this.tracerResultAfterStart,
    this.startTracerJobPayload,
    this.polledTracerJob,
    this.tracerPollFails = false,
    this.failFavoriteWrites = false,
  }) : super(baseUrl: 'http://localhost:8000');

  final AnalysisResult? analysisResult;
  final AnalysisResult? analysisResultAfterStart;
  final AnalysisJob? startJob;
  final AnalysisJob? polledJob;
  final bool pollFails;
  final bool tracerSession;
  final TracerResult? tracerResult;
  final TracerResult? tracerResultAfterStart;
  final TracerJob? startTracerJobPayload;
  final TracerJob? polledTracerJob;
  final bool tracerPollFails;
  final bool failFavoriteWrites;
  int startCalls = 0;
  int tracerStartCalls = 0;
  int renderStartCalls = 0;
  List<PhaseOverride> savedOverrides = const [];
  List<Map<String, num>> savedTracerControlPoints = const [];
  Map<String, dynamic> savedTracerStyle = const {};
  bool resetReviewCalled = false;
  bool deleteVideoCalled = false;
  bool deleteAccountCalled = false;
  int saveFavoriteCalls = 0;
  int deleteFavoriteCalls = 0;
  String? lastFavoriteIdempotencyKey;
  List<FavoriteItem> favorites = const [];

  @override
  Future<SwingSession> getSwingSession(
    String accessToken,
    String sessionId,
  ) async {
    return SwingSession.fromJson({
      'id': sessionId,
      'status': tracerSession ? 'ready_for_tracer' : 'video_uploaded',
      'club': '7 iron',
      'session_type': tracerSession ? 'tracer' : 'analysis',
      'location_type': 'range',
      'created_at': '2026-06-06T00:00:00Z',
      'videos': [
        {
          'id': 'video-1',
          'upload_id': 'upload-1',
          'storage_key': 'users/local/uploads/upload-1/swing.mp4',
          'angle': tracerSession ? 'rear_tracer' : 'down_the_line',
          'duration_ms': 4200,
          'quality_score': 80,
          'quality_status': 'warn',
          'quality_checks': [
            {
              'id': 'guide_overlay',
              'severity': 'warn',
              'message':
                  'Gallery videos may not use the SwingLens capture guide.',
            },
          ],
        },
      ],
    });
  }

  @override
  Future<AnalysisResult?> getAnalysisResult(
    String accessToken,
    String sessionId,
  ) async {
    if (startCalls > 0 && analysisResultAfterStart != null) {
      return analysisResultAfterStart;
    }
    return analysisResult;
  }

  @override
  Future<AnalysisJob> startAnalysisJob(
    String accessToken,
    String sessionId, {
    bool force = false,
  }) async {
    startCalls += 1;
    return startJob ?? _analysisJob(status: 'running', progress: 35);
  }

  @override
  Future<AnalysisJob> getAnalysisJob(String accessToken, String jobId) async {
    if (pollFails) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/analysis-jobs/$jobId'),
      );
    }
    return polledJob ??
        startJob ??
        _analysisJob(status: 'running', progress: 55);
  }

  @override
  Future<TracerResult?> getTracerResult(
    String accessToken,
    String sessionId,
  ) async {
    if (tracerStartCalls > 0 && tracerResultAfterStart != null) {
      return tracerResultAfterStart;
    }
    return tracerResult;
  }

  @override
  Future<TracerJob> startTracerJob(String accessToken, String sessionId) async {
    tracerStartCalls += 1;
    return startTracerJobPayload ??
        _tracerJob(status: 'running', progress: 45, jobType: 'detect');
  }

  @override
  Future<TracerJob> getTracerJob(String accessToken, String jobId) async {
    if (tracerPollFails) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/tracer-jobs/$jobId'),
      );
    }
    return polledTracerJob ??
        startTracerJobPayload ??
        _tracerJob(status: 'running', progress: 55, jobType: 'detect');
  }

  @override
  Future<TracerEdit> saveTracerEdit({
    required String accessToken,
    required String resultId,
    required List<Map<String, num>> controlPoints,
    required Map<String, dynamic> style,
  }) async {
    savedTracerControlPoints = controlPoints;
    savedTracerStyle = style;
    return TracerEdit.fromJson({
      'id': 'tracer-edit-1',
      'tracer_result_id': resultId,
      'control_points': controlPoints,
      'effective_path': controlPoints
          .asMap()
          .entries
          .map((entry) => {...entry.value, 'timestamp_ms': entry.key * 160})
          .toList(),
      'reviewed_style': style,
      'created_at': '2026-06-06T00:00:12Z',
      'updated_at': '2026-06-06T00:00:12Z',
    });
  }

  @override
  Future<TracerJob> startTracerRenderJob({
    required String accessToken,
    required String resultId,
  }) async {
    renderStartCalls += 1;
    return _tracerJob(status: 'succeeded', progress: 100, jobType: 'render');
  }

  @override
  Future<void> downloadTracerVideoFile({
    required String accessToken,
    required String resultId,
    required String destinationPath,
  }) async {}

  @override
  String analysisKeyframeImageUrl(String keyframeId) {
    return 'https://example.test/keyframes/$keyframeId.jpg';
  }

  @override
  Future<AnalysisOverlayTrack> getOverlayTrack(
    String accessToken,
    String resultId,
  ) async {
    return _overlayTrack();
  }

  @override
  Future<AnalysisEventReview> saveEventReview({
    required String accessToken,
    required String resultId,
    required List<PhaseOverride> phaseOverrides,
  }) async {
    savedOverrides = phaseOverrides;
    return AnalysisEventReview.fromJson({
      'id': 'review-1',
      'analysis_result_id': resultId,
      'phase_overrides': phaseOverrides
          .map((override) => override.toJson())
          .toList(),
      'effective_phases': [
        {'phase_code': 'P1', 'timestamp_ms': 0, 'source': 'detected'},
        {'phase_code': 'P4', 'timestamp_ms': 1000, 'source': 'reviewed'},
        {'phase_code': 'P7', 'timestamp_ms': 2000, 'source': 'detected'},
        {'phase_code': 'P10', 'timestamp_ms': 3000, 'source': 'detected'},
      ],
      'reviewed_metrics': {},
      'reviewed_report': _swingReportJson(source: 'reviewed'),
      'created_at': '2026-06-06T00:00:12Z',
      'updated_at': '2026-06-06T00:00:12Z',
    });
  }

  @override
  Future<void> resetEventReview({
    required String accessToken,
    required String resultId,
  }) async {
    resetReviewCalled = true;
  }

  @override
  Future<SwingReport> getSwingReport({
    required String accessToken,
    required String resultId,
  }) async {
    return SwingReport.fromJson(_swingReportJson());
  }

  @override
  Future<void> downloadSwingVideoFile({
    required String accessToken,
    required String videoId,
    required String destinationPath,
  }) async {}

  @override
  Future<void> deleteSwingVideo({
    required String accessToken,
    required String sessionId,
    required String videoId,
  }) async {
    deleteVideoCalled = true;
  }

  @override
  Future<List<FavoriteItem>> getFavorites(
    String accessToken, {
    String? folderId,
    String? entityType,
    String? entityId,
  }) async {
    return favorites
        .where((favorite) {
          if (folderId != null && favorite.folderId != folderId) return false;
          if (entityType != null && favorite.entityType != entityType) {
            return false;
          }
          if (entityId != null && favorite.entityId != entityId) return false;
          return true;
        })
        .toList(growable: false);
  }

  @override
  Future<FavoriteItem> saveFavorite(
    String accessToken, {
    required String entityType,
    required String entityId,
    String? folderId,
    String? note,
    Map<String, dynamic> metadata = const {},
    String? idempotencyKey,
  }) async {
    saveFavoriteCalls += 1;
    lastFavoriteIdempotencyKey = idempotencyKey;
    if (failFavoriteWrites) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/favorites'),
        type: DioExceptionType.connectionError,
      );
    }
    final favorite = FavoriteItem.fromJson({
      'id': 'favorite-$saveFavoriteCalls',
      'folder_id': folderId,
      'entity_type': entityType,
      'entity_id': entityId,
      'title': entityType.replaceAll('_', ' '),
      'body': 'Saved test favorite',
      'route': entityType == 'swing_report'
          ? '/swings/$entityId/report'
          : '/swings/$entityId',
      'note': note,
      'metadata': metadata,
    });
    favorites = [favorite];
    return favorite;
  }

  @override
  Future<void> deleteFavorite(
    String accessToken,
    String favoriteId, {
    String? idempotencyKey,
  }) async {
    deleteFavoriteCalls += 1;
    lastFavoriteIdempotencyKey = idempotencyKey;
    if (failFavoriteWrites) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/favorites/$favoriteId'),
        type: DioExceptionType.connectionError,
      );
    }
    favorites = favorites
        .where((favorite) => favorite.id != favoriteId)
        .toList(growable: false);
  }

  @override
  Future<RevenueCatCustomer> getRevenueCatCustomer(String accessToken) async {
    return RevenueCatCustomer.fromJson({
      'app_user_id': 'local-test-user',
      'entitlement_id': 'swinglens_pro',
      'is_entitled': false,
      'active_entitlements': <Map<String, dynamic>>[],
    });
  }

  @override
  Future<RevenueCatCustomer> syncRevenueCatCustomer(String accessToken) async {
    return RevenueCatCustomer.fromJson({
      'app_user_id': 'local-test-user',
      'entitlement_id': 'swinglens_pro',
      'is_entitled': true,
      'active_entitlements': [
        {
          'entitlement_id': 'swinglens_pro',
          'product_id': 'swinglens_pro_monthly',
          'is_active': true,
          'expires_at': '2026-07-06T00:00:00Z',
          'store': 'APP_STORE',
        },
      ],
    });
  }

  @override
  Future<PrivacyInventory> getPrivacyInventory(String accessToken) async {
    return PrivacyInventory.fromJson({
      'account': {'app_user_id': 'local-test-user'},
      'profile': {'stored': true},
      'uploads': {'count': 2},
      'swing_videos': {'count': 1},
      'analysis': {'results': 1, 'pose_frames': 24},
      'shot_tracer': {'results': 1, 'jobs': 1},
      'notifications': {'count': 1, 'unread': 1, 'preferences': true},
      'club_bag': {'count': 2},
      'favorites': {'count': 1, 'folders': 1},
      'rounds': {'count': 1, 'holes': 9},
      'entitlements': {'count': 0},
      'links': {
        'privacy_policy': 'https://example.com/privacy',
        'terms': 'https://example.com/terms',
      },
    });
  }

  @override
  Future<void> deleteAccount(String accessToken) async {
    deleteAccountCalled = true;
  }
}

class DashboardApiClient extends ApiClient {
  DashboardApiClient({
    this.emptyStats = false,
    this.longStats = false,
    this.homeDelay = Duration.zero,
    this.emptyFavorites = false,
    this.emptyClubBag = false,
    this.emptyNotifications = false,
    this.emptyActivity = false,
    this.failRoundHoleWrites = false,
    this.homeTrendDelta,
    this.includeTracerSessions = false,
  }) : super(baseUrl: 'http://localhost:8000');

  final bool emptyStats;
  final bool longStats;
  final Duration homeDelay;
  final bool emptyFavorites;
  final bool emptyClubBag;
  final bool emptyNotifications;
  final bool emptyActivity;
  final bool failRoundHoleWrites;
  final Object? homeTrendDelta;
  final bool includeTracerSessions;
  int homeDashboardCalls = 0;
  int performanceSnapshotCalls = 0;
  int faultStatsCalls = 0;
  int tracerStatsCalls = 0;
  int createClubCalls = 0;
  int updateClubCalls = 0;
  int deleteClubCalls = 0;
  int createFolderCalls = 0;
  int deleteFolderCalls = 0;
  int deleteFavoriteCalls = 0;
  int roundStatsCalls = 0;
  int createRoundCalls = 0;
  int updateRoundHoleCalls = 0;
  int completeRoundCalls = 0;
  int deleteRoundCalls = 0;
  String? lastRoundIdempotencyKey;
  int markNotificationReadCalls = 0;
  int markAllNotificationsReadCalls = 0;
  int deleteNotificationCalls = 0;
  int updateNotificationPreferenceCalls = 0;
  Map<String, dynamic> roundJson = _roundJson();
  List<NotificationItem> notifications = _notificationItems();
  NotificationPreferences notificationPreferences =
      const NotificationPreferences(
        analysisComplete: true,
        tracerReview: true,
        renderReady: true,
        uploadFailure: true,
        billing: true,
        roundReminders: true,
        system: true,
      );

  @override
  Future<HomeDashboard> getHomeDashboard(String accessToken) async {
    homeDashboardCalls += 1;
    if (homeDelay != Duration.zero) {
      await Future<void>.delayed(homeDelay);
    }
    return HomeDashboard.fromJson(
      _homeDashboardJson(heroTrendDelta: homeTrendDelta),
    );
  }

  @override
  Future<List<DashboardItem>> getActivity(String accessToken) async {
    if (emptyActivity) return const [];
    return [
      ...(_homeDashboardJson()['recent_activity'] as List<dynamic>).map(
        (item) => DashboardItem.fromJson(item as Map<String, dynamic>),
      ),
      DashboardItem.fromJson({
        'type': 'favorite_swing_session',
        'title': 'Favorite Session',
        'body': 'Saved for review',
        'status': 'SAVED',
        'route': '/swings/session-2',
        'created_at': '2026-06-06T00:04:00Z',
        'metadata': const {},
      }),
      for (final notification in notifications)
        DashboardItem(
          type: 'notification_${notification.type}',
          title: notification.title,
          body: notification.body,
          status: notification.isRead ? 'READ' : 'UNREAD',
          route: notification.route,
          createdAt: notification.createdAt,
          metadata: notification.metadata,
        ),
    ];
  }

  @override
  Future<List<NotificationItem>> getNotifications(
    String accessToken, {
    bool unreadOnly = false,
  }) async {
    if (emptyNotifications) return const [];
    return notifications
        .where((notification) => !unreadOnly || !notification.isRead)
        .toList(growable: false);
  }

  @override
  Future<int> getNotificationUnreadCount(String accessToken) async {
    if (emptyNotifications) return 0;
    return notifications.where((notification) => !notification.isRead).length;
  }

  @override
  Future<NotificationItem> markNotificationRead(
    String accessToken,
    String notificationId,
  ) async {
    markNotificationReadCalls += 1;
    final index = notifications.indexWhere(
      (notification) => notification.id == notificationId,
    );
    final updated = NotificationItem.fromJson({
      ..._notificationJson(
        id: notificationId,
        type: notifications[index].type,
        title: notifications[index].title,
        route: notifications[index].route,
        isRead: true,
      ),
      'body': notifications[index].body,
      'metadata': notifications[index].metadata,
      'read_at': '2026-06-06T00:05:00Z',
    });
    notifications = [
      for (var item in notifications)
        if (item.id == notificationId) updated else item,
    ];
    return updated;
  }

  @override
  Future<void> markAllNotificationsRead(String accessToken) async {
    markAllNotificationsReadCalls += 1;
    notifications = [
      for (final notification in notifications)
        NotificationItem.fromJson({
          ..._notificationJson(
            id: notification.id,
            type: notification.type,
            title: notification.title,
            route: notification.route,
            isRead: true,
          ),
          'body': notification.body,
          'metadata': notification.metadata,
          'read_at': '2026-06-06T00:05:00Z',
        }),
    ];
  }

  @override
  Future<void> deleteNotification(
    String accessToken,
    String notificationId,
  ) async {
    deleteNotificationCalls += 1;
    notifications = notifications
        .where((notification) => notification.id != notificationId)
        .toList(growable: false);
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences(
    String accessToken,
  ) async {
    return notificationPreferences;
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    String accessToken,
    NotificationPreferences preferences,
  ) async {
    updateNotificationPreferenceCalls += 1;
    notificationPreferences = preferences;
    return notificationPreferences;
  }

  @override
  Future<StatsDashboard> getStatsOverview(String accessToken) async {
    return StatsDashboard.fromJson(
      _statsDashboardJson(empty: emptyStats, longStats: longStats),
    );
  }

  @override
  Future<StatsDashboard> getSwingStats(String accessToken) async {
    return StatsDashboard.fromJson(
      _statsDashboardJson(
        title: 'Swing Stats',
        empty: emptyStats,
        longStats: longStats,
      ),
    );
  }

  @override
  Future<StatsDashboard> getTracerStats(String accessToken) async {
    tracerStatsCalls += 1;
    return StatsDashboard.fromJson(
      _statsDashboardJson(
        title: 'Shot Tracer Stats',
        empty: emptyStats,
        longStats: longStats,
      ),
    );
  }

  @override
  Future<StatsDashboard> getRoundStats(String accessToken) async {
    roundStatsCalls += 1;
    return StatsDashboard.fromJson(
      _statsDashboardJson(
        title: 'Round Stats',
        empty: emptyStats,
        longStats: longStats,
      ),
    );
  }

  @override
  Future<StatsDashboard> getClubStats(String accessToken) async {
    return StatsDashboard.fromJson(
      _statsDashboardJson(
        title: 'Club Performance',
        empty: emptyStats,
        longStats: longStats,
      ),
    );
  }

  @override
  Future<StatsDashboard> getFaultStats(String accessToken) async {
    faultStatsCalls += 1;
    return StatsDashboard.fromJson(
      _statsDashboardJson(
        title: 'Fault Trends',
        empty: emptyStats,
        longStats: longStats,
      ),
    );
  }

  @override
  Future<DashboardSection> getPerformanceSnapshot(String accessToken) async {
    performanceSnapshotCalls += 1;
    return DashboardSection.fromJson(
      _homeDashboardJson()['performance_snapshot'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<SwingSession>> getSwingSessions(String accessToken) async {
    return [
      SwingSession.fromJson({
        'id': 'session-1',
        'status': 'video_uploaded',
        'club': '7 iron',
        'session_type': 'analysis',
        'location_type': 'range',
        'created_at': '2026-06-06T00:00:00Z',
        'videos': const [],
      }),
      if (includeTracerSessions)
        SwingSession.fromJson({
          'id': 'tracer-session-1',
          'status': 'tracer_complete',
          'club': 'Driver',
          'session_type': 'tracer',
          'location_type': 'range',
          'created_at': '2026-06-06T00:00:00Z',
          'videos': const [
            {
              'id': 'tracer-video-1',
              'upload_id': 'tracer-upload-1',
              'storage_key': 'users/local/uploads/tracer-upload-1/tracer.mp4',
              'angle': 'rear_tracer',
              'duration_ms': 5200,
              'quality_score': 92,
              'quality_status': 'pass',
              'quality_checks': [],
            },
          ],
        }),
      if (includeTracerSessions)
        SwingSession.fromJson({
          'id': 'tracer-session-2',
          'status': 'needs_review',
          'club': '7 iron',
          'session_type': 'tracer',
          'location_type': 'range',
          'created_at': '2026-06-05T00:00:00Z',
          'videos': const [
            {
              'id': 'tracer-video-2',
              'upload_id': 'tracer-upload-2',
              'storage_key': 'users/local/uploads/tracer-upload-2/tracer.mp4',
              'angle': 'rear_tracer',
              'duration_ms': 4800,
              'quality_score': 62,
              'quality_status': 'warn',
              'quality_checks': [],
            },
          ],
        }),
    ];
  }

  @override
  Future<List<ClubBagItem>> getClubBag(
    String accessToken, {
    bool activeOnly = false,
  }) async {
    if (emptyClubBag) return const [];
    final clubs = [
      _clubBagJson(
        id: 'club-6i',
        label: '6 Iron',
        clubType: 'iron',
        active: true,
        order: 1,
        carry: 168,
        total: 176,
      ),
      _clubBagJson(
        id: 'club-driver',
        label: 'Driver',
        clubType: 'driver',
        active: true,
        order: 2,
        carry: 245,
        total: 268,
      ),
      _clubBagJson(
        id: 'club-old',
        label: 'Old Wedge',
        clubType: 'wedge',
        active: false,
        order: 99,
      ),
    ].map(ClubBagItem.fromJson).toList();
    if (!activeOnly) return clubs;
    return clubs.where((club) => club.isActive).toList(growable: false);
  }

  @override
  Future<ClubBagItem> createClubBagItem(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    createClubCalls += 1;
    return ClubBagItem.fromJson({
      'id': 'club-created',
      'label': payload['label'],
      'club_type': payload['club_type'] ?? 'club',
      'is_active': payload['is_active'] ?? true,
      'display_order': payload['display_order'] ?? 0,
      'carry_distance': payload['carry_distance'],
      'total_distance': payload['total_distance'],
      'distance_unit': payload['distance_unit'] ?? 'yards',
    });
  }

  @override
  Future<ClubBagItem> updateClubBagItem(
    String accessToken,
    String clubId,
    Map<String, dynamic> payload,
  ) async {
    updateClubCalls += 1;
    return ClubBagItem.fromJson({
      'id': clubId,
      'label': payload['label'] ?? 'Updated Club',
      'club_type': payload['club_type'] ?? 'iron',
      'is_active': payload['is_active'] ?? true,
      'display_order': payload['display_order'] ?? 0,
      'carry_distance': payload['carry_distance'],
      'total_distance': payload['total_distance'],
      'distance_unit': payload['distance_unit'] ?? 'yards',
    });
  }

  @override
  Future<void> deleteClubBagItem(String accessToken, String clubId) async {
    deleteClubCalls += 1;
  }

  @override
  Future<List<FavoriteFolder>> getFavoriteFolders(String accessToken) async {
    if (emptyFavorites) return const [];
    return [
      FavoriteFolder.fromJson({
        'id': 'folder-priority',
        'name': 'Priority Reviews',
        'display_order': 0,
      }),
    ];
  }

  @override
  Future<FavoriteFolder> createFavoriteFolder(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    createFolderCalls += 1;
    return FavoriteFolder.fromJson({
      'id': 'folder-created',
      'name': payload['name'] ?? 'New Folder',
      'display_order': payload['display_order'] ?? 0,
    });
  }

  @override
  Future<void> deleteFavoriteFolder(String accessToken, String folderId) async {
    deleteFolderCalls += 1;
  }

  @override
  Future<List<FavoriteItem>> getFavorites(
    String accessToken, {
    String? folderId,
    String? entityType,
    String? entityId,
  }) async {
    if (emptyFavorites) return const [];
    final favorites = [
      _favoriteJson(
        id: 'favorite-report',
        folderId: 'folder-priority',
        entityType: 'swing_report',
        entityId: 'session-1',
        title: '7 Iron Report',
        route: '/swings/session-1/report',
      ),
      _favoriteJson(
        id: 'favorite-session',
        entityType: 'swing_session',
        entityId: 'session-2',
        title: 'Driver Session',
        route: '/swings/session-2',
      ),
    ].map(FavoriteItem.fromJson).toList();
    return favorites
        .where((favorite) {
          if (folderId != null && favorite.folderId != folderId) return false;
          if (entityType != null && favorite.entityType != entityType) {
            return false;
          }
          if (entityId != null && favorite.entityId != entityId) return false;
          return true;
        })
        .toList(growable: false);
  }

  @override
  Future<void> deleteFavorite(
    String accessToken,
    String favoriteId, {
    String? idempotencyKey,
  }) async {
    deleteFavoriteCalls += 1;
  }

  @override
  Future<FavoriteItem> saveFavorite(
    String accessToken, {
    required String entityType,
    required String entityId,
    String? folderId,
    String? note,
    Map<String, dynamic> metadata = const {},
    String? idempotencyKey,
  }) async {
    return FavoriteItem.fromJson(
      _favoriteJson(
        id: 'favorite-$entityType-$entityId',
        entityType: entityType,
        entityId: entityId,
        title: 'Saved Round',
        route: '/rounds/$entityId',
        folderId: folderId,
      ),
    );
  }

  @override
  Future<List<GolfRound>> getRounds(String accessToken) async {
    if (emptyStats) return const [];
    return [GolfRound.fromJson(roundJson)];
  }

  @override
  Future<GolfRound> createRound(
    String accessToken,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    createRoundCalls += 1;
    roundJson = _roundJson(
      id: 'round-created',
      title: payload['title'] as String?,
      courseName: payload['course_name'] as String?,
      holesPlanned: payload['holes_planned'] as int? ?? 9,
    );
    return GolfRound.fromJson(roundJson);
  }

  @override
  Future<GolfRound> getRound(String accessToken, String roundId) async {
    return GolfRound.fromJson({...roundJson, 'id': roundId});
  }

  @override
  Future<GolfRound> updateRound(
    String accessToken,
    String roundId,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    roundJson = {...roundJson, ...payload, 'id': roundId};
    return GolfRound.fromJson(roundJson);
  }

  @override
  Future<GolfRound> updateRoundHole(
    String accessToken,
    String roundId,
    int holeNumber,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    updateRoundHoleCalls += 1;
    lastRoundIdempotencyKey = idempotencyKey;
    if (failRoundHoleWrites) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/v1/rounds/$roundId/holes/$holeNumber',
        ),
        type: DioExceptionType.connectionError,
      );
    }
    final holes = (roundJson['holes'] as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final index = holes.indexWhere((hole) => hole['hole_number'] == holeNumber);
    if (index >= 0) {
      holes[index] = {...holes[index], ...payload};
    }
    roundJson = {
      ...roundJson,
      'id': roundId,
      'holes': holes,
      'summary': _roundSummaryJson(holes, roundJson['holes_planned'] as int),
    };
    return GolfRound.fromJson(roundJson);
  }

  @override
  Future<GolfRound> completeRound(
    String accessToken,
    String roundId, {
    String? idempotencyKey,
  }) async {
    completeRoundCalls += 1;
    roundJson = {
      ...roundJson,
      'id': roundId,
      'status': 'completed',
      'completed_at': '2026-06-06T13:00:00Z',
    };
    return GolfRound.fromJson(roundJson);
  }

  @override
  Future<GolfRound> reopenRound(
    String accessToken,
    String roundId, {
    String? idempotencyKey,
  }) async {
    roundJson = {
      ...roundJson,
      'id': roundId,
      'status': 'in_progress',
      'completed_at': null,
    };
    return GolfRound.fromJson(roundJson);
  }

  @override
  Future<void> deleteRound(
    String accessToken,
    String roundId, {
    String? idempotencyKey,
  }) async {
    deleteRoundCalls += 1;
  }
}

Map<String, dynamic> _roundJson({
  String id = 'round-1',
  String? title = 'Front Nine Check',
  String? courseName = 'Municipal Front',
  int holesPlanned = 9,
}) {
  final holes = List<Map<String, dynamic>>.generate(holesPlanned, (index) {
    final holeNumber = index + 1;
    return {
      'id': 'hole-$holeNumber',
      'round_id': id,
      'hole_number': holeNumber,
      'par': 4,
      'strokes': holeNumber == 1 ? 5 : null,
      'putts': holeNumber == 1 ? 2 : null,
      'fairway_hit': holeNumber == 1 ? true : null,
      'green_in_regulation': holeNumber == 1 ? false : null,
      'penalties': 0,
      'notes': null,
      'created_at': '2026-06-06T12:00:00Z',
      'updated_at': '2026-06-06T12:00:00Z',
    };
  });
  return {
    'id': id,
    'user_id': 'local-test-user',
    'title': title,
    'course_name': courseName,
    'tee_name': 'White',
    'holes_planned': holesPlanned,
    'status': 'in_progress',
    'started_at': '2026-06-06T12:00:00Z',
    'completed_at': null,
    'notes': 'Widget test scorecard',
    'created_at': '2026-06-06T12:00:00Z',
    'updated_at': '2026-06-06T12:00:00Z',
    'holes': holes,
    'summary': _roundSummaryJson(holes, holesPlanned),
  };
}

Map<String, dynamic> _roundSummaryJson(
  List<Map<String, dynamic>> holes,
  int holesPlanned,
) {
  final completed = holes.where((hole) => hole['strokes'] != null).toList();
  final totalStrokes = completed.fold<int>(
    0,
    (total, hole) => total + (hole['strokes'] as int),
  );
  final totalPar = completed.isEmpty
      ? holes.fold<int>(0, (total, hole) => total + (hole['par'] as int))
      : completed.fold<int>(0, (total, hole) => total + (hole['par'] as int));
  final fairways = completed.where((hole) => hole['fairway_hit'] != null);
  final greens = completed.where((hole) => hole['green_in_regulation'] != null);
  return {
    'holes_completed': completed.length,
    'holes_planned': holesPlanned,
    'total_strokes': completed.isEmpty ? null : totalStrokes,
    'total_par': totalPar,
    'score_to_par': completed.isEmpty ? null : totalStrokes - totalPar,
    'total_putts': completed.isEmpty
        ? null
        : completed.fold<int>(
            0,
            (total, hole) => total + (hole['putts'] as int? ?? 0),
          ),
    'penalties': completed.fold<int>(
      0,
      (total, hole) => total + (hole['penalties'] as int),
    ),
    'fairways_hit': fairways
        .where((hole) => hole['fairway_hit'] == true)
        .length,
    'fairways_total': fairways.length,
    'greens_in_regulation': greens
        .where((hole) => hole['green_in_regulation'] == true)
        .length,
    'greens_total': greens.length,
  };
}

Map<String, dynamic> _clubBagJson({
  required String id,
  required String label,
  required String clubType,
  required bool active,
  required int order,
  int? carry,
  int? total,
}) {
  return {
    'id': id,
    'label': label,
    'club_type': clubType,
    'is_active': active,
    'display_order': order,
    'carry_distance': carry,
    'total_distance': total,
    'distance_unit': 'yards',
  };
}

Map<String, dynamic> _favoriteJson({
  required String id,
  required String entityType,
  required String entityId,
  required String title,
  required String route,
  String? folderId,
}) {
  return {
    'id': id,
    'folder_id': folderId,
    'entity_type': entityType,
    'entity_id': entityId,
    'title': title,
    'body': 'Saved for review',
    'route': route,
    'note': null,
    'metadata': const {},
  };
}

List<NotificationItem> _notificationItems() {
  return [
    NotificationItem.fromJson(
      _notificationJson(
        id: 'notification-analysis',
        type: 'analysis_complete',
        title: 'Swing Analysis Ready',
        body: '7 iron report is ready.',
        route: '/swings/session-1/report',
      ),
    ),
    NotificationItem.fromJson(
      _notificationJson(
        id: 'notification-tracer',
        type: 'tracer_needs_review',
        title: 'Tracer Needs Review',
        body: 'Driver tracer confidence is low.',
        route: '/tracer',
      ),
    ),
    NotificationItem.fromJson(
      _notificationJson(
        id: 'notification-round',
        type: 'round_completed',
        title: 'Round Completed',
        body: 'Front Nine Check is saved.',
        route: '/rounds/round-1',
        isRead: true,
      ),
    ),
  ];
}

Map<String, dynamic> _notificationJson({
  required String id,
  required String type,
  required String title,
  String? body,
  String? route,
  bool isRead = false,
}) {
  return {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'route': route,
    'metadata': const {},
    'is_read': isRead,
    'created_at': '2026-06-06T00:03:00Z',
    'read_at': isRead ? '2026-06-06T00:04:00Z' : null,
  };
}

Map<String, dynamic> _homeDashboardJson({Object? heroTrendDelta}) {
  final heroMetadata = <String, dynamic>{
    'score': 82,
    'main_focus': 'Early Extension',
  };
  if (heroTrendDelta != null) {
    heroMetadata['trend_delta'] = heroTrendDelta;
  }
  return {
    'user': {
      'id': 'local-test-user',
      'email': 'local-test@example.com',
      'first_name': 'Local Test',
      'skill_level': 'intermediate',
      'handedness': 'right',
    },
    'priority_item': {
      'type': 'analysis_ready',
      'title': 'Swing Analysis Ready',
      'body': 'Score 82 · Main focus: Early Extension',
      'status': 'ANALYSIS READY',
      'route': '/swings/session-1/report',
      'created_at': '2026-06-06T00:00:00Z',
      'metadata': {},
    },
    'hero': {
      'type': 'latest_swing',
      'title': 'Latest Swing',
      'body': 'Score 82 · Main focus: Early Extension',
      'status': 'ANALYSIS READY',
      'route': '/swings/session-1/report',
      'created_at': '2026-06-06T00:00:00Z',
      'metadata': heroMetadata,
    },
    'quick_actions': [
      {
        'id': 'record_swing',
        'title': 'Record Swing',
        'subtitle': 'AI analysis',
        'route': '/swing/record',
      },
      {
        'id': 'shot_tracer',
        'title': 'Shot Tracer',
        'subtitle': 'Track ball flight',
        'route': '/tracer/new',
      },
      {
        'id': 'play_round',
        'title': 'Play Round',
        'subtitle': 'Scorecard',
        'route': '/rounds',
      },
      {
        'id': 'stats',
        'title': 'Stats',
        'subtitle': 'Performance',
        'route': '/stats',
      },
    ],
    'performance_snapshot': {
      'title': 'Performance Snapshot',
      'body': 'Built from completed swing analyses and visual tracer results.',
      'route': '/performance-snapshot',
      'empty': false,
      'metrics': [
        {'label': 'Swing Score', 'value': '82', 'route': '/stats/swings'},
        {'label': 'Trace Confidence', 'value': '91%', 'route': '/stats/tracer'},
      ],
      'items': [],
    },
    'today_focus': {
      'type': 'swing_focus',
      'title': "Today's Focus",
      'body': 'Review early extension and record a follow-up swing.',
      'status': 'POSE BASED',
      'route': '/swings/session-1/report',
      'metadata': {},
    },
    'favorites_preview': [
      {
        'type': 'favorite',
        'title': '7 Iron Report',
        'body': 'Saved for review',
        'status': 'FAVORITE',
        'route': '/swings/session-1/report',
        'created_at': '2026-06-06T00:00:00Z',
        'metadata': const {},
      },
    ],
    'recent_activity': [
      {
        'type': 'swing_analysis',
        'title': 'Swing Report',
        'body': 'Score 82 · Main focus: Early Extension',
        'status': 'ANALYSIS',
        'route': '/swings/session-1/report',
        'created_at': '2026-06-06T00:00:00Z',
        'metadata': {},
      },
    ],
    'capabilities': {
      'home_dashboard': true,
      'swing_analysis': true,
      'shot_tracer': true,
      'rounds': true,
      'favorites': true,
      'notifications': true,
      'club_bag': true,
    },
  };
}

Map<String, dynamic> _statsDashboardJson({
  String title = 'Stats Overview',
  bool empty = false,
  bool longStats = false,
}) {
  final focusValue = longStats
      ? 'Early Extension / Loss Of Posture / Open Clubface Pattern'
      : 'Early Extension';
  return {
    'timeframe': 'all_time',
    'title': title,
    'body': empty
        ? 'Not enough data yet.'
        : 'Current stats use completed SwingLens data only.',
    'empty': empty,
    'metrics': empty
        ? const []
        : [
            {'label': 'Swing Score', 'value': '82', 'route': '/stats/swings'},
            {
              'label': longStats
                  ? 'Average Trace Confidence From Reviewed Renders'
                  : 'Trace Confidence',
              'value': '91%',
              'route': '/stats/tracer',
            },
            {
              'label': 'Main Focus',
              'value': focusValue,
              'delta': longStats
                  ? 'Seen across the latest completed pose reports'
                  : null,
              'route': '/stats/faults',
            },
          ],
    'sections': empty
        ? const []
        : [
            {
              'title': 'Swing Stats',
              'body': 'Pose-based analysis from completed swing reports.',
              'route': '/stats/swings',
              'empty': false,
              'metrics': [
                {'label': 'Analyzed Swings', 'value': '6'},
                {'label': 'Captured Sessions', 'value': '10'},
              ],
              'items': [
                {
                  'type': 'primary_focus',
                  'title': 'Most Common Focus',
                  'body': '$focusValue appears most often in recent reports.',
                  'status': 'POSE BASED',
                  'route': '/stats/faults',
                },
              ],
            },
            {
              'title': 'Shot Tracer Stats',
              'body':
                  'Visual-only path confidence. Not carry, speed, spin, or launch-monitor data.',
              'route': '/stats/tracer',
              'empty': false,
              'metrics': [
                {'label': 'Tracer Results', 'value': '4'},
                {'label': 'Recent Needs Review', 'value': '1'},
              ],
              'items': [
                {
                  'type': 'tracer_claim_limit',
                  'title': 'Tracer Claim Limit',
                  'body':
                      'These are visual path confidence and review signals only.',
                  'status': 'VISUAL ONLY',
                  'route': '/tracer',
                },
              ],
            },
          ],
    'capabilities': {'stats': true},
  };
}

AnalysisJob _analysisJob({
  required String status,
  required int progress,
  String? errorMessage,
}) {
  return AnalysisJob.fromJson({
    'id': 'analysis-job-1',
    'user_id': 'local-test-user',
    'session_id': 'session-1',
    'swing_video_id': 'video-1',
    'status': status,
    'progress': progress,
    'error_message': errorMessage,
    'rq_job_id': 'rq-test-id',
    'created_at': '2026-06-06T00:00:00Z',
    'started_at': status == 'pending' ? null : '2026-06-06T00:00:01Z',
    'completed_at': status == 'running' || status == 'pending'
        ? null
        : '2026-06-06T00:00:10Z',
  });
}

TracerJob _tracerJob({
  required String status,
  required int progress,
  required String jobType,
  String? errorMessage,
}) {
  return TracerJob.fromJson({
    'id': 'tracer-job-1',
    'user_id': 'local-test-user',
    'session_id': 'session-1',
    'swing_video_id': 'video-1',
    'job_type': jobType,
    'status': status,
    'progress': progress,
    'error_message': errorMessage,
    'rq_job_id': 'rq-tracer-id',
    'created_at': '2026-06-06T00:00:00Z',
    'started_at': status == 'pending' ? null : '2026-06-06T00:00:01Z',
    'completed_at': status == 'running' || status == 'pending'
        ? null
        : '2026-06-06T00:00:10Z',
  });
}

TracerResult _tracerResult({String status = 'available'}) {
  return TracerResult.fromJson({
    'id': 'tracer-result-1',
    'job_id': 'tracer-job-1',
    'session_id': 'session-1',
    'swing_video_id': 'video-1',
    'confidence': status == 'needs_review' ? 0.44 : 0.78,
    'status': status,
    'ball_path': [
      {'x': 0.5, 'y': 0.78, 'timestamp_ms': 0},
      {'x': 0.46, 'y': 0.48, 'timestamp_ms': 160},
      {'x': 0.40, 'y': 0.24, 'timestamp_ms': 320},
    ],
    'metrics': {
      'mode': 'visual_tracer_ball_tracking_mvp',
      'visual_only': true,
      'no_launch_monitor_metrics': true,
      'needs_better_capture': status == 'needs_review',
      'tracking': {
        'version': 'phase6_1_opencv_ball_tracker_v1',
        'detector_version': 'phase6_2_impact_stabilized_cv_v1',
        'path_source': status == 'needs_review'
            ? 'rejected_detected'
            : 'auto_detected',
        'auto_eligible': status != 'needs_review',
        'world_stabilized': true,
        'camera_motion_score': 0.92,
        'observed_point_count': 3,
        'interpolated_point_count': status == 'needs_review' ? 1 : 0,
        'gap_count': status == 'needs_review' ? 1 : 0,
        'impact_timestamp_ms': 0,
        'failure_reasons': status == 'needs_review'
            ? ['ball_not_confidently_tracked']
            : <String>[],
        if (status == 'needs_review')
          'capture_gate': {
            'version': 'phase6_6_guided_capture_gate_v1',
            'passed': false,
            'auto_eligible': false,
            'source': 'gallery',
            'checks': [
              {'code': 'camera_source', 'passed': false},
              {'code': 'capture_guide_active', 'passed': false},
              {'code': 'white_ball_confirmed', 'passed': false},
              {'code': 'phone_stable', 'passed': false},
              {'code': 'fps_ok', 'passed': false},
              {'code': 'resolution_ok', 'passed': false},
            ],
            'reject_reasons': [
              'capture_gate_failed_camera_source',
              'capture_gate_failed_capture_guide_active',
              'capture_gate_failed_white_ball_confirmed',
              'capture_gate_failed_phone_stable',
              'capture_gate_failed_fps_ok',
              'capture_gate_failed_resolution_ok',
            ],
          },
      },
      'flight': {
        'version': 'phase6_3_image_space_flight_metrics_v1',
        'measurement_space': 'normalized_image_2d',
        'not_launch_monitor': true,
        'path_source': status == 'needs_review'
            ? 'provisional_prior'
            : 'auto_detected',
        'status': status == 'needs_review' ? 'needs_review' : 'available',
        'summary': status == 'needs_review'
            ? 'Visual flight metrics are provisional because the ball track needs review.'
            : 'Visual tracer rises about 54% of the frame with a straight screen-relative flight.',
        'visual_launch_angle_degrees': 97.6,
        'start_direction_delta_degrees': -2.3,
        'peak_height_norm': 0.54,
        'curve_direction': 'straight',
        'curve_strength': 'straight',
      },
    },
    'has_render_video': status != 'needs_review',
    'has_thumbnail': status != 'needs_review',
    'render': {
      'available': status != 'needs_review',
      'reason': status == 'needs_review' ? 'needs_better_capture' : null,
      'format': status == 'needs_review' ? null : 'mp4',
      'path_point_count': 3,
      'path_source': status == 'needs_review'
          ? 'rejected_detected'
          : 'auto_detected',
      'visual_only': true,
      'not_launch_monitor': true,
    },
    'render_video_storage_key': 'users/local/tracer/tracer-job-1/render.mp4',
    'thumbnail_storage_key': 'users/local/tracer/tracer-job-1/thumbnail.jpg',
    'style': {'name': 'classic_white'},
    'created_at': '2026-06-06T00:00:11Z',
    'updated_at': '2026-06-06T00:00:11Z',
  });
}

AnalysisResult _analysisResult() {
  return AnalysisResult.fromJson({
    'id': 'analysis-result-1',
    'job_id': 'analysis-job-1',
    'session_id': 'session-1',
    'swing_video_id': 'video-1',
    'prototype_score': 72,
    'summary':
        'Prototype analysis sampled 24 frames and detected pose in 18 frames.',
    'report': {
      'confidence_label': 'prototype',
      'limitations': [
        'This is a pose and phase prototype, not a swing fault diagnosis.',
      ],
      'quality_warnings': ['Gallery videos may not use the capture guide.'],
      'diagnosis': {
        'version': 'phase4_mvp_v1',
        'status': 'available',
        'primary_fault': {
          'code': 'sway',
          'label': 'Sway',
          'confidence': 0.86,
          'evidence':
              'Hips shifted laterally 0.42 body-widths by the top of backswing.',
          'drill':
              'Make backswing rehearsals with an alignment stick just outside your trail hip.',
          'next_practice_goal':
              'Turn into the trail hip without letting the pelvis drift laterally in the backswing.',
        },
        'faults': [
          {'code': 'sway', 'label': 'Sway', 'confidence': 0.86},
          {
            'code': 'loss_of_posture',
            'label': 'Loss of posture',
            'confidence': 0.55,
          },
        ],
        'limitations': [
          'MVP diagnosis uses pose landmarks only and does not track the club or ball.',
        ],
        'visual_evidence': {
          'coordinate_space': 'normalized_image',
          'segments': [
            {
              'from': 'left_shoulder',
              'to': 'right_shoulder',
              'style': 'skeleton',
            },
            {'from': 'left_shoulder', 'to': 'left_elbow', 'style': 'skeleton'},
            {'from': 'left_elbow', 'to': 'left_wrist', 'style': 'skeleton'},
            {
              'from': 'right_shoulder',
              'to': 'right_elbow',
              'style': 'skeleton',
            },
            {'from': 'right_elbow', 'to': 'right_wrist', 'style': 'skeleton'},
            {'from': 'left_hip', 'to': 'right_hip', 'style': 'skeleton'},
          ],
          'phase_overlays': [
            {
              'phase_code': 'P1',
              'frame_index': 0,
              'timestamp_ms': 0,
              'points': {
                'left_shoulder': {'x': 0.42, 'y': 0.30, 'visibility': 0.9},
                'right_shoulder': {'x': 0.58, 'y': 0.30, 'visibility': 0.9},
                'left_elbow': {'x': 0.38, 'y': 0.43, 'visibility': 0.9},
                'right_elbow': {'x': 0.62, 'y': 0.43, 'visibility': 0.9},
                'left_wrist': {'x': 0.36, 'y': 0.55, 'visibility': 0.9},
                'right_wrist': {'x': 0.64, 'y': 0.55, 'visibility': 0.9},
                'left_hip': {'x': 0.44, 'y': 0.64, 'visibility': 0.9},
                'right_hip': {'x': 0.56, 'y': 0.64, 'visibility': 0.9},
                'mid_shoulder': {'x': 0.50, 'y': 0.30, 'visibility': 1.0},
                'mid_hip': {'x': 0.50, 'y': 0.64, 'visibility': 1.0},
              },
              'guide_lines': [
                {
                  'label': 'Spine angle',
                  'from': 'mid_hip',
                  'to': 'mid_shoulder',
                  'style': 'spine',
                },
                {
                  'label': 'Setup hip reference',
                  'x': 0.50,
                  'y1': 0.12,
                  'y2': 0.95,
                  'style': 'fault_reference',
                },
              ],
            },
          ],
        },
      },
      'next_capture_recommendation':
          'Use the guided camera view with full body and club visible.',
    },
    'phases': [
      {
        'phase_code': 'P1',
        'label': 'Setup',
        'frame_index': 0,
        'timestamp_ms': 0,
        'confidence': 0.7,
      },
    ],
    'metrics': {
      'sampled_frames': 24,
      'resolution_width': 1080,
      'resolution_height': 1920,
    },
    'pose_summary': {'pose_coverage': 0.75},
    'keyframes': [
      {
        'id': 'keyframe-1',
        'phase_code': 'P1',
        'frame_index': 0,
        'timestamp_ms': 0,
        'confidence': 0.7,
        'created_at': '2026-06-06T00:00:11Z',
      },
    ],
    'created_at': '2026-06-06T00:00:11Z',
  });
}

Map<String, dynamic> _swingReportJson({String source = 'detected'}) {
  return {
    'version': 'phase4_9_body_metrics_v1',
    'status': 'available',
    'source': source,
    'score': 78,
    'metric_cards': [
      {
        'code': 'tempo_ratio',
        'label': 'Tempo ratio',
        'value': 3.0,
        'unit': 'backswing/downswing',
        'status': 'pass',
        'summary': 'Backswing 3000 ms, downswing 1000 ms.',
        'evidence_timestamp_ms': 1000,
      },
      {
        'code': 'posture_delta',
        'label': 'Posture change',
        'value': 18.5,
        'unit': 'deg',
        'status': 'warn',
        'summary': 'Spine angle change from setup to impact.',
        'evidence_timestamp_ms': 2000,
      },
      {
        'code': 'finish_stability',
        'label': 'Finish stability',
        'value': 82,
        'unit': 'index',
        'status': 'pass',
        'summary': 'How still the body stays around the finish hold.',
        'evidence_timestamp_ms': 4000,
      },
      {
        'code': 'lead_elbow_angle',
        'label': 'Lead elbow angle',
        'value': 164.0,
        'unit': 'deg',
        'status': 'pass',
        'summary': 'Lead-arm structure at the top of backswing.',
        'evidence_timestamp_ms': 1000,
      },
      {
        'code': 'setup_stance_width',
        'label': 'Setup stance width',
        'value': 2.15,
        'unit': 'body widths',
        'status': 'pass',
        'summary': 'Ankle-to-ankle width relative to body width at setup.',
        'evidence_timestamp_ms': 0,
      },
      {
        'code': 'foot_flare_symmetry',
        'label': 'Foot flare symmetry',
        'value': 8.0,
        'unit': 'deg',
        'status': 'pass',
        'summary':
            'Difference between left and right foot-line flare at setup.',
        'evidence_timestamp_ms': 0,
      },
      {
        'code': 'impact_extension',
        'label': 'Impact extension',
        'value': 1.24,
        'unit': 'body widths',
        'status': 'pass',
        'summary': 'Average shoulder-to-wrist radius through impact.',
        'evidence_timestamp_ms': 2000,
      },
    ],
    'findings': [
      {
        'code': 'posture_delta',
        'label': 'Posture changed through impact',
        'severity': 'warn',
        'confidence': 0.58,
        'what_happened': 'Your spine angle moved from setup to impact.',
        'why_it_matters': 'Changing posture can make contact less predictable.',
        'evidence_timestamp_ms': 2000,
        'drill': 'Make slow half-swings keeping chest angle over the ball.',
        'next_goal': 'Keep setup and impact posture within 12 degrees.',
      },
    ],
    'limitations': ['Pose-based guidance only.'],
  };
}

AnalysisOverlayTrack _overlayTrack({bool reviewed = false}) {
  return AnalysisOverlayTrack.fromJson({
    'result_id': 'analysis-result-1',
    'swing_video_id': 'video-1',
    'duration_ms': 4200,
    'resolution_width': 1080,
    'resolution_height': 1920,
    'coordinate_space': 'normalized_image',
    'landmark_schema': 'mediapipe_pose_33',
    'segments': [
      {'from': 'left_shoulder', 'to': 'right_shoulder', 'style': 'skeleton'},
      {'from': 'left_shoulder', 'to': 'left_elbow', 'style': 'skeleton'},
      {'from': 'left_elbow', 'to': 'left_wrist', 'style': 'skeleton'},
      {'from': 'left_hip', 'to': 'right_hip', 'style': 'skeleton'},
    ],
    'frames': [
      {
        'frame_index': 0,
        'timestamp_ms': 0,
        'pose_detected': true,
        'average_visibility': 0.9,
        'points': {
          'left_shoulder': {'x': 0.42, 'y': 0.30, 'visibility': 0.9},
          'right_shoulder': {'x': 0.58, 'y': 0.30, 'visibility': 0.9},
          'left_elbow': {'x': 0.38, 'y': 0.43, 'visibility': 0.9},
          'left_wrist': {'x': 0.36, 'y': 0.55, 'visibility': 0.9},
          'left_hip': {'x': 0.44, 'y': 0.64, 'visibility': 0.9},
          'right_hip': {'x': 0.56, 'y': 0.64, 'visibility': 0.9},
          'mid_shoulder': {'x': 0.50, 'y': 0.30, 'visibility': 1.0},
          'mid_hip': {'x': 0.50, 'y': 0.64, 'visibility': 1.0},
        },
        'guide_lines': [
          {
            'label': 'Spine angle',
            'from': 'mid_hip',
            'to': 'mid_shoulder',
            'style': 'spine',
          },
          {
            'label': 'Setup hip reference',
            'x': 0.50,
            'y1': 0.12,
            'y2': 0.95,
            'style': 'fault_reference',
          },
        ],
        'metrics': {
          'spine_angle_degrees': 1.2,
          'hip_center_x': 0.50,
          'lead_elbow_angle_degrees': 164.0,
          'stance_width_body_widths': 2.15,
          'arm_extension_body_widths': 1.24,
          'body_plane_tilt_degrees': 12.0,
          'hand_plane_proxy_degrees': 34.0,
        },
      },
      {
        'frame_index': 20,
        'timestamp_ms': 2000,
        'pose_detected': true,
        'average_visibility': 0.86,
        'points': {
          'left_shoulder': {'x': 0.50, 'y': 0.31, 'visibility': 0.9},
          'right_shoulder': {'x': 0.66, 'y': 0.31, 'visibility': 0.9},
          'left_elbow': {'x': 0.47, 'y': 0.43, 'visibility': 0.9},
          'left_wrist': {'x': 0.45, 'y': 0.55, 'visibility': 0.9},
          'left_hip': {'x': 0.52, 'y': 0.64, 'visibility': 0.9},
          'right_hip': {'x': 0.64, 'y': 0.64, 'visibility': 0.9},
          'mid_shoulder': {'x': 0.58, 'y': 0.31, 'visibility': 1.0},
          'mid_hip': {'x': 0.58, 'y': 0.64, 'visibility': 1.0},
        },
        'guide_lines': [
          {
            'label': 'Spine angle',
            'from': 'mid_hip',
            'to': 'mid_shoulder',
            'style': 'spine',
          },
          {
            'label': 'Setup hip reference',
            'x': 0.50,
            'y1': 0.12,
            'y2': 0.95,
            'style': 'fault_reference',
          },
        ],
        'metrics': {'spine_angle_degrees': 9.4, 'hip_center_x': 0.58},
      },
    ],
    'checkpoints': [
      {
        'phase_code': 'P1',
        'label': 'Setup',
        'timestamp_ms': 0,
        'frame_index': 0,
        'confidence': 0.9,
        'detection_method': 'pose_motion_heuristic',
        'detection_status': 'detected',
      },
      {
        'phase_code': reviewed ? 'P4' : 'P7',
        'label': reviewed ? 'Top' : 'Impact',
        'timestamp_ms': reviewed ? 1000 : 2000,
        'frame_index': reviewed ? 10 : 20,
        'confidence': reviewed ? 1.0 : 0.8,
        'detection_method': 'pose_motion_heuristic',
        'detection_status': reviewed ? 'reviewed' : 'detected',
        'source': reviewed ? 'reviewed' : 'detected',
      },
    ],
    'fault_checkpoints': [
      {
        'code': 'sway',
        'label': 'Sway',
        'timestamp_ms': 2000,
        'frame_index': 20,
        'phase_code': 'P7',
        'confidence': 0.86,
        'evidence':
            'Hips shifted laterally 0.42 body-widths by the top of backswing.',
        'drill':
            'Make backswing rehearsals with an alignment stick just outside your trail hip.',
        'next_goal':
            'Turn into the trail hip without letting the pelvis drift laterally in the backswing.',
        'is_primary': true,
      },
    ],
  });
}

class UploadQueueApiClient extends ApiClient {
  UploadQueueApiClient() : super(baseUrl: 'http://localhost:8000');

  int uploadSwingVideoCalls = 0;
  String? lastIdempotencyKey;
  String? lastFileName;
  String? lastClub;
  UploadCaptureMetadata? lastCaptureMetadata;

  @override
  Future<SwingSession> uploadSwingVideo({
    required String accessToken,
    required XFile file,
    required String club,
    required String angle,
    required String locationType,
    required UploadCaptureMetadata captureMetadata,
    String sessionType = 'analysis',
    int? durationMs,
    int? resolutionWidth,
    int? resolutionHeight,
    String? idempotencyKey,
  }) async {
    uploadSwingVideoCalls += 1;
    lastIdempotencyKey = idempotencyKey;
    lastFileName = file.name;
    lastClub = club;
    lastCaptureMetadata = captureMetadata;
    return SwingSession.fromJson({
      'id': 'queued-session',
      'status': 'video_uploaded',
      'club': club,
      'session_type': sessionType,
      'location_type': locationType,
      'created_at': '2026-06-06T00:00:00Z',
      'videos': const [],
    });
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('tracer result render metadata overrides legacy private keys', () {
    final rejected = _tracerResult(status: 'needs_review');
    final available = _tracerResult();

    expect(rejected.hasRender, isFalse);
    expect(rejected.hasThumbnail, isFalse);
    expect(rejected.render['available'], isFalse);
    expect(available.hasRender, isTrue);
    expect(available.hasThumbnail, isTrue);
    expect(available.render['available'], isTrue);
  });

  test('native capture capabilities classify high fps iPhone path', () {
    final capabilities = NativeCaptureCapabilities.fromJson({
      'nativeCaptureAvailable': true,
      'highFpsCaptureAvailable': true,
      'trustedAutoCaptureAvailable': true,
      'diagnosticOnly': false,
      'deviceTier': 'A',
      'deviceModel': 'iPhone17,2',
      'systemVersion': '18.0',
      'preferredMode': '1080p240',
      'selectedFormat': {'targetFps': 240, 'label': '1080p240'},
      'supportedFormats': [
        {'targetFps': 240, 'label': '1080p240'},
      ],
    });

    expect(capabilities.trustedForTracer, isTrue);
    expect(capabilities.readinessLabel, 'HIGH FPS READY');
    expect(capabilities.selectedFormat['targetFps'], 240);
  });

  test('native capture capabilities keep low fps path diagnostic only', () {
    final capabilities = NativeCaptureCapabilities.fromJson({
      'nativeCaptureAvailable': true,
      'highFpsCaptureAvailable': false,
      'trustedAutoCaptureAvailable': false,
      'diagnosticOnly': true,
      'deviceTier': 'D',
      'preferredMode': '4K60',
    });

    expect(capabilities.trustedForTracer, isFalse);
    expect(capabilities.readinessLabel, 'DIAGNOSTIC ONLY');
  });

  test('home dashboard model parses backend contract', () {
    final dashboard = HomeDashboard.fromJson(_homeDashboardJson());

    expect(dashboard.hero.title, 'Latest Swing');
    expect(
      dashboard.quickActions.map((action) => action.id),
      contains('record_swing'),
    );
    expect(dashboard.performanceSnapshot.metrics.first.value, '82');
  });

  test('offline queue retries favorite writes with request id', () async {
    final queue = OfflineQueueStore(
      persistence: MemoryOfflineQueuePersistence(),
    );
    await queue.load();
    final item = await queue.enqueue(
      action: 'favorite.save',
      title: 'Save session queued',
      payload: {
        'entity_type': 'swing_session',
        'entity_id': 'session-1',
        'metadata': <String, dynamic>{},
      },
    );
    final api = SwingDetailApiClient();

    await queue.retryAll(accessToken: 'local-access-token', apiClient: api);

    expect(api.saveFavoriteCalls, 1);
    expect(api.lastFavoriteIdempotencyKey, item.id);
    expect(queue.pendingCount, 0);
  });

  test(
    'offline queue retries retained swing uploads with request id',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'swinglens-upload-queue-test-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final retainedFile = File('${directory.path}/queued.mov');
      await retainedFile.writeAsBytes([0, 1, 2, 3, 4, 5]);
      final queue = OfflineQueueStore(
        persistence: MemoryOfflineQueuePersistence(),
      );
      await queue.load();
      final item = await queue.enqueue(
        action: 'upload.swing_video',
        title: 'Video upload queued',
        payload: {
          'local_file_path': retainedFile.path,
          'file_name': 'queued.mov',
          'club': '7 iron',
          'angle': 'down_the_line',
          'location_type': 'range',
          'session_type': 'analysis',
          'duration_ms': 4200,
          'resolution_width': 1920,
          'resolution_height': 1080,
          'capture_metadata': const UploadCaptureMetadata(
            source: 'gallery',
            guideOverlay: false,
            platform: 'ios',
            fileExtension: '.mov',
          ).toJson(),
        },
      );
      final api = UploadQueueApiClient();

      await queue.retryAll(accessToken: 'local-access-token', apiClient: api);

      expect(api.uploadSwingVideoCalls, 1);
      expect(api.lastIdempotencyKey, item.id);
      expect(api.lastFileName, 'queued.mov');
      expect(api.lastClub, '7 iron');
      expect(api.lastCaptureMetadata?.fileExtension, '.mov');
      expect(queue.pendingCount, 0);
      expect(await retainedFile.exists(), isFalse);
    },
  );

  test(
    'offline queue keeps missing retained uploads as failed items',
    () async {
      final queue = OfflineQueueStore(
        persistence: MemoryOfflineQueuePersistence(),
      );
      await queue.load();
      await queue.enqueue(
        action: 'upload.swing_video',
        title: 'Video upload queued',
        payload: {
          'local_file_path': '/tmp/swinglens-missing-queued-upload.mov',
          'file_name': 'queued.mov',
          'club': '7 iron',
          'angle': 'down_the_line',
          'location_type': 'range',
          'session_type': 'analysis',
          'capture_metadata': const UploadCaptureMetadata(
            source: 'gallery',
            guideOverlay: false,
          ).toJson(),
        },
      );
      final api = UploadQueueApiClient();

      await queue.retryAll(accessToken: 'local-access-token', apiClient: api);

      expect(api.uploadSwingVideoCalls, 0);
      expect(queue.pendingCount, 1);
      expect(
        queue.items.single.lastError,
        contains('Queued upload file is missing'),
      );
      expect(
        queue.statusFor(queue.items.single),
        OfflineQueueItemStatus.failed,
      );
    },
  );

  test('offline queue clear failed keeps pending work', () async {
    final persistence = MemoryOfflineQueuePersistence();
    final failed = OfflineQueueItem(
      id: 'failed-item',
      action: 'upload.swing_video',
      title: 'Failed upload',
      payload: const <String, dynamic>{},
      createdAt: DateTime.utc(2026, 6, 12),
      lastError: 'Queued upload file is missing',
    );
    final pending = OfflineQueueItem(
      id: 'pending-item',
      action: 'favorite.save',
      title: 'Pending favorite',
      payload: const <String, dynamic>{
        'entity_type': 'swing_session',
        'entity_id': 'session-1',
        'metadata': <String, dynamic>{},
      },
      createdAt: DateTime.utc(2026, 6, 12),
    );
    await persistence.write([failed, pending]);
    final queue = OfflineQueueStore(persistence: persistence);
    await queue.load();

    await queue.clearFailed();

    expect(queue.pendingCount, 1);
    expect(queue.failedCount, 0);
    expect(queue.items.single.id, 'pending-item');
  });

  Future<void> pumpSwingLensApp(
    WidgetTester tester, {
    AuthController? auth,
    ApiClient? apiClient,
    OfflineQueueStore? offlineQueue,
  }) async {
    final controller =
        auth ?? AuthController(ApiClient(baseUrl: 'http://localhost:8000'));
    controller.state = auth?.state ?? const AuthState();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => controller),
          if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
          if (offlineQueue != null)
            offlineQueueProvider.overrideWith((ref) => offlineQueue),
        ],
        child: const SwingLensApp(),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpStandalone(
    WidgetTester tester, {
    required Widget child,
    required AuthController auth,
    ApiClient? apiClient,
    OfflineQueueStore? offlineQueue,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
          if (offlineQueue != null)
            offlineQueueProvider.overrideWith((ref) => offlineQueue),
        ],
        child: MaterialApp(theme: buildSwingLensTheme(), home: child),
      ),
    );
    await tester.pump();
  }

  void setPhoneViewportWithKeyboard(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
    });
  }

  testWidgets('sync center shows queued offline work', (
    WidgetTester tester,
  ) async {
    final queue = OfflineQueueStore(
      persistence: MemoryOfflineQueuePersistence(),
    );
    await queue.load();
    await queue.enqueue(
      action: 'favorite.save',
      title: 'Save session queued',
      payload: {
        'entity_type': 'swing_session',
        'entity_id': 'session-1',
        'metadata': <String, dynamic>{},
      },
    );

    await pumpStandalone(
      tester,
      child: const SyncCenterScreen(),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(),
      offlineQueue: queue,
    );

    expect(find.text('SYNC CENTER'), findsOneWidget);
    expect(find.text('1 PENDING'), findsOneWidget);
    expect(find.text('SAVE SESSION QUEUED'), findsOneWidget);
    expect(find.textContaining('SAVE FAVORITE'), findsOneWidget);
    expect(find.textContaining('PENDING'), findsWidgets);
    expect(
      find.byKey(const ValueKey('sync-center-retry-all-button')),
      findsOneWidget,
    );
  });

  testWidgets('sync center clears failed items without removing pending work', (
    WidgetTester tester,
  ) async {
    final persistence = MemoryOfflineQueuePersistence();
    await persistence.write([
      OfflineQueueItem(
        id: 'failed-sync-item',
        action: 'upload.swing_video',
        title: 'Failed upload',
        payload: const <String, dynamic>{},
        createdAt: DateTime.utc(2026, 6, 12),
        lastError: 'Queued upload file is missing',
      ),
      OfflineQueueItem(
        id: 'pending-sync-item',
        action: 'favorite.save',
        title: 'Pending favorite',
        payload: const <String, dynamic>{
          'entity_type': 'swing_session',
          'entity_id': 'session-1',
          'metadata': <String, dynamic>{},
        },
        createdAt: DateTime.utc(2026, 6, 12),
      ),
    ]);
    final queue = OfflineQueueStore(persistence: persistence);
    await queue.load();

    await pumpStandalone(
      tester,
      child: const SyncCenterScreen(),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(),
      offlineQueue: queue,
    );

    expect(find.text('FAILED UPLOAD'), findsOneWidget);
    expect(queue.pendingCount, 2);
    expect(queue.failedCount, 1);
    expect(find.textContaining('1 failed item'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('sync-center-clear-failed-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('FAILED UPLOAD'), findsNothing);
    expect(find.text('PENDING FAVORITE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sync-center-clear-failed-button')),
      findsNothing,
    );
    expect(queue.pendingCount, 1);
    expect(queue.failedCount, 0);
  });

  testWidgets('offline sync coordinator retries queued work on mount', (
    WidgetTester tester,
  ) async {
    final queue = OfflineQueueStore(
      persistence: MemoryOfflineQueuePersistence(),
    );
    await queue.load();
    final item = await queue.enqueue(
      action: 'favorite.save',
      title: 'Save session queued',
      payload: {
        'entity_type': 'swing_session',
        'entity_id': 'session-1',
        'metadata': <String, dynamic>{},
      },
    );
    final api = SwingDetailApiClient();

    await pumpStandalone(
      tester,
      child: const OfflineSyncCoordinator(
        minRetryInterval: Duration.zero,
        child: SizedBox.shrink(),
      ),
      auth: ReadyTestAuthController(),
      apiClient: api,
      offlineQueue: queue,
    );
    await tester.pumpAndSettle();

    expect(api.saveFavoriteCalls, 1);
    expect(api.lastFavoriteIdempotencyKey, item.id);
    expect(queue.pendingCount, 0);
  });

  testWidgets('shows SwingLens welcome entrypoint', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(tester);

    expect(find.text('SWINGLENS AI'), findsWidgets);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('debug sign in exposes and fills the local test account', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(tester);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('USE LOCAL TEST ACCOUNT'));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller?.text, contains('swinglens.phase6.tracer'));
    expect(fields.last.controller?.text, 'LocalSwing!2026-06-07#06');
  });

  testWidgets('sign up form stays usable when the keyboard is visible', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(tester);
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    setPhoneViewportWithKeyboard(tester);
    await tester.enterText(find.byType(TextField).first, 'golfer@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('START YOUR ANALYSIS'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  testWidgets('sign in form stays usable when the keyboard is visible', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(tester);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    setPhoneViewportWithKeyboard(tester);
    await tester.enterText(find.byType(TextField).first, 'golfer@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('MEMBER ACCESS'), findsOneWidget);
    expect(find.text('SIGN IN'), findsWidgets);
  });

  testWidgets(
    'profile onboarding advances without returning to the first screen',
    (WidgetTester tester) async {
      final auth = OnboardingTestAuthController();
      await pumpSwingLensApp(tester, auth: auth);
      await tester.pumpAndSettle();

      expect(find.text('SET YOUR BASELINE'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'CONTINUE'));
      await tester.tap(find.widgetWithText(FilledButton, 'CONTINUE'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(auth.updateProfileCalls, 1);
      expect(find.text('MATCH YOUR SETUP'), findsOneWidget);
      expect(find.text('SET YOUR BASELINE'), findsNothing);
    },
  );

  testWidgets('home dashboard renders API data and stable action keys', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(homeTrendDelta: '+8%'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Local.'), findsOneWidget);
    expect(find.text('LAST GAME'), findsOneWidget);
    expect(find.text('Last Round'), findsOneWidget);
    expect(find.text('PERFORMANCE LAB'), findsOneWidget);
    expect(find.text('POSE BASED'), findsNothing);
    expect(find.text('NOT ENOUGH'), findsNothing);
    expect(find.text('Rounds v2'), findsNothing);
    expect(find.text('Open stats'), findsNothing);
    expect(
      find.byKey(const ValueKey('home-last-game-course-image')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home-hero-card'))).height,
      greaterThanOrEqualTo(190),
    );
    expect(find.byKey(const ValueKey('home-weather-pill')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-center-golfer-asset')),
      findsOneWidget,
    );
    expect(find.text('82%'), findsWidgets);
    expect(find.text('Trend'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-action-record_swing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-action-shot_tracer')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bottom-nav-bar')), findsOneWidget);
  });

  testWidgets('home quick actions preserve capture route aliases', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(),
    );
    await tester.pumpAndSettle();

    final recordAction = find.byKey(const ValueKey('home-action-record_swing'));
    await tester.ensureVisible(recordAction);
    await tester.pumpAndSettle();
    await tester.tap(recordAction);
    await tester.pumpAndSettle();

    expect(find.text('GUIDED CAPTURE'), findsOneWidget);
  });

  testWidgets('shot tracer hub renders camera-first intro and visual recents', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const TracerHubScreen(),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(includeTracerSessions: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('SHOT TRACER'), findsOneWidget);
    expect(
      find.text(
        'Capture rear-angle ball flight.\nTracer metrics are visual-only.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('shot-tracer-hero-image')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tracer-guide-overlay')), findsOneWidget);
    expect(find.text('START TRACER CAMERA'), findsOneWidget);
    expect(find.text('IMPORT VIDEO'), findsOneWidget);
    expect(find.text('RECENT TRACERS'), findsOneWidget);
    expect(find.text('Auto Tracked'), findsOneWidget);
    expect(find.text('Needs Review'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.textContaining('TRACER_COMPLETE'), findsNothing);
    expect(find.textContaining('QUALITY PASS'), findsNothing);
  });

  testWidgets('rounds tab renders saved scorecards and opens detail', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rounds'));
    await tester.pumpAndSettle();

    expect(find.text('ROUNDS'), findsOneWidget);
    expect(find.text('FRONT NINE CHECK'), findsOneWidget);
    expect(find.textContaining('MUNICIPAL FRONT'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('round-row-round-1')));
    await tester.pumpAndSettle();

    expect(find.text('FRONT NINE CHECK'), findsWidgets);
    expect(find.text('SAVE ROUND'), findsOneWidget);
    expect(find.text('COMPLETE ROUND'), findsOneWidget);
  });

  testWidgets('round start form creates a scorecard', (
    WidgetTester tester,
  ) async {
    final api = DashboardApiClient();
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rounds-start-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Range Nine',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Course'),
      'Widget Links',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('round-start-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('round-start-submit-button')));
    await tester.pumpAndSettle();

    expect(api.createRoundCalls, 1);
    expect(find.text('RANGE NINE'), findsOneWidget);
    expect(find.text('SAVE ROUND'), findsOneWidget);
  });

  testWidgets('round detail edits holes and exposes lifecycle actions', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final api = DashboardApiClient();
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('round-row-round-1')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('round-hole-2')),
      320,
    );
    await tester.tap(find.byKey(const ValueKey('round-hole-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Strokes'), '4');
    await tester.enterText(find.widgetWithText(TextField, 'Putts'), '2');
    await tester.tap(find.widgetWithText(FilledButton, 'SAVE'));
    await tester.pumpAndSettle();

    expect(api.updateRoundHoleCalls, 1);

    await tester.ensureVisible(
      find.byKey(const ValueKey('round-complete-button')),
    );
    await tester.tap(find.byKey(const ValueKey('round-complete-button')));
    await tester.pumpAndSettle();
    expect(api.completeRoundCalls, 1);

    await tester.ensureVisible(find.text('DELETE ROUND'));
    await tester.tap(find.text('DELETE ROUND'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'DELETE'));
    await tester.pumpAndSettle();

    expect(api.deleteRoundCalls, 1);
    expect(find.text('ROUNDS'), findsOneWidget);
  });

  testWidgets('round hole save queues when the network is unavailable', (
    WidgetTester tester,
  ) async {
    final queue = OfflineQueueStore(
      persistence: MemoryOfflineQueuePersistence(),
    );
    await queue.load();
    final api = DashboardApiClient(failRoundHoleWrites: true);
    await pumpStandalone(
      tester,
      child: const RoundDetailScreen(roundId: 'round-1'),
      auth: ReadyTestAuthController(),
      apiClient: api,
      offlineQueue: queue,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('round-hole-1')),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('round-hole-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'SAVE'));
    await tester.pumpAndSettle();

    expect(api.updateRoundHoleCalls, 1);
    expect(queue.pendingCount, 1);
    expect(queue.items.single.action, 'round.hole.update');
    await tester.scrollUntilVisible(
      find.text('1 PENDING SYNC'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('1 PENDING SYNC'), findsOneWidget);
  });

  testWidgets('home pull to refresh refetches dashboard data', (
    WidgetTester tester,
  ) async {
    final api = DashboardApiClient();
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pumpAndSettle();

    expect(api.homeDashboardCalls, 1);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 360),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(api.homeDashboardCalls, 2);
  });

  testWidgets('dashboard loading state does not show fallback actions', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(
        homeDelay: const Duration(milliseconds: 500),
      ),
    );
    await tester.pump();

    expect(find.text('SYNCING'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-action-record_swing')),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('home header shortcuts open notifications and profile', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-notifications-button')));
    await tester.pumpAndSettle();
    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('2 UNREAD'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-profile-button')));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets('notifications list supports read state and preferences', (
    WidgetTester tester,
  ) async {
    final api = DashboardApiClient();
    await pumpStandalone(
      tester,
      child: const NotificationsScreen(),
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('2 UNREAD'), findsOneWidget);
    expect(find.text('SWING ANALYSIS READY'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark read').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(api.markNotificationReadCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey('notifications-read-all-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(api.markAllNotificationsReadCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey('notifications-preferences-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ANALYSIS COMPLETE'), findsWidgets);
    await tester.tap(find.text('ANALYSIS COMPLETE').last);
    await tester.tap(find.text('SAVE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(api.updateNotificationPreferenceCalls, 1);
    expect(api.notificationPreferences.analysisComplete, isFalse);
  });

  testWidgets('notifications empty unread state remains refreshable', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const NotificationsScreen(),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(emptyNotifications: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('NO NOTIFICATIONS'), findsOneWidget);
    await tester.tap(find.text('UNREAD'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('NO UNREAD NOTIFICATIONS'), findsOneWidget);
  });

  testWidgets('notification route opens nested round detail', (
    WidgetTester tester,
  ) async {
    final api = DashboardApiClient();
    expect(
      api.notifications
          .firstWhere((notification) => notification.id == 'notification-round')
          .route,
      '/rounds/round-1',
    );
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-notifications-button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notification-tile-notification-round')),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -160));
    await tester.pumpAndSettle();
    final tile = find.byKey(
      const ValueKey('notification-tile-notification-round'),
    );
    final topLeft = tester.getTopLeft(tile);
    await tester.tapAt(topLeft + const Offset(24, 24));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('round-detail-round-1')), findsOneWidget);
    expect(find.text('FRONT NINE CHECK'), findsOneWidget);
  });

  testWidgets('activity screen renders normalized feed items', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const ActivityScreen(),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('ACTIVITY'), findsOneWidget);
    expect(find.text('FAVORITE SESSION'), findsOneWidget);
    expect(find.text('SWING ANALYSIS READY'), findsOneWidget);
  });

  testWidgets('activity screen renders an empty feed state', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const ActivityScreen(),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(emptyActivity: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('NO ACTIVITY YET'), findsOneWidget);
  });

  testWidgets('profile hub exposes Phase 4 panels', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('GOLF PROFILE'), findsOneWidget);
    expect(find.text('CLUB BAG'), findsOneWidget);
    expect(find.text('FAVORITES'), findsOneWidget);
    expect(find.textContaining('UNITS: IMPERIAL'), findsOneWidget);
  });

  testWidgets('profile preferences save Phase 4 fields', (
    WidgetTester tester,
  ) async {
    final auth = OnboardingTestAuthController();
    auth.state = const AuthState(
      user: UserProfile(id: 'local-test-user', email: 'local-test@example.com'),
      profile: GolferProfile(
        userId: 'local-test-user',
        handedness: 'right',
        skillLevel: 'intermediate',
        goals: ['clean_contact'],
      ),
      accessToken: 'local-access-token',
      refreshToken: 'local-refresh-token',
      hasVideoConsent: true,
    );
    await pumpStandalone(
      tester,
      child: const ProfilePreferencesScreen(),
      auth: auth,
      apiClient: DashboardApiClient(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('METRIC'));
    await tester.pump();
    await tester.tap(find.text('TRACER'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-preferences-save')),
    );
    await tester.tap(find.byKey(const ValueKey('profile-preferences-save')));
    await tester.pumpAndSettle();

    expect(auth.updateProfileCalls, 1);
    expect(auth.state.profile?.unitsSystem, 'metric');
    expect(auth.state.profile?.distanceUnit, 'meters');
    expect(auth.state.profile?.defaultCaptureMode, 'tracer');
  });

  testWidgets('club bag screen renders list and delete action', (
    WidgetTester tester,
  ) async {
    final api = DashboardApiClient();
    await pumpStandalone(
      tester,
      child: const ClubBagScreen(),
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pumpAndSettle();

    expect(find.text('6 IRON'), findsOneWidget);
    expect(find.text('DRIVER'), findsOneWidget);
    expect(find.text('OLD WEDGE'), findsOneWidget);

    await tester.tap(find.text('6 IRON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    expect(api.deleteClubCalls, 1);
  });

  testWidgets('club bag screen shows empty state', (WidgetTester tester) async {
    await pumpStandalone(
      tester,
      child: const ClubBagScreen(),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(emptyClubBag: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('NO CLUBS SAVED'), findsOneWidget);
  });

  testWidgets('favorites screen renders folders and remove action', (
    WidgetTester tester,
  ) async {
    final api = DashboardApiClient();
    await pumpStandalone(
      tester,
      child: const FavoritesScreen(),
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIORITY REVIEWS'), findsOneWidget);
    expect(find.text('7 IRON REPORT'), findsOneWidget);
    expect(find.text('DRIVER SESSION'), findsOneWidget);

    await tester.tap(find.text('PRIORITY REVIEWS'));
    await tester.pumpAndSettle();
    expect(find.text('7 IRON REPORT'), findsOneWidget);
    expect(find.text('DRIVER SESSION'), findsNothing);

    await tester.tap(find.text('REMOVE FAVORITE'));
    await tester.pumpAndSettle();
    expect(api.deleteFavoriteCalls, 1);
  });

  testWidgets('stats quick action opens overview and metric routes', (
    WidgetTester tester,
  ) async {
    final api = DashboardApiClient();
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('home-action-stats')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-action-stats')));
    await tester.pumpAndSettle();
    expect(find.text('STATS OVERVIEW'), findsOneWidget);
    expect(find.text('MOST COMMON FOCUS'), findsOneWidget);

    await tester.tap(find.text('SWING SCORE'));
    await tester.pumpAndSettle();
    expect(find.text('SWING STATS'), findsWidgets);

    await tester.tap(find.text('TRACER'));
    await tester.pumpAndSettle();
    expect(api.tracerStatsCalls, greaterThanOrEqualTo(1));
    expect(find.text('SHOT TRACER STATS'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('Visual-only path confidence'),
      360,
    );
    expect(find.textContaining('Visual-only path confidence'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FAULTS'));
    await tester.pumpAndSettle();
    expect(api.faultStatsCalls, greaterThanOrEqualTo(1));
    expect(find.text('FAULT TRENDS'), findsWidgets);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('home-action-stats')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-action-stats')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MAIN FOCUS'));
    await tester.pumpAndSettle();

    expect(api.faultStatsCalls, greaterThanOrEqualTo(1));
    expect(find.text('FAULT TRENDS'), findsWidgets);
  });

  testWidgets('stats detail shows route-specific honest empty states', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const StatsDetailScreen(kind: 'swings'),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(emptyStats: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('NOT ENOUGH DATA YET'), findsOneWidget);
    expect(find.text('SWING STATS'), findsOneWidget);
    expect(find.text('RECORD SWING'), findsOneWidget);

    await pumpStandalone(
      tester,
      child: const StatsDetailScreen(kind: 'tracer'),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(emptyStats: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('SHOT TRACER STATS'), findsOneWidget);
    expect(find.text('RECORD TRACER'), findsOneWidget);
    expect(find.textContaining('Carry, ball speed, spin'), findsOneWidget);

    await pumpStandalone(
      tester,
      child: const StatsDetailScreen(kind: 'faults'),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(emptyStats: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('FAULT TRENDS'), findsOneWidget);
    expect(
      find.textContaining('Fault trends need completed reports'),
      findsOneWidget,
    );
  });

  testWidgets('stats metrics tolerate long labels on a narrow viewport', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await pumpStandalone(
      tester,
      child: const StatsOverviewScreen(),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(longStats: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('STATS OVERVIEW'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('performance snapshot screen uses dedicated endpoint', (
    WidgetTester tester,
  ) async {
    final api = DashboardApiClient();
    await pumpStandalone(
      tester,
      child: const PerformanceSnapshotScreen(),
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pumpAndSettle();

    expect(api.homeDashboardCalls, 0);
    expect(api.performanceSnapshotCalls, 1);
    expect(find.text('PERFORMANCE SNAPSHOT'), findsWidgets);
  });

  testWidgets('bottom navigation opens phased product sections', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(
      tester,
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(),
    );
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(
      find.byKey(const ValueKey('bottom-nav-bar')),
    );
    expect(navBar.height, 84);
    expect(navBar.backgroundColor, Colors.transparent);
    expect(navBar.indicatorColor, const Color(0x30F2F2F5));
    final indicatorShape = navBar.indicatorShape as StadiumBorder;
    expect(indicatorShape.side.color, const Color(0x4DF2F2F5));
    final navTheme = tester.widget<NavigationBarTheme>(
      find.byType(NavigationBarTheme).last,
    );
    expect(
      navTheme.data.iconTheme!.resolve({WidgetState.selected})!.color,
      const Color(0xFFF8F8FA),
    );
    expect(
      navTheme.data.iconTheme!.resolve(<WidgetState>{})!.color,
      const Color(0xFFE2E2E8),
    );
    final selectedLabel = navTheme.data.labelTextStyle!.resolve({
      WidgetState.selected,
    })!;
    final unselectedLabel = navTheme.data.labelTextStyle!.resolve(
      <WidgetState>{},
    )!;
    expect(selectedLabel.color, const Color(0xFFF8F8FA));
    expect(unselectedLabel.color, const Color(0xFFD7D7DE));
    expect(selectedLabel.letterSpacing, 0);

    await tester.tap(find.text('Swing'));
    await tester.pumpAndSettle();
    expect(find.text('SWING LIBRARY'), findsOneWidget);

    await tester.tap(find.text('Tracer'));
    await tester.pumpAndSettle();
    expect(find.text('SHOT TRACER'), findsOneWidget);
    expect(find.text('START TRACER CAMERA'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shot-tracer-hero-image')),
      findsOneWidget,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);

    await tester.tap(find.text('Rounds'));
    await tester.pumpAndSettle();
    expect(find.text('ROUNDS'), findsOneWidget);
  });

  test('register surfaces duplicate email from the API', () async {
    final auth = AuthController(
      FailingRegisterApiClient(
        statusCode: 409,
        data: {'detail': 'Email is already registered'},
      ),
    );
    auth.state = const AuthState();

    await auth.register('golfer@example.com', 'password123');

    expect(auth.state.error, 'Email is already registered.');
  });

  test('register surfaces validation guidance from the API', () async {
    final auth = AuthController(
      FailingRegisterApiClient(
        statusCode: 422,
        data: {
          'detail': [
            {'msg': 'String should have at least 8 characters'},
          ],
        },
      ),
    );
    auth.state = const AuthState();

    await auth.register('golfer@example.com', 'short');

    expect(
      auth.state.error,
      'Enter a valid email and a password with at least 8 characters.',
    );
  });

  test('login hydrates returning user profile and consent', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final auth = AuthController(ReturningUserApiClient());
    auth.state = const AuthState();

    await auth.login('returning@example.com', 'password123');

    expect(auth.state.isAuthenticated, isTrue);
    expect(auth.state.isOnboarded, isTrue);
    expect(auth.state.profile?.skillLevel, 'intermediate');
    expect(auth.state.hasVideoConsent, isTrue);
  });

  test('login clears token storage when hydration fails', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final auth = AuthController(HydrationFailingLoginApiClient());
    auth.state = const AuthState();

    await auth.login('returning@example.com', 'password123');

    expect(auth.state.isAuthenticated, isFalse);
    expect(await storage.read(key: 'access_token'), isNull);
    expect(await storage.read(key: 'refresh_token'), isNull);
  });

  testWidgets('guided capture requires video consent', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const UploadScreen(),
      auth: NoConsentTestAuthController(),
      apiClient: DashboardApiClient(),
    );

    expect(find.text('GUIDED CAPTURE'), findsOneWidget);
    expect(
      find.text('Video-processing consent is required before upload.'),
      findsOneWidget,
    );
    expect(find.text('REVIEW CONSENT'), findsOneWidget);
    expect(find.text('RECORD VIDEO'), findsNothing);
  });

  testWidgets(
    'guided capture exposes phase 2 controls and disables upload without media',
    (WidgetTester tester) async {
      await pumpStandalone(
        tester,
        child: const UploadScreen(),
        auth: ReadyTestAuthController(),
        apiClient: DashboardApiClient(),
      );

      expect(find.text('RECORD VIDEO'), findsOneWidget);
      expect(find.text('CHOOSE VIDEO'), findsOneWidget);
      expect(find.text('FACE ON'), findsOneWidget);
      expect(find.text('DOWN THE LINE'), findsOneWidget);
      expect(find.text('REAR TRACER'), findsNothing);
      expect(find.text('DRIVER'), findsOneWidget);
      expect(find.text('RANGE'), findsOneWidget);

      final upload = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'UPLOAD SWING'),
      );
      expect(upload.onPressed, isNull);
    },
  );

  testWidgets('guided capture uses active club bag items when available', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const UploadScreen(),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(),
    );
    await tester.pumpAndSettle();

    expect(find.text('6 IRON'), findsOneWidget);
    expect(find.text('DRIVER'), findsOneWidget);
    expect(find.text('OLD WEDGE'), findsNothing);
  });

  testWidgets('shot tracer capture exposes rear guide setup', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const UploadScreen(mode: UploadMode.tracer),
      auth: ReadyTestAuthController(),
      apiClient: DashboardApiClient(),
    );

    expect(find.text('SHOT TRACER'), findsOneWidget);
    expect(find.text('ANGLE: REAR TRACER'), findsOneWidget);
    expect(find.text('BALL'), findsOneWidget);
    expect(find.text('TARGET'), findsOneWidget);
    expect(find.text('SIGNATURE'), findsOneWidget);
    expect(find.text('BROADCAST WHITE'), findsOneWidget);
    expect(find.text('POWER RED'), findsOneWidget);
    expect(find.text('BALL VISIBLE'), findsOneWidget);
    expect(find.text('BALL IN LAUNCH ZONE'), findsOneWidget);
    expect(find.text('TARGET LINE SET'), findsOneWidget);
    expect(find.text('TARGET FORWARD'), findsOneWidget);
    expect(find.text('HELD STILL 1 SEC'), findsOneWidget);
    expect(find.text('RANGE READY'), findsOneWidget);
    expect(find.text('UPLOAD TRACER VIDEO'), findsOneWidget);
    expect(find.text('FACE ON'), findsNothing);
  });

  testWidgets('swing detail renders backend quality results', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(),
    );
    await tester.pumpAndSettle();

    expect(find.text('QUALITY: WARN'), findsOneWidget);
    expect(find.text('SCORE: 80'), findsOneWidget);
    expect(find.text('DURATION: 4.2 SEC'), findsOneWidget);
    expect(find.text('START ANALYSIS'), findsOneWidget);
    expect(
      find.text(
        'WARN: Gallery videos may not use the SwingLens capture guide.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('OBJECT KEY:'), findsNothing);
  });

  testWidgets('tracer detail starts detector and hides pose analysis', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(
        tracerSession: true,
        startTracerJobPayload: _tracerJob(
          status: 'running',
          progress: 45,
          jobType: 'detect',
        ),
        polledTracerJob: _tracerJob(
          status: 'running',
          progress: 55,
          jobType: 'detect',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ANGLE: REAR_TRACER'), findsOneWidget);
    expect(find.text('CREATE TRACER'), findsOneWidget);
    expect(find.text('START ANALYSIS'), findsNothing);

    await tester.ensureVisible(find.text('CREATE TRACER'));
    await tester.pump();
    await tester.tap(find.text('CREATE TRACER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DETECT · RUNNING · 55%'), findsOneWidget);
    expect(
      find.text('TRACKING BALL PATH AND RENDERING PRIVATE VIDEO'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tracer result shows needs-better-capture without manual edit', (
    WidgetTester tester,
  ) async {
    final api = SwingDetailApiClient(
      tracerSession: true,
      tracerResult: _tracerResult(status: 'needs_review'),
    );
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('TRACER FILM ROOM'), findsOneWidget);
    expect(
      find.text(
        'NEEDS BETTER CAPTURE: use the guided rear camera flow with a white ball, stable phone, and visible target line.',
      ),
      findsOneWidget,
    );
    expect(find.text('RECORD GUIDED TRACER'), findsOneWidget);
    expect(find.text('STATUS: NEEDS BETTER CAPTURE'), findsOneWidget);
    expect(
      find.text('DETECTED POINTS: 3 · INTERPOLATED: 1 · GAPS: 1'),
      findsOneWidget,
    );
    expect(find.text('FIX BEFORE RETRY'), findsOneWidget);
    expect(
      find.text('- Use the guided rear camera instead of gallery import.'),
      findsOneWidget,
    );
    expect(
      find.text('- Keep the SwingLens tracer guide active before recording.'),
      findsOneWidget,
    );
    expect(
      find.text('- Confirm a visible white ball before recording.'),
      findsOneWidget,
    );
    expect(
      find.text('- Hold the phone steady for at least one second.'),
      findsOneWidget,
    );
    expect(find.text('- Record at 24 FPS or higher.'), findsOneWidget);
    expect(find.text('VISUAL FLIGHT'), findsOneWidget);
    expect(find.text('LAUNCH: 97.6° · START: -2.3°'), findsOneWidget);
    expect(find.text('APEX: 54% FRAME · CURVE: STRAIGHT'), findsOneWidget);
    expect(find.text('EDIT TRACER PATH'), findsNothing);
    expect(find.text('MANUAL TRACER EDIT'), findsNothing);
    expect(find.byKey(const ValueKey('tracer-save-edit')), findsNothing);
    expect(api.savedTracerControlPoints, isEmpty);
    expect(api.renderStartCalls, 0);
  });

  testWidgets('analysis panel shows running state after starting a job', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(
        startJob: _analysisJob(status: 'running', progress: 35),
        polledJob: _analysisJob(status: 'running', progress: 55),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('START ANALYSIS'));
    await tester.tap(find.text('START ANALYSIS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('RUNNING · 55%'), findsOneWidget);
    expect(find.text('POSE TRACKED'), findsOneWidget);
    expect(find.text('SWING EVENTS MAPPED'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('analysis panel smooths sparse backend progress while running', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(
        startJob: _analysisJob(status: 'running', progress: 10),
        polledJob: _analysisJob(status: 'running', progress: 10),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('START ANALYSIS'));
    await tester.tap(find.text('START ANALYSIS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('RUNNING · 10%'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 850));

    expect(find.text('RUNNING · 13%'), findsOneWidget);
    expect(find.text('VIDEO PREPARED'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('analysis panel holds complete progress before overview', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(
        analysisResultAfterStart: _analysisResult(),
        startJob: _analysisJob(status: 'running', progress: 10),
        polledJob: _analysisJob(status: 'succeeded', progress: 100),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('START ANALYSIS'));
    await tester.tap(find.text('START ANALYSIS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('COMPLETE · 100%'), findsOneWidget);
    expect(find.text('REPORT BUILT'), findsOneWidget);
    expect(find.text('ANALYSIS REVIEW'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('ANALYSIS REVIEW'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('analysis panel shows backend failure and retry action', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(
        startJob: _analysisJob(
          status: 'failed',
          progress: 100,
          errorMessage: 'No frames could be sampled from uploaded video',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('START ANALYSIS'));
    await tester.tap(find.text('START ANALYSIS'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('could not be read frame by frame'),
      findsOneWidget,
    );
    expect(
      find.text('DETAIL: No frames could be sampled from uploaded video'),
      findsOneWidget,
    );
    expect(find.text('RETRY ANALYSIS'), findsOneWidget);
  });

  testWidgets('analysis panel surfaces polling errors for active jobs', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(
        startJob: _analysisJob(status: 'running', progress: 35),
        pollFails: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('START ANALYSIS'));
    await tester.tap(find.text('START ANALYSIS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Unable to poll analysis status.'), findsOneWidget);
    expect(find.text('CHECK STATUS'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('analysis panel renders compact result overview', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(analysisResult: _analysisResult()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('ANALYSIS REVIEW'), findsOneWidget);
    expect(find.text('EVIDENCE REPLAY'), findsOneWidget);
    expect(
      find.text(
        'Prototype analysis sampled 24 frames and detected pose in 18 frames.',
      ),
      findsOneWidget,
    );
    expect(find.text('78'), findsOneWidget);
    expect(find.text('MOVEMENT SCORE'), findsOneWidget);
    expect(find.text('POSTURE CHANGED THROUGH IMPACT'), findsOneWidget);
    expect(find.text('TEMPO RATIO'), findsOneWidget);
    expect(find.text('POSTURE CHANGE'), findsOneWidget);
    expect(find.text('FINISH STABILITY'), findsOneWidget);
    expect(find.text('FIX THIS FIRST'), findsOneWidget);
    expect(find.textContaining('slow half-swings'), findsOneWidget);
    expect(find.textContaining('NEXT GOAL:'), findsWidgets);
    expect(find.text('EVIDENCE REPLAY'), findsOneWidget);
    expect(find.text('VIEW FULL BREAKDOWN'), findsOneWidget);
    expect(find.text('KEY MOMENTS'), findsNothing);
  });

  testWidgets('swing detail favorite toggle saves the session', (
    WidgetTester tester,
  ) async {
    final api = SwingDetailApiClient(analysisResult: _analysisResult());
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('SAVE SESSION'));
    await tester.tap(find.text('SAVE SESSION'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.saveFavoriteCalls, 1);
    expect(find.text('SESSION SAVED'), findsOneWidget);
  });

  testWidgets('favorite toggle queues save when the network is unavailable', (
    WidgetTester tester,
  ) async {
    final queue = OfflineQueueStore(
      persistence: MemoryOfflineQueuePersistence(),
    );
    await queue.load();
    final api = SwingDetailApiClient(
      analysisResult: _analysisResult(),
      failFavoriteWrites: true,
    );
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: api,
      offlineQueue: queue,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('SAVE SESSION'));
    await tester.tap(find.text('SAVE SESSION'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(api.saveFavoriteCalls, 1);
    expect(queue.pendingCount, 1);
    expect(queue.items.single.action, 'favorite.save');
    expect(find.text('SYNC QUEUED'), findsOneWidget);
  });

  testWidgets('analysis report favorite toggle saves the report', (
    WidgetTester tester,
  ) async {
    final api = SwingDetailApiClient(analysisResult: _analysisResult());
    await pumpStandalone(
      tester,
      child: const SwingReportScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('SAVE REPORT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.saveFavoriteCalls, 1);
    expect(find.text('REPORT SAVED'), findsOneWidget);
  });

  testWidgets('tracer result favorite toggle saves the tracer', (
    WidgetTester tester,
  ) async {
    final api = SwingDetailApiClient(
      tracerSession: true,
      tracerResult: _tracerResult(),
    );
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: api,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('SAVE TRACER'));
    await tester.tap(find.text('SAVE TRACER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.saveFavoriteCalls, 1);
    expect(find.text('TRACER SAVED'), findsOneWidget);
  });

  testWidgets('analysis breakdown route renders full report and keyframes', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingReportScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(analysisResult: _analysisResult()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('ANALYSIS BREAKDOWN'), findsOneWidget);
    expect(find.text('SWING FILM ROOM'), findsOneWidget);
    expect(find.text('FULL REPORT'), findsOneWidget);
    expect(find.text('MOVEMENT SCORE: 78'), findsOneWidget);
    expect(
      find.text('PRIMARY: POSTURE CHANGED THROUGH IMPACT'),
      findsOneWidget,
    );
    expect(find.textContaining('TEMPO RATIO:'), findsOneWidget);
    expect(find.textContaining('IMPACT EXTENSION:'), findsOneWidget);
    expect(find.text('KEY MOMENTS'), findsOneWidget);
    expect(find.text('P1 SETUP'), findsOneWidget);
  });

  testWidgets('film room overview keeps controls compact', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: Scaffold(
        body: SingleChildScrollView(
          child: SwingFilmRoomView(
            track: _overlayTrack(),
            mode: SwingFilmRoomMode.overview,
          ),
        ),
      ),
      auth: ReadyTestAuthController(),
    );

    expect(find.text('EVIDENCE REPLAY'), findsOneWidget);
    expect(find.text('SWING FILM ROOM'), findsNothing);
    expect(find.text('0.25X'), findsNothing);
    expect(find.text('ADJUST EVENTS'), findsNothing);
    expect(find.byKey(const ValueKey('film-room-slider')), findsNothing);
  });

  testWidgets('film room exposes slider speed toggles and fault panel', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: Scaffold(
        body: SingleChildScrollView(
          child: SwingFilmRoomView(track: _overlayTrack()),
        ),
      ),
      auth: ReadyTestAuthController(),
    );

    expect(find.text('SWING FILM ROOM'), findsOneWidget);
    expect(find.byKey(const ValueKey('film-room-slider')), findsOneWidget);
    expect(find.text('0.25X'), findsOneWidget);
    expect(find.text('0.50X'), findsOneWidget);
    expect(find.text('1X'), findsOneWidget);
    expect(find.text('P1'), findsWidgets);
    expect(find.text('P7'), findsOneWidget);
    expect(find.text('EVENT 90%'), findsOneWidget);
    expect(find.text('LEAD ARM 164°'), findsOneWidget);
    expect(find.text('STANCE 2.15 BW'), findsOneWidget);
    expect(find.text('EXT 1.24 BW'), findsOneWidget);
    expect(find.text('BODY PLANE 12°'), findsOneWidget);
    expect(find.text('HAND LINE 34°'), findsOneWidget);
    expect(find.text('SWAY'), findsOneWidget);

    await tester.ensureVisible(find.text('SWAY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SWAY'));
    await tester.pumpAndSettle();

    expect(find.text('PRIMARY MISTAKE MOMENT'), findsOneWidget);
    expect(find.textContaining('WHAT HAPPENED:'), findsOneWidget);
    expect(find.textContaining('FIX DRILL:'), findsOneWidget);

    await tester.tap(find.text('SKELETON').first);
    await tester.tap(find.text('0.25X'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('film room event review can set save and reset checkpoints', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 2200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    Map<String, int>? saved;
    var resetCalled = false;
    await pumpStandalone(
      tester,
      child: Scaffold(
        body: SingleChildScrollView(
          child: SwingFilmRoomView(
            track: _overlayTrack(reviewed: true),
            onSaveReview: (overrides) async => saved = overrides,
            onResetReview: () async => resetCalled = true,
          ),
        ),
      ),
      auth: ReadyTestAuthController(),
    );

    expect(find.text('P4 REVIEWED'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('phase-chip-P4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('phase-chip-P4')));
    await tester.pumpAndSettle();
    expect(find.text('REVIEWED EVENT'), findsOneWidget);

    await tester.tap(find.text('ADJUST EVENTS'));
    await tester.pumpAndSettle();
    expect(find.text('SET P1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-phase-P4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('set-review-phase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-event-review')));
    await tester.pumpAndSettle();

    expect(saved?['P4'], 1000);
    expect(find.text('REVIEW SAVED'), findsOneWidget);

    await tester.tap(find.text('ADJUST EVENTS'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reset-event-review')));
    await tester.pumpAndSettle();
    expect(resetCalled, isTrue);
  });

  test(
    'overlay track keeps portrait display aspect for rotated MOV output',
    () {
      final track = AnalysisOverlayTrack.fromJson({
        'result_id': 'analysis-result-rotated',
        'swing_video_id': 'video-rotated',
        'duration_ms': 25000,
        'resolution_width': 2160,
        'resolution_height': 3840,
        'coordinate_space': 'normalized_image',
        'landmark_schema': 'mediapipe_pose_33',
        'segments': <Map<String, dynamic>>[],
        'frames': <Map<String, dynamic>>[],
        'checkpoints': <Map<String, dynamic>>[],
        'fault_checkpoints': <Map<String, dynamic>>[],
      });

      expect(track.aspectRatio, closeTo(0.5625, 0.0001));
    },
  );

  testWidgets('settings privacy screen renders backend data inventory', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const PrivacyDataScreen(),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIVACY'), findsOneWidget);
    expect(find.text('DATA INVENTORY'), findsOneWidget);
    expect(find.text('UPLOADS: 2'), findsOneWidget);
    expect(find.text('VIDEOS: 1'), findsOneWidget);
    expect(find.text('ANALYSIS RESULTS: 1'), findsOneWidget);
    expect(find.text('TRACER RESULTS: 1'), findsOneWidget);
  });

  testWidgets(
    'subscription screen renders entitlement status and sync action',
    (WidgetTester tester) async {
      await pumpStandalone(
        tester,
        child: const SubscriptionScreen(),
        auth: ReadyTestAuthController(),
        apiClient: SwingDetailApiClient(),
      );
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION'), findsOneWidget);
      expect(find.text('NOT ACTIVE'), findsOneWidget);
      expect(find.text('SYNC ENTITLEMENT'), findsOneWidget);
      expect(find.text('RESTORE PURCHASES'), findsOneWidget);

      await tester.tap(find.text('RESTORE PURCHASES'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SYNC ENTITLEMENT'));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('PRODUCT: swinglens_pro_monthly'), findsOneWidget);
    },
  );

  testWidgets('swing detail delete video action opens confirmation', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('DELETE VIDEO'));
    await tester.tap(find.text('DELETE VIDEO'));
    await tester.pumpAndSettle();

    expect(find.text('Delete video?'), findsOneWidget);
    expect(find.textContaining('private video'), findsOneWidget);
  });

  testWidgets('delete account screen requires typed confirmation', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const DeleteAccountScreen(),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(),
    );
    await tester.pumpAndSettle();

    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'DELETE ACCOUNT'),
    );
    expect(disabled.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pumpAndSettle();
    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'DELETE ACCOUNT'),
    );
    expect(enabled.onPressed, isNotNull);
  });

  test('upload capture metadata serializes phase 2 fields', () {
    const metadata = UploadCaptureMetadata(
      source: 'camera',
      guideOverlay: true,
      platform: 'ios',
      cameraLensDirection: 'back',
      nativeHighFpsAvailable: false,
      fileExtension: '.mov',
    );

    expect(metadata.toJson(), {
      'source': 'camera',
      'guide_overlay': true,
      'platform': 'ios',
      'camera_lens_direction': 'back',
      'native_high_fps_available': false,
      'file_extension': '.mov',
    });
  });

  test('upload capture metadata serializes tracer setup', () {
    const metadata = UploadCaptureMetadata(
      source: 'camera',
      guideOverlay: true,
      tracer: {
        'ball_anchor': {'x': 0.5, 'y': 0.78},
        'target_line': {
          'start': {'x': 0.5, 'y': 0.78},
          'end': {'x': 0.44, 'y': 0.24},
        },
      },
    );

    expect(metadata.toJson()['tracer'], {
      'ball_anchor': {'x': 0.5, 'y': 0.78},
      'target_line': {
        'start': {'x': 0.5, 'y': 0.78},
        'end': {'x': 0.44, 'y': 0.24},
      },
    });
  });

  test('tracer readiness allows only verified guided camera auto tracking', () {
    final readiness = buildTracerReadiness(
      const TracerReadinessInput(
        cameraReady: true,
        rearCameraActive: true,
        guideOverlay: true,
        ballAnchorSet: true,
        targetLineSet: true,
        whiteBallConfirmed: true,
        sensorVerified: true,
        phoneLevel: true,
        phoneStable: true,
        simulatorOrUnverified: false,
      ),
    );

    expect(readiness.autoEligible, isTrue);
    expect(readiness.canRecord, isTrue);
    expect(readiness.unverifiedTestCapture, isFalse);
  });

  test(
    'tracer readiness permits simulator capture only as unverified test',
    () {
      final readiness = buildTracerReadiness(
        const TracerReadinessInput(
          cameraReady: true,
          rearCameraActive: true,
          guideOverlay: true,
          ballAnchorSet: true,
          targetLineSet: true,
          whiteBallConfirmed: true,
          sensorVerified: false,
          phoneLevel: false,
          phoneStable: false,
          simulatorOrUnverified: true,
        ),
      );

      expect(readiness.autoEligible, isFalse);
      expect(readiness.unverifiedTestCapture, isTrue);
      expect(readiness.canRecord, isTrue);
      expect(readiness.checks['simulator_or_unverified'], isTrue);
    },
  );

  test('tracer readiness blocks recording without white ball confirmation', () {
    final readiness = buildTracerReadiness(
      const TracerReadinessInput(
        cameraReady: true,
        rearCameraActive: true,
        guideOverlay: true,
        ballAnchorSet: true,
        targetLineSet: true,
        whiteBallConfirmed: false,
        sensorVerified: true,
        phoneLevel: true,
        phoneStable: true,
        simulatorOrUnverified: false,
      ),
    );

    expect(readiness.autoEligible, isFalse);
    expect(readiness.canRecord, isFalse);
    expect(readiness.checks['white_ball_confirmed'], isFalse);
  });

  test('tracer readiness blocks poor range alignment geometry', () {
    final readiness = buildTracerReadiness(
      const TracerReadinessInput(
        cameraReady: true,
        rearCameraActive: true,
        guideOverlay: true,
        ballAnchorSet: true,
        ballAnchorLaunchZone: false,
        targetLineSet: true,
        targetLineForward: false,
        whiteBallConfirmed: true,
        sensorVerified: true,
        phoneLevel: true,
        phoneStable: true,
        stableDurationMs: 1300,
        simulatorOrUnverified: false,
      ),
    );

    expect(readiness.autoEligible, isFalse);
    expect(readiness.canRecord, isFalse);
    expect(readiness.checks['ball_anchor_launch_zone'], isFalse);
    expect(readiness.checks['target_line_forward'], isFalse);
  });

  test('tracer readiness requires a full one-second stable hold', () {
    final readiness = buildTracerReadiness(
      const TracerReadinessInput(
        cameraReady: true,
        rearCameraActive: true,
        guideOverlay: true,
        ballAnchorSet: true,
        targetLineSet: true,
        whiteBallConfirmed: true,
        sensorVerified: true,
        phoneLevel: true,
        phoneStable: true,
        stableDurationMs: 700,
        simulatorOrUnverified: false,
      ),
    );

    expect(readiness.autoEligible, isFalse);
    expect(readiness.canRecord, isFalse);
    expect(readiness.checks['stable_duration_1s'], isFalse);
  });
}
