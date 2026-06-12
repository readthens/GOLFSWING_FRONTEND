import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: apiBaseUrl);
});

class ApiClient {
  ApiClient({required String baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
        ),
      ),
      _rawDio = Dio();

  final Dio _dio;
  final Dio _rawDio;

  Future<AuthPayload> register({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/v1/auth/register',
      data: {'email': email, 'password': password},
    );
    return AuthPayload.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthPayload> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthPayload.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthPayload> loginWithApple({
    required String identityToken,
    String? nonce,
    String? fullName,
    String? authorizationCode,
  }) async {
    final payload = <String, dynamic>{
      'identity_token': identityToken,
      'nonce': nonce,
      'full_name': fullName,
      'authorization_code': authorizationCode,
    }..removeWhere((_, value) => value == null);
    final response = await _dio.post('/v1/auth/apple', data: payload);
    return AuthPayload.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AppleNonce> createAppleNonce() async {
    final response = await _dio.post('/v1/auth/apple/nonce');
    return AppleNonce.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/v1/auth/logout', data: {'refresh_token': refreshToken});
  }

  Future<MePayload> getMe(String accessToken) async {
    final response = await _dio.get('/v1/me', options: _auth(accessToken));
    return MePayload.fromJson(response.data as Map<String, dynamic>);
  }

  Future<HomeDashboard> getHomeDashboard(String accessToken) async {
    final response = await _dio.get('/v1/home', options: _auth(accessToken));
    return HomeDashboard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<DashboardItem>> getActivity(String accessToken) async {
    final response = await _dio.get(
      '/v1/activity',
      options: _auth(accessToken),
    );
    final items = response.data as List<dynamic>;
    return items
        .map((item) => DashboardItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<NotificationItem>> getNotifications(
    String accessToken, {
    bool unreadOnly = false,
  }) async {
    final response = await _dio.get(
      '/v1/notifications',
      queryParameters: {'unread_only': unreadOnly},
      options: _auth(accessToken),
    );
    final items = response.data as List<dynamic>;
    return items
        .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> getNotificationUnreadCount(String accessToken) async {
    final response = await _dio.get(
      '/v1/notifications/unread-count',
      options: _auth(accessToken),
    );
    final payload = response.data as Map<String, dynamic>;
    return payload['unread_count'] as int? ?? 0;
  }

  Future<NotificationItem> markNotificationRead(
    String accessToken,
    String notificationId,
  ) async {
    final response = await _dio.post(
      '/v1/notifications/$notificationId/read',
      options: _auth(accessToken),
    );
    return NotificationItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markAllNotificationsRead(String accessToken) async {
    await _dio.post('/v1/notifications/read-all', options: _auth(accessToken));
  }

  Future<void> deleteNotification(
    String accessToken,
    String notificationId,
  ) async {
    await _dio.delete(
      '/v1/notifications/$notificationId',
      options: _auth(accessToken),
    );
  }

  Future<NotificationPreferences> getNotificationPreferences(
    String accessToken,
  ) async {
    final response = await _dio.get(
      '/v1/notifications/preferences',
      options: _auth(accessToken),
    );
    return NotificationPreferences.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<NotificationPreferences> updateNotificationPreferences(
    String accessToken,
    NotificationPreferences preferences,
  ) async {
    final response = await _dio.patch(
      '/v1/notifications/preferences',
      data: preferences.toJson(),
      options: _auth(accessToken),
    );
    return NotificationPreferences.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<StatsDashboard> getStatsOverview(String accessToken) async {
    final response = await _dio.get(
      '/v1/stats/overview',
      options: _auth(accessToken),
    );
    return StatsDashboard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StatsDashboard> getSwingStats(String accessToken) async {
    final response = await _dio.get(
      '/v1/stats/swings',
      options: _auth(accessToken),
    );
    return StatsDashboard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StatsDashboard> getTracerStats(String accessToken) async {
    final response = await _dio.get(
      '/v1/stats/tracer',
      options: _auth(accessToken),
    );
    return StatsDashboard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StatsDashboard> getRoundStats(String accessToken) async {
    final response = await _dio.get(
      '/v1/stats/rounds',
      options: _auth(accessToken),
    );
    return StatsDashboard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StatsDashboard> getClubStats(String accessToken) async {
    final response = await _dio.get(
      '/v1/stats/clubs',
      options: _auth(accessToken),
    );
    return StatsDashboard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StatsDashboard> getFaultStats(String accessToken) async {
    final response = await _dio.get(
      '/v1/stats/faults',
      options: _auth(accessToken),
    );
    return StatsDashboard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DashboardSection> getPerformanceSnapshot(String accessToken) async {
    final response = await _dio.get(
      '/v1/performance-snapshot',
      options: _auth(accessToken),
    );
    return DashboardSection.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MePayload> updateProfile(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      '/v1/me',
      data: payload,
      options: _auth(accessToken),
    );
    return MePayload.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ClubBagItem>> getClubBag(
    String accessToken, {
    bool activeOnly = false,
  }) async {
    final response = await _dio.get(
      '/v1/club-bag',
      queryParameters: {'active_only': activeOnly},
      options: _auth(accessToken),
    );
    final items = response.data as List<dynamic>;
    return items
        .map((item) => ClubBagItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ClubBagItem> createClubBagItem(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '/v1/club-bag',
      data: payload,
      options: _auth(accessToken),
    );
    return ClubBagItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ClubBagItem> updateClubBagItem(
    String accessToken,
    String clubId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      '/v1/club-bag/$clubId',
      data: payload,
      options: _auth(accessToken),
    );
    return ClubBagItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteClubBagItem(String accessToken, String clubId) async {
    await _dio.delete('/v1/club-bag/$clubId', options: _auth(accessToken));
  }

  Future<List<FavoriteFolder>> getFavoriteFolders(String accessToken) async {
    final response = await _dio.get(
      '/v1/favorites/folders',
      options: _auth(accessToken),
    );
    final items = response.data as List<dynamic>;
    return items
        .map((item) => FavoriteFolder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FavoriteFolder> createFavoriteFolder(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '/v1/favorites/folders',
      data: payload,
      options: _auth(accessToken),
    );
    return FavoriteFolder.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FavoriteFolder> updateFavoriteFolder(
    String accessToken,
    String folderId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      '/v1/favorites/folders/$folderId',
      data: payload,
      options: _auth(accessToken),
    );
    return FavoriteFolder.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteFavoriteFolder(String accessToken, String folderId) async {
    await _dio.delete(
      '/v1/favorites/folders/$folderId',
      options: _auth(accessToken),
    );
  }

  Future<List<FavoriteItem>> getFavorites(
    String accessToken, {
    String? folderId,
    String? entityType,
    String? entityId,
  }) async {
    final response = await _dio.get(
      '/v1/favorites',
      queryParameters: {
        'folder_id': ?folderId,
        'entity_type': ?entityType,
        'entity_id': ?entityId,
      },
      options: _auth(accessToken),
    );
    final items = response.data as List<dynamic>;
    return items
        .map((item) => FavoriteItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FavoriteItem> saveFavorite(
    String accessToken, {
    required String entityType,
    required String entityId,
    String? folderId,
    String? note,
    Map<String, dynamic> metadata = const {},
    String? idempotencyKey,
  }) async {
    final response = await _dio.post(
      '/v1/favorites',
      data: {
        'entity_type': entityType,
        'entity_id': entityId,
        'folder_id': folderId,
        'note': note,
        'metadata': metadata,
      }..removeWhere((_, value) => value == null),
      options: _auth(accessToken, idempotencyKey: idempotencyKey),
    );
    return FavoriteItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteFavorite(
    String accessToken,
    String favoriteId, {
    String? idempotencyKey,
  }) async {
    await _dio.delete(
      '/v1/favorites/$favoriteId',
      options: _auth(accessToken, idempotencyKey: idempotencyKey),
    );
  }

  Future<List<GolfRound>> getRounds(String accessToken) async {
    final response = await _dio.get('/v1/rounds', options: _auth(accessToken));
    final items = response.data as List<dynamic>;
    return items
        .map((item) => GolfRound.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GolfRound> createRound(
    String accessToken,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final response = await _dio.post(
      '/v1/rounds',
      data: payload,
      options: _auth(accessToken, idempotencyKey: idempotencyKey),
    );
    return GolfRound.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GolfRound> getRound(String accessToken, String roundId) async {
    final response = await _dio.get(
      '/v1/rounds/$roundId',
      options: _auth(accessToken),
    );
    return GolfRound.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GolfRound> updateRound(
    String accessToken,
    String roundId,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final response = await _dio.patch(
      '/v1/rounds/$roundId',
      data: payload,
      options: _auth(accessToken, idempotencyKey: idempotencyKey),
    );
    return GolfRound.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GolfRound> updateRoundHole(
    String accessToken,
    String roundId,
    int holeNumber,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final response = await _dio.patch(
      '/v1/rounds/$roundId/holes/$holeNumber',
      data: payload,
      options: _auth(accessToken, idempotencyKey: idempotencyKey),
    );
    return GolfRound.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GolfRound> completeRound(
    String accessToken,
    String roundId, {
    String? idempotencyKey,
  }) async {
    final response = await _dio.post(
      '/v1/rounds/$roundId/complete',
      options: _auth(accessToken, idempotencyKey: idempotencyKey),
    );
    return GolfRound.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GolfRound> reopenRound(
    String accessToken,
    String roundId, {
    String? idempotencyKey,
  }) async {
    final response = await _dio.post(
      '/v1/rounds/$roundId/reopen',
      options: _auth(accessToken, idempotencyKey: idempotencyKey),
    );
    return GolfRound.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteRound(
    String accessToken,
    String roundId, {
    String? idempotencyKey,
  }) async {
    await _dio.delete(
      '/v1/rounds/$roundId',
      options: _auth(accessToken, idempotencyKey: idempotencyKey),
    );
  }

  Future<List<Consent>> getConsents(String accessToken) async {
    final response = await _dio.get(
      '/v1/consents',
      options: _auth(accessToken),
    );
    final items = response.data as List<dynamic>;
    return items
        .map((item) => Consent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Consent> acceptVideoConsent(String accessToken) async {
    final response = await _dio.post(
      '/v1/consents',
      data: {'consent_type': 'video_processing', 'version': '2026-06-06'},
      options: _auth(accessToken),
    );
    return Consent.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SwingSession>> getSwingSessions(String accessToken) async {
    final response = await _dio.get(
      '/v1/swing-sessions',
      options: _auth(accessToken),
    );
    final items = response.data as List<dynamic>;
    return items
        .map((item) => SwingSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SwingSession> getSwingSession(
    String accessToken,
    String sessionId,
  ) async {
    final response = await _dio.get(
      '/v1/swing-sessions/$sessionId',
      options: _auth(accessToken),
    );
    return SwingSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnalysisJob> startAnalysisJob(
    String accessToken,
    String sessionId, {
    bool force = false,
  }) async {
    final response = await _dio.post(
      '/v1/swing-sessions/$sessionId/analysis-jobs',
      options: _auth(accessToken),
      queryParameters: force ? {'force': true} : null,
    );
    return AnalysisJob.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnalysisJob> getAnalysisJob(String accessToken, String jobId) async {
    final response = await _dio.get(
      '/v1/analysis-jobs/$jobId',
      options: _auth(accessToken),
    );
    return AnalysisJob.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnalysisResult?> getAnalysisResult(
    String accessToken,
    String sessionId,
  ) async {
    try {
      final response = await _dio.get(
        '/v1/swing-sessions/$sessionId/analysis',
        options: _auth(accessToken),
      );
      return AnalysisResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  String analysisKeyframeImageUrl(String keyframeId) {
    return '${_dio.options.baseUrl}/v1/analysis-keyframes/$keyframeId/image';
  }

  Future<AnalysisOverlayTrack> getOverlayTrack(
    String accessToken,
    String resultId,
  ) async {
    final response = await _dio.get(
      '/v1/analysis-results/$resultId/overlay-track',
      options: _auth(accessToken),
    );
    return AnalysisOverlayTrack.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnalysisEventReview> saveEventReview({
    required String accessToken,
    required String resultId,
    required List<PhaseOverride> phaseOverrides,
  }) async {
    final response = await _dio.put(
      '/v1/analysis-results/$resultId/event-review',
      data: {
        'phase_overrides': phaseOverrides
            .map((override) => override.toJson())
            .toList(),
      },
      options: _auth(accessToken),
    );
    return AnalysisEventReview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> resetEventReview({
    required String accessToken,
    required String resultId,
  }) async {
    await _dio.delete(
      '/v1/analysis-results/$resultId/event-review',
      options: _auth(accessToken),
    );
  }

  Future<SwingReport> getSwingReport({
    required String accessToken,
    required String resultId,
  }) async {
    final response = await _dio.get(
      '/v1/analysis-results/$resultId/swing-report',
      options: _auth(accessToken),
    );
    return SwingReport.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> downloadSwingVideoFile({
    required String accessToken,
    required String videoId,
    required String destinationPath,
  }) async {
    await _dio.download(
      '/v1/swing-videos/$videoId/file',
      destinationPath,
      options: _auth(accessToken),
    );
  }

  Future<TracerJob> startTracerJob(String accessToken, String sessionId) async {
    final response = await _dio.post(
      '/v1/swing-sessions/$sessionId/tracer-jobs',
      options: _auth(accessToken),
    );
    return TracerJob.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TracerJob> startTracerRenderJob({
    required String accessToken,
    required String resultId,
  }) async {
    final response = await _dio.post(
      '/v1/tracer-results/$resultId/render-jobs',
      options: _auth(accessToken),
    );
    return TracerJob.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TracerJob> getTracerJob(String accessToken, String jobId) async {
    final response = await _dio.get(
      '/v1/tracer-jobs/$jobId',
      options: _auth(accessToken),
    );
    return TracerJob.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TracerResult?> getTracerResult(
    String accessToken,
    String sessionId,
  ) async {
    try {
      final response = await _dio.get(
        '/v1/swing-sessions/$sessionId/tracer-result',
        options: _auth(accessToken),
      );
      return TracerResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<TracerEdit> saveTracerEdit({
    required String accessToken,
    required String resultId,
    required List<Map<String, num>> controlPoints,
    required Map<String, dynamic> style,
  }) async {
    final response = await _dio.put(
      '/v1/tracer-results/$resultId/edit',
      data: {'control_points': controlPoints, 'style': style},
      options: _auth(accessToken),
    );
    return TracerEdit.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> downloadTracerVideoFile({
    required String accessToken,
    required String resultId,
    required String destinationPath,
  }) async {
    await _dio.download(
      '/v1/tracer-results/$resultId/video',
      destinationPath,
      options: _auth(accessToken),
    );
  }

  Future<void> deleteSwingVideo({
    required String accessToken,
    required String sessionId,
    required String videoId,
  }) async {
    await _dio.delete(
      '/v1/swing-sessions/$sessionId/videos/$videoId',
      options: _auth(accessToken),
    );
  }

  Future<RevenueCatCustomer> getRevenueCatCustomer(String accessToken) async {
    final response = await _dio.get(
      '/v1/revenuecat/customer',
      options: _auth(accessToken),
    );
    return RevenueCatCustomer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RevenueCatCustomer> syncRevenueCatCustomer(String accessToken) async {
    final response = await _dio.post(
      '/v1/revenuecat/sync',
      options: _auth(accessToken),
    );
    final payload = response.data as Map<String, dynamic>;
    final entitlements =
        (payload['active_entitlements'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  RevenueCatEntitlement.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    return RevenueCatCustomer(
      appUserId: payload['app_user_id'] as String? ?? '',
      entitlementId: entitlements.isEmpty
          ? 'swinglens_pro'
          : entitlements.first.entitlementId,
      isEntitled: entitlements.any((item) => item.isActive),
      activeEntitlements: entitlements,
    );
  }

  Future<PrivacyInventory> getPrivacyInventory(String accessToken) async {
    final response = await _dio.get(
      '/v1/privacy/data-inventory',
      options: _auth(accessToken),
    );
    return PrivacyInventory.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteAccount(String accessToken) async {
    await _dio.delete(
      '/v1/me',
      data: {'confirmation': 'DELETE'},
      options: _auth(accessToken),
    );
  }

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
    final contentType = _videoContentType(file.name);
    final byteSize = await file.length();
    final presign = await _dio.post(
      '/v1/uploads/presign',
      data: {
        'filename': file.name,
        'content_type': contentType,
        'byte_size': byteSize,
      },
      options: _auth(
        accessToken,
        idempotencyKey: _stepKey(idempotencyKey, 'presign'),
      ),
    );
    final presignPayload = UploadPresignPayload.fromJson(
      presign.data as Map<String, dynamic>,
    );

    await _rawDio.put(
      presignPayload.presignedUrl,
      data: file.openRead(),
      options: Options(
        headers: {
          'Content-Type': contentType,
          Headers.contentLengthHeader: byteSize,
        },
        contentType: contentType,
      ),
    );

    await _dio.post(
      '/v1/uploads/complete',
      data: {'upload_id': presignPayload.upload.id, 'byte_size': byteSize},
      options: _auth(
        accessToken,
        idempotencyKey: _stepKey(idempotencyKey, 'complete'),
      ),
    );

    final session = await _dio.post(
      '/v1/swing-sessions',
      data: {
        'club': club,
        'session_type': sessionType,
        'location_type': locationType,
      },
      options: _auth(
        accessToken,
        idempotencyKey: _stepKey(idempotencyKey, 'session'),
      ),
    );
    final sessionPayload = SwingSession.fromJson(
      session.data as Map<String, dynamic>,
    );

    await _dio.post(
      '/v1/swing-sessions/${sessionPayload.id}/videos',
      data: {
        'upload_id': presignPayload.upload.id,
        'angle': angle,
        'duration_ms': durationMs,
        'resolution_width': resolutionWidth,
        'resolution_height': resolutionHeight,
        'capture_metadata': captureMetadata.toJson(),
        'metadata': {
          'source': 'mobile_upload_phase_2',
          'client_file_name': file.name,
          'client_byte_size': byteSize,
        },
      },
      options: _auth(
        accessToken,
        idempotencyKey: _stepKey(idempotencyKey, 'attach'),
      ),
    );

    return getSwingSession(accessToken, sessionPayload.id);
  }

  Options _auth(String token, {String? idempotencyKey}) {
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return Options(headers: headers);
  }

  String? _stepKey(String? baseKey, String step) =>
      baseKey == null ? null : '$baseKey:$step';

  String _videoContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }
}

class UploadCaptureMetadata {
  const UploadCaptureMetadata({
    required this.source,
    required this.guideOverlay,
    this.platform,
    this.cameraLensDirection,
    this.nativeHighFpsAvailable,
    this.fileExtension,
    this.tracer,
  });

  final String source;
  final bool guideOverlay;
  final String? platform;
  final String? cameraLensDirection;
  final bool? nativeHighFpsAvailable;
  final String? fileExtension;
  final Map<String, dynamic>? tracer;

  factory UploadCaptureMetadata.fromJson(Map<String, dynamic> json) {
    final tracerPayload = json['tracer'];
    return UploadCaptureMetadata(
      source: json['source'] as String? ?? 'gallery',
      guideOverlay: json['guide_overlay'] as bool? ?? false,
      platform: json['platform'] as String?,
      cameraLensDirection: json['camera_lens_direction'] as String?,
      nativeHighFpsAvailable: json['native_high_fps_available'] as bool?,
      fileExtension: json['file_extension'] as String?,
      tracer: tracerPayload is Map
          ? Map<String, dynamic>.from(tracerPayload)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'guide_overlay': guideOverlay,
      if (platform != null) 'platform': platform,
      if (cameraLensDirection != null)
        'camera_lens_direction': cameraLensDirection,
      if (nativeHighFpsAvailable != null)
        'native_high_fps_available': nativeHighFpsAvailable,
      if (fileExtension != null) 'file_extension': fileExtension,
      if (tracer != null) 'tracer': tracer,
    };
  }
}
