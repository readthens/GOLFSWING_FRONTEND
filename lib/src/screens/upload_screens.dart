import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../capture/native_capture_bridge.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

const _maxVideoBytes = 250 * 1024 * 1024;
const _minGoodDurationMs = 2000;
const _maxGoodDurationMs = 15000;
const _maxAllowedDurationMs = 30000;
const _minGoodResolutionEdge = 720;
const _supportedExtensions = {'.mp4', '.mov', '.m4v', '.webm'};

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _picker = ImagePicker();
  final _nativeCaptureBridge = const NativeCaptureBridge();

  String _club = '7 iron';
  String _angle = 'down_the_line';
  String _locationType = 'range';
  String _source = 'gallery';
  String? _cameraLensDirection;
  bool _guideOverlay = false;
  bool? _nativeHighFpsAvailable;

  XFile? _file;
  int? _byteSize;
  int? _durationMs;
  int? _resolutionWidth;
  int? _resolutionHeight;
  VideoPlayerController? _videoController;
  CameraController? _cameraController;

  bool _isUploading = false;
  bool _isInitializingCamera = false;
  bool _isRecording = false;
  String? _error;
  String? _mediaNotice;
  String? _cameraNotice;

  @override
  void dispose() {
    _videoController?.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).state;
    final qualityChecks = _qualityChecks;
    final hasHardFailure = qualityChecks.any(
      (check) => check.severity == 'fail',
    );

    return AppScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/home'),
              ),
              const Text('GUIDED CAPTURE', style: AppTextStyles.title),
              const SizedBox(height: 12),
              Text(
                'Record with a simple guide or choose a saved swing. Quality checks run before upload.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              if (!auth.hasVideoConsent)
                InfoPanel(
                  children: [
                    const Text(
                      'Video-processing consent is required before upload.',
                    ),
                    GhostButton(
                      label: 'REVIEW CONSENT',
                      onPressed: () =>
                          context.go('/onboarding/privacy-consent'),
                    ),
                  ],
                )
              else ...[
                _CapturePreview(
                  angle: _angle,
                  cameraController: _cameraController,
                  videoController: _videoController,
                  file: _file,
                  isRecording: _isRecording,
                ),
                const SizedBox(height: 18),
                _buildSourceActions(),
                if (_cameraNotice != null) ...[
                  const SizedBox(height: 12),
                  InfoPanel(children: [Text(_cameraNotice!)]),
                ],
                const SizedBox(height: 18),
                const Text('ANGLE', style: AppTextStyles.label),
                const SizedBox(height: 10),
                SegmentedChoices(
                  values: const ['face_on', 'down_the_line'],
                  selected: _angle,
                  onSelected: (value) => setState(() => _angle = value),
                ),
                const SizedBox(height: 18),
                const Text('CLUB', style: AppTextStyles.label),
                const SizedBox(height: 10),
                SegmentedChoices(
                  values: const [
                    'driver',
                    '3 wood',
                    'hybrid',
                    '5 iron',
                    '7 iron',
                    'wedge',
                  ],
                  selected: _club,
                  onSelected: (value) => setState(() => _club = value),
                ),
                const SizedBox(height: 18),
                const Text('LOCATION', style: AppTextStyles.label),
                const SizedBox(height: 10),
                SegmentedChoices(
                  values: const ['range', 'course', 'indoor', 'net'],
                  selected: _locationType,
                  onSelected: (value) => setState(() => _locationType = value),
                ),
                const SizedBox(height: 18),
                if (_file != null) _buildReviewPanel(qualityChecks),
                if (_mediaNotice != null) ...[
                  const SizedBox(height: 12),
                  InfoPanel(children: [Text(_mediaNotice!)]),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorText(_error!),
                ],
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _isUploading ? 'UPLOADING' : 'UPLOAD SWING',
                  onPressed: _file == null || hasHardFailure || _isUploading
                      ? null
                      : () => _upload(auth.accessToken),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceActions() {
    return Row(
      children: [
        Expanded(
          child: GhostButton(
            label: _isRecording
                ? 'STOP RECORDING'
                : _isInitializingCamera
                ? 'OPENING CAMERA'
                : 'RECORD VIDEO',
            onPressed: _isInitializingCamera ? null : _recordOrStop,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GhostButton(
            label: 'CHOOSE VIDEO',
            onPressed: _isRecording ? null : _pickVideo,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewPanel(List<_LocalQualityCheck> qualityChecks) {
    return InfoPanel(
      children: [
        Text('FILE: ${_file!.name}'),
        Text('SOURCE: ${_source.toUpperCase()}'),
        Text('SIZE: ${_formatBytes(_byteSize)}'),
        Text('DURATION: ${_formatDuration(_durationMs)}'),
        Text('RESOLUTION: ${_formatResolution()}'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.content_cut),
                label: const Text('TRIM START'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.content_cut),
                label: const Text('TRIM END'),
              ),
            ),
          ],
        ),
        const Text('Trim controls are staged for a later capture pass.'),
        ...qualityChecks.map(
          (check) => _QualityCheckRow(
            severity: check.severity,
            message: check.message,
          ),
        ),
      ],
    );
  }

  Future<void> _pickVideo() async {
    final video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (video != null) {
      await _prepareVideo(
        video,
        source: 'gallery',
        guideOverlay: false,
        cameraLensDirection: null,
      );
    }
  }

  Future<void> _recordOrStop() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initializeCamera();
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await _videoController?.dispose();
      setState(() {
        _file = null;
        _videoController = null;
        _byteSize = null;
        _durationMs = null;
        _resolutionWidth = null;
        _resolutionHeight = null;
        _mediaNotice = null;
      });
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _cameraNotice = null;
        _error = null;
      });
    } catch (_) {
      setState(() {
        _cameraNotice =
            'Camera recording is unavailable on this device. Choose a saved video instead.';
      });
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) return;
    try {
      final video = await controller.stopVideoRecording();
      setState(() => _isRecording = false);
      await _prepareVideo(
        video,
        source: 'camera',
        guideOverlay: true,
        cameraLensDirection: _cameraLensDirection,
      );
    } catch (_) {
      setState(() {
        _isRecording = false;
        _cameraNotice =
            'Recording could not be saved. Choose a saved video or try recording again.';
      });
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraNotice = null;
    });
    try {
      final capabilities = await _nativeCaptureBridge.getCaptureCapabilities();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraNotice =
              'No camera is available here. Choose a saved video to keep testing.';
          _isInitializingCamera = false;
          _nativeHighFpsAvailable = capabilities.highFpsCaptureAvailable;
        });
        return;
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _cameraController?.dispose();
      setState(() {
        _cameraController = controller;
        _cameraLensDirection = camera.lensDirection.name;
        _nativeHighFpsAvailable = capabilities.highFpsCaptureAvailable;
        _isInitializingCamera = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraNotice =
            'Camera is unavailable here. Choose a saved video to keep testing.';
        _isInitializingCamera = false;
      });
    }
  }

  Future<void> _prepareVideo(
    XFile file, {
    required String source,
    required bool guideOverlay,
    required String? cameraLensDirection,
  }) async {
    await _videoController?.dispose();
    VideoPlayerController? controller;
    int? byteSize;
    int? durationMs;
    int? width;
    int? height;
    String? notice;

    try {
      byteSize = await file.length();
    } catch (_) {
      notice = 'Video size could not be read; upload quality checks may warn.';
    }

    try {
      controller = VideoPlayerController.file(File(file.path));
      await controller.initialize();
      await controller.setLooping(true);
      durationMs = controller.value.duration.inMilliseconds;
      final size = controller.value.size;
      if (size.width > 0 && size.height > 0) {
        width = size.width.round();
        height = size.height.round();
      }
    } catch (_) {
      await controller?.dispose();
      controller = null;
      notice =
          'Video preview is unavailable; upload can continue if file checks pass.';
    }

    if (!mounted) {
      await controller?.dispose();
      return;
    }
    setState(() {
      _file = file;
      _source = source;
      _guideOverlay = guideOverlay;
      _cameraLensDirection = cameraLensDirection;
      _byteSize = byteSize;
      _durationMs = durationMs;
      _resolutionWidth = width;
      _resolutionHeight = height;
      _videoController = controller;
      _mediaNotice = notice;
      _error = null;
    });
  }

  Future<void> _upload(String? token) async {
    if (token == null || _file == null) return;
    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(apiClientProvider)
          .uploadSwingVideo(
            accessToken: token,
            file: _file!,
            club: _club,
            angle: _angle,
            locationType: _locationType,
            durationMs: _durationMs,
            resolutionWidth: _resolutionWidth,
            resolutionHeight: _resolutionHeight,
            captureMetadata: UploadCaptureMetadata(
              source: _source,
              guideOverlay: _guideOverlay,
              platform: _platformName,
              cameraLensDirection: _cameraLensDirection,
              nativeHighFpsAvailable: _nativeHighFpsAvailable,
              fileExtension: _fileExtension(_file!.name),
            ),
          );
      if (mounted) context.go('/swings/${session.id}');
    } catch (_) {
      setState(() {
        _error =
            'Upload failed. Confirm the backend and storage services are running.';
        _isUploading = false;
      });
    }
  }

  List<_LocalQualityCheck> get _qualityChecks {
    final file = _file;
    if (file == null) return const [];
    final extension = _fileExtension(file.name);
    final checks = <_LocalQualityCheck>[];

    if (!_supportedExtensions.contains(extension) ||
        _contentType(file.name) == null) {
      checks.add(const _LocalQualityCheck.fail('Unsupported video file type.'));
    } else {
      checks.add(const _LocalQualityCheck.pass('Supported video file type.'));
    }

    final byteSize = _byteSize;
    if (byteSize == null) {
      checks.add(const _LocalQualityCheck.warn('Video size is unknown.'));
    } else if (byteSize <= 0) {
      checks.add(const _LocalQualityCheck.fail('Video file is empty.'));
    } else if (byteSize > _maxVideoBytes) {
      checks.add(
        const _LocalQualityCheck.fail(
          'Video is larger than the 250 MB Phase 2 limit.',
        ),
      );
    } else {
      checks.add(
        const _LocalQualityCheck.pass(
          'Video size is within the Phase 2 limit.',
        ),
      );
    }

    final durationMs = _durationMs;
    if (durationMs == null) {
      checks.add(const _LocalQualityCheck.warn('Video duration is unknown.'));
    } else if (durationMs > _maxAllowedDurationMs) {
      checks.add(
        const _LocalQualityCheck.fail('Video must be 30 seconds or shorter.'),
      );
    } else if (durationMs < _minGoodDurationMs) {
      checks.add(
        const _LocalQualityCheck.warn(
          'Video is shorter than the recommended 2 seconds.',
        ),
      );
    } else if (durationMs > _maxGoodDurationMs) {
      checks.add(
        const _LocalQualityCheck.warn(
          'Video is longer than the recommended 15 seconds.',
        ),
      );
    } else {
      checks.add(
        const _LocalQualityCheck.pass('Video duration is in the guided range.'),
      );
    }

    if (_resolutionWidth == null || _resolutionHeight == null) {
      checks.add(const _LocalQualityCheck.warn('Video resolution is unknown.'));
    } else if ([
          _resolutionWidth!,
          _resolutionHeight!,
        ].reduce((a, b) => a < b ? a : b) <
        _minGoodResolutionEdge) {
      checks.add(
        const _LocalQualityCheck.warn(
          'Resolution is below the recommended 720p baseline.',
        ),
      );
    } else {
      checks.add(
        const _LocalQualityCheck.pass('Resolution meets the Phase 2 baseline.'),
      );
    }

    if (_source == 'camera' && _guideOverlay) {
      checks.add(
        const _LocalQualityCheck.pass(
          'SwingLens guide was active during recording.',
        ),
      );
    } else {
      checks.add(
        const _LocalQualityCheck.warn(
          'Gallery videos may not use the capture guide.',
        ),
      );
    }
    return checks;
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return 'unknown';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null) return 'unknown';
    return '${(durationMs / 1000).toStringAsFixed(1)} sec';
  }

  String _formatResolution() {
    if (_resolutionWidth == null || _resolutionHeight == null) return 'unknown';
    return '${_resolutionWidth}x$_resolutionHeight';
  }

  String _fileExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot == -1) return '';
    return filename.substring(dot).toLowerCase();
  }

  String? _contentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return null;
  }

  String get _platformName {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }
}

class _CapturePreview extends StatelessWidget {
  const _CapturePreview({
    required this.angle,
    required this.cameraController,
    required this.videoController,
    required this.file,
    required this.isRecording,
  });

  final String angle;
  final CameraController? cameraController;
  final VideoPlayerController? videoController;
  final XFile? file;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final cameraReady = cameraController?.value.isInitialized ?? false;
    final videoReady = videoController?.value.isInitialized ?? false;
    return AspectRatio(
      aspectRatio: 9 / 13,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cameraReady && file == null)
                CameraPreview(cameraController!)
              else if (videoReady)
                GestureDetector(
                  onTap: () {
                    if (videoController!.value.isPlaying) {
                      videoController!.pause();
                    } else {
                      videoController!.play();
                    }
                  },
                  child: VideoPlayer(videoController!),
                )
              else
                const Center(
                  child: Icon(
                    Icons.videocam_outlined,
                    size: 52,
                    color: AppColors.textSecondary,
                  ),
                ),
              CustomPaint(painter: _CaptureGuidePainter(angle: angle)),
              Positioned(
                left: 14,
                top: 14,
                child: _PreviewBadge(
                  label: isRecording
                      ? 'REC'
                      : file == null
                      ? 'READY'
                      : 'REVIEW',
                  active: isRecording,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? AppColors.textPrimary
            : Colors.black.withValues(alpha: 0.68),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: AppTextStyles.micro.copyWith(
            color: active ? Colors.black : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CaptureGuidePainter extends CustomPainter {
  const _CaptureGuidePainter({required this.angle});

  final String angle;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final mutedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    if (angle == 'face_on') {
      canvas.drawLine(
        Offset(size.width * 0.5, size.height * 0.16),
        Offset(size.width * 0.5, size.height * 0.84),
        guidePaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.18, size.height * 0.76),
        Offset(size.width * 0.82, size.height * 0.76),
        guidePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * 0.5, size.height * 0.48),
            width: size.width * 0.42,
            height: size.height * 0.48,
          ),
          const Radius.circular(8),
        ),
        mutedPaint,
      );
    } else {
      canvas.drawLine(
        Offset(size.width * 0.18, size.height * 0.78),
        Offset(size.width * 0.86, size.height * 0.36),
        guidePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.22,
            size.height * 0.32,
            size.width * 0.5,
            size.height * 0.5,
          ),
          const Radius.circular(8),
        ),
        mutedPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.5, size.height * 0.2),
        Offset(size.width * 0.5, size.height * 0.82),
        mutedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CaptureGuidePainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}

class _QualityCheckRow extends StatelessWidget {
  const _QualityCheckRow({required this.severity, required this.message});

  final String severity;
  final String message;

  @override
  Widget build(BuildContext context) {
    final icon = switch (severity) {
      'pass' => Icons.check_circle_outline,
      'fail' => Icons.error_outline,
      _ => Icons.info_outline,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textPrimary),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _LocalQualityCheck {
  const _LocalQualityCheck({required this.severity, required this.message});

  const _LocalQualityCheck.pass(String message)
    : this(severity: 'pass', message: message);

  const _LocalQualityCheck.warn(String message)
    : this(severity: 'warn', message: message);

  const _LocalQualityCheck.fail(String message)
    : this(severity: 'fail', message: message);

  final String severity;
  final String message;
}
