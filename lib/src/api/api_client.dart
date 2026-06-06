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

  Future<void> logout(String refreshToken) async {
    await _dio.post('/v1/auth/logout', data: {'refresh_token': refreshToken});
  }

  Future<MePayload> getMe(String accessToken) async {
    final response = await _dio.get('/v1/me', options: _auth(accessToken));
    return MePayload.fromJson(response.data as Map<String, dynamic>);
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
    String sessionId,
  ) async {
    final response = await _dio.post(
      '/v1/swing-sessions/$sessionId/analysis-jobs',
      options: _auth(accessToken),
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

  Future<SwingSession> uploadSwingVideo({
    required String accessToken,
    required XFile file,
    required String club,
    required String angle,
    required String locationType,
    required UploadCaptureMetadata captureMetadata,
    int? durationMs,
    int? resolutionWidth,
    int? resolutionHeight,
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
      options: _auth(accessToken),
    );
    final presignPayload = UploadPresignPayload.fromJson(
      presign.data as Map<String, dynamic>,
    );

    await _rawDio.put(
      presignPayload.presignedUrl,
      data: file.openRead(),
      options: Options(
        headers: {'Content-Type': contentType},
        contentType: contentType,
      ),
    );

    await _dio.post(
      '/v1/uploads/complete',
      data: {'upload_id': presignPayload.upload.id, 'byte_size': byteSize},
      options: _auth(accessToken),
    );

    final session = await _dio.post(
      '/v1/swing-sessions',
      data: {
        'club': club,
        'session_type': 'analysis',
        'location_type': locationType,
      },
      options: _auth(accessToken),
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
      options: _auth(accessToken),
    );

    return getSwingSession(accessToken, sessionPayload.id);
  }

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

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
  });

  final String source;
  final bool guideOverlay;
  final String? platform;
  final String? cameraLensDirection;
  final bool? nativeHighFpsAvailable;
  final String? fileExtension;

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
    };
  }
}
