import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../capture/native_capture_bridge.dart';
import '../capture/tracer_readiness.dart';
import '../offline/offline_queue.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

const _maxVideoBytes = 250 * 1024 * 1024;
const _minGoodDurationMs = 2000;
const _maxGoodDurationMs = 15000;
const _maxAllowedDurationMs = 30000;
const _minGoodResolutionEdge = 720;
const _supportedExtensions = {'.mp4', '.mov', '.m4v', '.webm'};
const _fallbackClubChoices = [
  'driver',
  '3 wood',
  'hybrid',
  '5 iron',
  '7 iron',
  'wedge',
];

enum UploadMode { analysis, tracer }

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({
    this.mode = UploadMode.analysis,
    this.cameraFirst = false,
    super.key,
  });

  final UploadMode mode;
  final bool cameraFirst;

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _picker = ImagePicker();
  final _nativeCaptureBridge = const NativeCaptureBridge();

  String _club = '7 iron';
  List<String> _clubChoices = _fallbackClubChoices;
  String _angle = 'down_the_line';
  String _locationType = 'range';
  String _source = 'gallery';
  String _tracerStyle = 'signature';
  String _tracerPointMode = 'ball';
  String? _cameraLensDirection;
  bool _guideOverlay = false;
  bool _whiteBallConfirmed = false;
  bool? _nativeHighFpsAvailable;
  NativeCaptureCapabilities _nativeCaptureCapabilities =
      const NativeCaptureCapabilities(highFpsCaptureAvailable: false);
  Map<String, dynamic> _nativeCaptureDiagnostics = const {};
  bool _isNativeTracerRecording = false;
  Map<String, bool> _recordedTracerReadinessChecks = const {};
  int? _recordedStableDurationMs;
  Offset _tracerBallAnchor = const Offset(0.5, 0.78);
  Offset _tracerTargetPoint = const Offset(0.5, 0.28);

  XFile? _file;
  int? _byteSize;
  int? _durationMs;
  int? _resolutionWidth;
  int? _resolutionHeight;
  VideoPlayerController? _videoController;
  CameraController? _cameraController;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _sensorTimeoutTimer;
  DateTime? _stableSince;
  double? _lastAccelX;
  double? _lastAccelY;
  double? _lastAccelZ;
  double? _phoneLevelDegrees;
  double _stabilityScore = 0;
  int _stabilitySamples = 0;
  bool _sensorUnavailable = false;

  bool _isUploading = false;
  bool _isInitializingCamera = false;
  bool _isRecording = false;
  bool _tracerImpactWindowActive = false;
  int _tracerRecordingTenths = 0;
  Timer? _tracerRecordingTimer;
  String? _error;
  String? _mediaNotice;
  String? _cameraNotice;

  bool get _isTracerMode => widget.mode == UploadMode.tracer;
  bool get _isTracerCameraEntry => _isTracerMode && widget.cameraFirst;

  @override
  void initState() {
    super.initState();
    if (_isTracerMode) {
      _angle = 'rear_tracer';
      _club = 'driver';
      if (_isTracerCameraEntry) {
        _source = 'camera';
        _guideOverlay = true;
        _whiteBallConfirmed = true;
        unawaited(_initializeCamera());
      }
      _startTracerStabilityMonitor();
    }
    unawaited(_loadClubBagChoices());
  }

  @override
  void dispose() {
    _sensorTimeoutTimer?.cancel();
    _tracerRecordingTimer?.cancel();
    _accelerometerSubscription?.cancel();
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
    final tracerReadiness = _tracerReadiness;

    if (_isTracerCameraEntry) {
      return _buildTracerCameraFirstScreen(
        auth: auth,
        hasHardFailure: hasHardFailure,
        tracerReadiness: tracerReadiness,
      );
    }

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
              Text(
                _isTracerMode ? 'SHOT TRACER' : 'GUIDED CAPTURE',
                style: AppTextStyles.title,
              ),
              const SizedBox(height: 12),
              Text(
                _isTracerMode
                    ? 'Use the rear camera guide for auto tracking. Gallery imports are allowed for testing, but weak clips will ask for a better capture.'
                    : 'Record with a simple guide or choose a saved swing. Quality checks run before upload.',
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
                  tracerMode: _isTracerMode,
                  tracerBallAnchor: _tracerBallAnchor,
                  tracerTargetPoint: _tracerTargetPoint,
                  tracerStyle: _tracerStyle,
                  tracerPointMode: _tracerPointMode,
                  handedness:
                      auth.profile?.handedness?.toLowerCase() ?? 'right',
                  onTracerPointChanged: _isTracerMode
                      ? _updateTracerPoint
                      : null,
                ),
                const SizedBox(height: 18),
                _buildSourceActions(tracerReadiness),
                if (_cameraNotice != null) ...[
                  const SizedBox(height: 12),
                  InfoPanel(children: [Text(_cameraNotice!)]),
                ],
                const SizedBox(height: 18),
                if (_isTracerMode) ...[
                  _buildTracerSetupPanel(
                    auth.profile?.handedness,
                    tracerReadiness,
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  const Text('ANGLE', style: AppTextStyles.label),
                  const SizedBox(height: 10),
                  SegmentedChoices(
                    values: const ['face_on', 'down_the_line'],
                    selected: _angle,
                    onSelected: (value) => setState(() => _angle = value),
                  ),
                  const SizedBox(height: 18),
                ],
                const Text('CLUB', style: AppTextStyles.label),
                const SizedBox(height: 10),
                SegmentedChoices(
                  values: _clubChoices,
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
                  label: _isUploading
                      ? 'UPLOADING'
                      : _isTracerMode
                      ? 'UPLOAD TRACER VIDEO'
                      : 'UPLOAD SWING',
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

  Widget _buildTracerCameraFirstScreen({
    required AuthState auth,
    required bool hasHardFailure,
    required TracerReadinessResult tracerReadiness,
  }) {
    final handedness = auth.profile?.handedness?.toLowerCase() ?? 'right';
    final cameraReady = _cameraController?.value.isInitialized ?? false;
    final fileReady = _file != null;
    final recordEnabled =
        _isRecording || (!_isInitializingCamera && cameraReady && !fileReady);
    final recordLabel = _tracerRecordLabel(cameraReady, tracerReadiness);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _TracerCameraOnlyPreview(
                angle: _angle,
                cameraController: _cameraController,
                videoController: _videoController,
                file: _file,
                isRecording: _isRecording,
                status: _tracerLiveStatus(cameraReady, tracerReadiness),
                timer: _tracerRecordingTimerLabel,
                cameraNotice: _cameraNotice ?? _mediaNotice ?? _error,
                tracerBallAnchor: _tracerBallAnchor,
                tracerTargetPoint: _tracerTargetPoint,
                tracerStyle: _tracerStyle,
                tracerPointMode: _tracerPointMode,
                handedness: handedness,
                onBack: () => context.go('/tracer'),
                onTracerPointChanged: _updateTracerPoint,
              ),
            ),
            _TracerCameraControls(
              fileReady: fileReady,
              recording: _isRecording,
              uploading: _isUploading,
              recordEnabled: recordEnabled,
              uploadEnabled: fileReady && !hasHardFailure && !_isUploading,
              recordLabel: recordLabel,
              status: _tracerLiveStatus(cameraReady, tracerReadiness),
              onRecord: _recordOrStop,
              onRetake: _retakeTracerCapture,
              onUseVideo: () => _upload(auth.accessToken),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadClubBagChoices() async {
    final token = ref.read(authControllerProvider).state.accessToken;
    if (token == null) return;
    try {
      final clubs = await ref
          .read(apiClientProvider)
          .getClubBag(token, activeOnly: true);
      final labels = clubs
          .where((club) => club.label.trim().isNotEmpty)
          .map((club) => club.label.trim())
          .toList();
      if (!mounted || labels.isEmpty) return;
      setState(() {
        _clubChoices = labels;
        if (!_clubChoices.contains(_club)) {
          _club = _isTracerMode && _clubChoices.contains('Driver')
              ? 'Driver'
              : _clubChoices.first;
        }
      });
    } catch (_) {
      // Keep the built-in club selector when profile club bag is unavailable.
    }
  }

  Widget _buildSourceActions(TracerReadinessResult tracerReadiness) {
    final cameraNeedsOpening =
        _isTracerMode && !(_cameraController?.value.isInitialized ?? false);
    final recordDisabled =
        _isInitializingCamera ||
        (_isTracerMode &&
            !_isRecording &&
            !cameraNeedsOpening &&
            !tracerReadiness.canRecord);
    return Row(
      children: [
        Expanded(
          child: GhostButton(
            label: _isRecording
                ? 'STOP RECORDING'
                : _isInitializingCamera
                ? 'OPENING CAMERA'
                : cameraNeedsOpening
                ? 'OPEN CAMERA'
                : tracerReadiness.unverifiedTestCapture
                ? 'UNVERIFIED TEST CAPTURE'
                : 'RECORD VIDEO',
            onPressed: recordDisabled ? null : _recordOrStop,
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

  String _tracerRecordLabel(bool cameraReady, TracerReadinessResult readiness) {
    if (_file != null) return 'VIDEO READY';
    if (_isRecording) return 'STOP RECORDING';
    if (_isInitializingCamera) return 'OPENING CAMERA';
    if (!cameraReady) return 'CAMERA UNAVAILABLE';
    if (_isTracerCameraEntry) return 'TAP TO RECORD';
    if (!readiness.canRecord) return 'HOLD FRAME STEADY';
    return 'START RECORDING';
  }

  String _tracerLiveStatus(bool cameraReady, TracerReadinessResult readiness) {
    if (_file != null) return 'VIDEO READY';
    if (_isRecording && _tracerImpactWindowActive) return 'IMPACT WINDOW';
    if (_isRecording) return 'WAITING FOR IMPACT';
    if (_isInitializingCamera) return 'OPENING CAMERA';
    if (!cameraReady) return 'CAMERA UNAVAILABLE';
    if (_isTracerCameraEntry) return 'SHOT TRACER';
    if (readiness.canRecord) return 'RANGE READY';
    return 'LOCK BALL AND TARGET';
  }

  String get _tracerRecordingTimerLabel {
    final seconds = _tracerRecordingTenths ~/ 10;
    final tenths = _tracerRecordingTenths % 10;
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}.$tenths';
  }

  Widget _buildReviewPanel(List<_LocalQualityCheck> qualityChecks) {
    final tracerReadiness = _effectiveTracerReadiness;
    return InfoPanel(
      children: [
        Text('FILE: ${_file!.name}'),
        Text('SOURCE: ${_source.toUpperCase()}'),
        Text('SIZE: ${_formatBytes(_byteSize)}'),
        Text('DURATION: ${_formatDuration(_durationMs)}'),
        Text('RESOLUTION: ${_formatResolution()}'),
        if (_isTracerMode) ...[
          Text('BALL: ${_formatPoint(_tracerBallAnchor)}'),
          Text('TARGET: ${_formatPoint(_tracerTargetPoint)}'),
          Text('STYLE: ${_tracerStyle.replaceAll('_', ' ').toUpperCase()}'),
          Text('AUTO ELIGIBLE: ${tracerReadiness.autoEligible ? 'YES' : 'NO'}'),
          Text(
            'STABLE HOLD: ${(_effectiveStableDurationMs / 1000).toStringAsFixed(1)} SEC',
          ),
          Text('TRACER CAMERA: ${_nativeCaptureCapabilities.readinessLabel}'),
          if (_nativeCaptureDiagnostics.isNotEmpty) ...[
            Text(
              'NATIVE MODE: ${_nativeCaptureDiagnostics['formatLabel'] ?? 'UNKNOWN'}',
            ),
            Text(
              'MEASURED FPS: ${_formatNumber(_nativeCaptureDiagnostics['measuredFps'])}',
            ),
            Text(
              'DROPPED FRAMES: ${_nativeCaptureDiagnostics['droppedFrameCount'] ?? 0}',
            ),
          ],
        ],
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

  Widget _buildTracerSetupPanel(
    String? handedness,
    TracerReadinessResult readiness,
  ) {
    final checks = _tracerAlignmentChecks(handedness);
    return InfoPanel(
      children: [
        const Text('TRACER SETUP', style: AppTextStyles.label),
        const Text('ANGLE: REAR TRACER'),
        Text('TRACER CAMERA: ${_nativeCaptureCapabilities.readinessLabel}'),
        Text(
          'MODE: ${_nativeCaptureCapabilities.preferredMode ?? 'diagnostic'}',
        ),
        const Text('Tap or drag on the preview to set the selected marker.'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _whiteBallConfirmed,
          onChanged: (value) =>
              setState(() => _whiteBallConfirmed = value ?? false),
          title: const Text('WHITE BALL', style: AppTextStyles.label),
          subtitle: const Text('Auto tracking requires a visible white ball.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        SegmentedChoices(
          values: const ['ball', 'target'],
          selected: _tracerPointMode,
          onSelected: (value) => setState(() => _tracerPointMode = value),
        ),
        const Text('TRACER STYLE', style: AppTextStyles.label),
        SegmentedChoices(
          values: const ['signature', 'broadcast_white', 'power_red'],
          selected: _tracerStyle,
          onSelected: (value) => setState(() => _tracerStyle = value),
        ),
        _AlignmentRow(label: 'BALL VISIBLE', passed: checks['ball_visible']!),
        _AlignmentRow(
          label: 'BALL IN LAUNCH ZONE',
          passed: readiness.checks['ball_anchor_launch_zone']!,
        ),
        _AlignmentRow(
          label: 'GOLFER IN FRAME',
          passed: checks['golfer_in_frame']!,
        ),
        _AlignmentRow(
          label: 'TARGET LINE SET',
          passed: readiness.checks['target_line_set']!,
        ),
        _AlignmentRow(
          label: 'TARGET FORWARD',
          passed: readiness.checks['target_line_forward']!,
        ),
        _AlignmentRow(
          label: 'REAR CAMERA ACTIVE',
          passed: readiness.checks['rear_camera_active']!,
        ),
        _AlignmentRow(
          label: 'WHITE BALL CONFIRMED',
          passed: readiness.checks['white_ball_confirmed']!,
        ),
        _AlignmentRow(
          label:
              'PHONE LEVEL ${_phoneLevelDegrees == null ? '' : '${_phoneLevelDegrees!.toStringAsFixed(1)}°'}',
          passed: readiness.checks['phone_level']!,
        ),
        _AlignmentRow(
          label: 'PHONE STABLE',
          passed: readiness.checks['phone_stable']!,
        ),
        _AlignmentRow(
          label: 'HELD STILL 1 SEC',
          passed: readiness.checks['stable_duration_1s']!,
        ),
        _AlignmentRow(label: 'RANGE READY', passed: readiness.autoEligible),
        if (readiness.unverifiedTestCapture)
          const Text(
            'UNVERIFIED TEST CAPTURE: motion sensors are unavailable, so this upload will not be auto-eligible.',
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

  Future<void> _retakeTracerCapture() async {
    await _videoController?.dispose();
    if (!mounted) return;
    setState(() {
      _file = null;
      _videoController = null;
      _byteSize = null;
      _durationMs = null;
      _resolutionWidth = null;
      _resolutionHeight = null;
      _mediaNotice = null;
      _error = null;
      _source = 'camera';
      _guideOverlay = true;
      _tracerImpactWindowActive = false;
      _tracerRecordingTenths = 0;
      _recordedTracerReadinessChecks = const {};
      _recordedStableDurationMs = null;
    });
    if (!(_cameraController?.value.isInitialized ?? false)) {
      await _initializeCamera();
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initializeCamera();
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isTracerMode && !_isTracerCameraEntry && !_tracerReadiness.canRecord) {
      setState(() {
        _cameraNotice =
            'Complete the tracer readiness checks before recording.';
      });
      return;
    }
    final recordingReadiness = _tracerReadiness;
    final recordingStableDurationMs = _stableDurationMs;

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
        _recordedTracerReadinessChecks = _isTracerMode
            ? Map<String, bool>.from(recordingReadiness.checks)
            : const {};
        _recordedStableDurationMs = _isTracerMode
            ? recordingStableDurationMs
            : null;
      });
      if (_isTracerMode && _nativeCaptureCapabilities.trustedForTracer) {
        await _cameraController?.dispose();
        _cameraController = null;
        await _nativeCaptureBridge.startTracerCapture();
        setState(() {
          _isRecording = true;
          _tracerImpactWindowActive = false;
          _tracerRecordingTenths = 0;
          _isNativeTracerRecording = true;
          _source = 'native_camera';
          _guideOverlay = true;
          _cameraLensDirection = 'back';
          _cameraNotice = null;
          _error = null;
        });
        _startTracerRecordingClock();
        return;
      }
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _tracerImpactWindowActive = false;
        _tracerRecordingTenths = 0;
        _isNativeTracerRecording = false;
        _cameraNotice = null;
        _error = null;
      });
      _startTracerRecordingClock();
    } catch (_) {
      setState(() {
        _cameraNotice = _isTracerCameraEntry
            ? 'Camera recording is unavailable here. Return to Shot Tracer to import a video.'
            : 'Camera recording is unavailable on this device. Choose a saved video instead.';
      });
    }
  }

  void _startTracerRecordingClock() {
    if (!_isTracerMode) return;
    _tracerRecordingTimer?.cancel();
    _tracerRecordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) {
      if (!mounted || !_isRecording) return;
      setState(() {
        _tracerRecordingTenths += 1;
        if (_tracerRecordingTenths >= 18) {
          _tracerImpactWindowActive = true;
        }
      });
    });
  }

  Future<void> _stopRecording() async {
    _tracerRecordingTimer?.cancel();
    if (_isNativeTracerRecording) {
      try {
        final result = await _nativeCaptureBridge.stopTracerCapture();
        setState(() {
          _isRecording = false;
          _tracerImpactWindowActive = true;
          _isNativeTracerRecording = false;
          _nativeCaptureDiagnostics = result.diagnostics;
          _cameraLensDirection = 'back';
        });
        await _prepareVideo(
          XFile(result.filePath),
          source: 'native_camera',
          guideOverlay: true,
          cameraLensDirection: 'back',
        );
      } catch (_) {
        setState(() {
          _isRecording = false;
          _isNativeTracerRecording = false;
          _cameraNotice = _isTracerCameraEntry
              ? 'Native high-FPS recording could not be saved. Try recording again or return to Shot Tracer to import a video.'
              : 'Native high-FPS recording could not be saved. Try recording again.';
        });
      }
      return;
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) return;
    try {
      final video = await controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _tracerImpactWindowActive = true;
      });
      await _prepareVideo(
        video,
        source: 'camera',
        guideOverlay: true,
        cameraLensDirection: _cameraLensDirection,
      );
    } catch (_) {
      setState(() {
        _isRecording = false;
        _cameraNotice = _isTracerCameraEntry
            ? 'Recording could not be saved. Try recording again or return to Shot Tracer to import a video.'
            : 'Recording could not be saved. Choose a saved video or try recording again.';
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
          _cameraNotice = _isTracerCameraEntry
              ? 'No camera is available here. Return to Shot Tracer to import a video.'
              : 'No camera is available here. Choose a saved video to keep testing.';
          _isInitializingCamera = false;
          _nativeHighFpsAvailable = capabilities.highFpsCaptureAvailable;
          _nativeCaptureCapabilities = capabilities;
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
        _nativeCaptureCapabilities = capabilities;
        _isInitializingCamera = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraNotice = _isTracerCameraEntry
            ? 'Camera is unavailable here. Return to Shot Tracer to import a video.'
            : 'Camera is unavailable here. Choose a saved video to keep testing.';
        _isInitializingCamera = false;
      });
    }
  }

  void _startTracerStabilityMonitor() {
    _sensorTimeoutTimer?.cancel();
    _sensorTimeoutTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _stabilitySamples > 0) return;
      setState(() => _sensorUnavailable = true);
    });
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen(
          _handleAccelerometerEvent,
          onError: (_) {
            if (!mounted) return;
            setState(() => _sensorUnavailable = true);
          },
        );
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (magnitude <= 0) return;
    final levelDegrees =
        math.asin((event.x / magnitude).clamp(-1.0, 1.0)).abs() * 180 / math.pi;
    final previousX = _lastAccelX;
    final previousY = _lastAccelY;
    final previousZ = _lastAccelZ;
    var delta = 0.0;
    if (previousX != null && previousY != null && previousZ != null) {
      final dx = event.x - previousX;
      final dy = event.y - previousY;
      final dz = event.z - previousZ;
      delta = math.sqrt(dx * dx + dy * dy + dz * dz);
    }
    final sampleScore = (1 - delta / 1.2).clamp(0.0, 1.0).toDouble();
    final sampleStable = levelDegrees <= 6 && sampleScore >= 0.72;
    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      _sensorUnavailable = false;
      _lastAccelX = event.x;
      _lastAccelY = event.y;
      _lastAccelZ = event.z;
      _phoneLevelDegrees = levelDegrees;
      _stabilityScore = _stabilitySamples == 0
          ? sampleScore
          : (_stabilityScore * 0.72 + sampleScore * 0.28);
      _stabilitySamples = sampleStable
          ? (_stabilitySamples + 1).clamp(0, 120).toInt()
          : 0;
      _stableSince = sampleStable ? (_stableSince ?? now) : null;
    });
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
      if (source != 'native_camera') {
        _nativeCaptureDiagnostics = const {};
      }
      if (!_isTracerMode || source == 'gallery') {
        _recordedTracerReadinessChecks = const {};
        _recordedStableDurationMs = null;
      }
      _error = null;
    });
  }

  Future<void> _upload(String? token) async {
    if (token == null || _file == null) return;
    final captureMetadata = UploadCaptureMetadata(
      source: _source,
      guideOverlay: _guideOverlay,
      platform: _platformName,
      cameraLensDirection: _cameraLensDirection,
      nativeHighFpsAvailable: _nativeHighFpsAvailable,
      fileExtension: _fileExtension(_file!.name),
      tracer: _isTracerMode ? _tracerMetadata() : null,
    );
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
            sessionType: _isTracerMode ? 'tracer' : 'analysis',
            captureMetadata: captureMetadata,
          );
      if (mounted) context.go('/swings/${session.id}');
    } catch (error) {
      if (shouldQueueOffline(error)) {
        await ref
            .read(offlineQueueProvider)
            .enqueueSwingUpload(
              file: _file!,
              club: _club,
              angle: _angle,
              locationType: _locationType,
              sessionType: _isTracerMode ? 'tracer' : 'analysis',
              durationMs: _durationMs,
              resolutionWidth: _resolutionWidth,
              resolutionHeight: _resolutionHeight,
              captureMetadata: captureMetadata.toJson(),
            );
        if (!mounted) return;
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload saved offline. Sync it later.')),
        );
        context.go('/profile/sync');
        return;
      }
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

    if (_usesGuidedCameraSource && _guideOverlay) {
      checks.add(
        const _LocalQualityCheck.pass(
          'SwingLens guide was active during recording.',
        ),
      );
    } else {
      checks.add(
        _LocalQualityCheck.warn(
          _isTracerMode
              ? 'Auto shot tracer is strongest with guided rear-camera capture.'
              : 'Gallery videos may not use the capture guide.',
        ),
      );
    }
    return checks;
  }

  TracerReadinessResult get _tracerReadiness {
    final cameraReady = _cameraController?.value.isInitialized ?? false;
    final rearCameraActive = _cameraLensDirection == 'back';
    final targetLineSet =
        (_tracerTargetPoint - _tracerBallAnchor).distanceSquared > 0.015;
    final ballAnchorSet = _pointInGuideBounds(_tracerBallAnchor);
    final ballAnchorLaunchZone = _pointInLaunchZone(_tracerBallAnchor);
    final targetLineForward = _targetLineForward;
    final sensorVerified = !_sensorUnavailable && _stabilitySamples > 0;
    final phoneLevel = _phoneLevelDegrees != null && _phoneLevelDegrees! <= 6;
    final stableDurationMs = _stableDurationMs;
    final phoneStable =
        _stableSince != null &&
        stableDurationMs >= 1000 &&
        _stabilityScore >= 0.72 &&
        _stabilitySamples >= 8;
    final guideOverlay =
        _liveTracerGuideActive || (_usesGuidedCameraSource && _guideOverlay);
    return buildTracerReadiness(
      TracerReadinessInput(
        cameraReady: cameraReady,
        rearCameraActive: rearCameraActive,
        guideOverlay: guideOverlay,
        ballAnchorSet: ballAnchorSet,
        ballAnchorLaunchZone: ballAnchorLaunchZone,
        targetLineSet: targetLineSet,
        targetLineForward: targetLineForward,
        whiteBallConfirmed: _whiteBallConfirmed,
        sensorVerified: sensorVerified,
        phoneLevel: phoneLevel,
        phoneStable: phoneStable,
        simulatorOrUnverified: _sensorUnavailable,
        stableDurationMs: stableDurationMs,
      ),
    );
  }

  TracerReadinessResult get _effectiveTracerReadiness {
    if (_file != null && _recordedTracerReadinessChecks.isNotEmpty) {
      return TracerReadinessResult(checks: _recordedTracerReadinessChecks);
    }
    return _tracerReadiness;
  }

  int get _effectiveStableDurationMs {
    if (_file != null && _recordedStableDurationMs != null) {
      return _recordedStableDurationMs!;
    }
    return _stableDurationMs;
  }

  int get _stableDurationMs {
    final stableSince = _stableSince;
    if (stableSince == null) return 0;
    return DateTime.now().difference(stableSince).inMilliseconds;
  }

  bool get _liveTracerGuideActive {
    return _isTracerMode &&
        _file == null &&
        (_cameraController?.value.isInitialized ?? false);
  }

  bool _pointInGuideBounds(Offset point) {
    return point.dx >= 0.08 &&
        point.dx <= 0.92 &&
        point.dy >= 0.08 &&
        point.dy <= 0.92;
  }

  bool _pointInLaunchZone(Offset point) {
    return point.dx >= 0.18 &&
        point.dx <= 0.82 &&
        point.dy >= 0.55 &&
        point.dy <= 0.92;
  }

  bool get _targetLineForward {
    return _tracerTargetPoint.dy <= _tracerBallAnchor.dy - 0.12;
  }

  bool get _usesGuidedCameraSource {
    return _source == 'camera' || _source == 'native_camera';
  }

  void _updateTracerPoint(Offset normalizedPoint) {
    final clamped = Offset(
      normalizedPoint.dx.clamp(0.08, 0.92).toDouble(),
      normalizedPoint.dy.clamp(0.08, 0.92).toDouble(),
    );
    setState(() {
      if (_tracerPointMode == 'target') {
        _tracerTargetPoint = clamped;
      } else {
        _tracerBallAnchor = clamped;
      }
    });
  }

  Map<String, dynamic> _tracerMetadata() {
    final handedness =
        ref.read(authControllerProvider).state.profile?.handedness ?? 'right';
    final checks = _tracerAlignmentChecks(handedness);
    final readiness = _effectiveTracerReadiness;
    final stableDurationMs = _effectiveStableDurationMs;
    final nativeCapture = _nativeCaptureMetadata();
    return {
      'ball_anchor': _pointJson(_tracerBallAnchor),
      'target_line': {
        'start': _pointJson(_tracerBallAnchor),
        'end': _pointJson(_tracerTargetPoint),
      },
      'handedness': handedness,
      'guide_version': 'phase6_12_range_tracer_guide_v1',
      'capture_source': _source,
      'auto_eligible': readiness.autoEligible,
      'readiness_checks': readiness.checks,
      'phone_level_degrees': _phoneLevelDegrees,
      'stability_score': double.parse(_stabilityScore.toStringAsFixed(3)),
      'stability_samples': _stabilitySamples,
      'stable_duration_ms': stableDurationMs,
      'white_ball_confirmed': _whiteBallConfirmed,
      'simulator_or_unverified': readiness.checks['simulator_or_unverified'],
      'native_capture': nativeCapture,
      'capture_quality': {
        'source_type': _source,
        'guide_overlay': _guideOverlay,
        'camera_lens_direction': _cameraLensDirection,
        'phone_stability': readiness.autoEligible ? 'stable' : 'unverified',
        'phone_level_degrees': _phoneLevelDegrees,
        'stability_score': double.parse(_stabilityScore.toStringAsFixed(3)),
        'stability_samples': _stabilitySamples,
        'stable_duration_ms': stableDurationMs,
        'white_ball_confirmed': _whiteBallConfirmed,
        'simulator_or_unverified': readiness.checks['simulator_or_unverified'],
        'duration_ms': _durationMs,
        'resolution_width': _resolutionWidth,
        'resolution_height': _resolutionHeight,
        'native_capture': nativeCapture,
        'measured_fps': nativeCapture['measured_fps'],
        'target_fps': nativeCapture['target_fps'],
        'device_tier': nativeCapture['device_tier'],
        'native_sample_count': nativeCapture['sample_count'],
        'dropped_frame_count': nativeCapture['dropped_frame_count'],
      },
      'style': {'name': _tracerStyle},
      'alignment_checks': checks,
    };
  }

  Map<String, dynamic> _nativeCaptureMetadata() {
    final diagnostics = _nativeCaptureDiagnostics;
    return {
      'source': diagnostics['source'] ?? 'flutter_camera',
      'device_tier':
          diagnostics['deviceTier'] ?? _nativeCaptureCapabilities.deviceTier,
      'device_model':
          diagnostics['deviceModel'] ?? _nativeCaptureCapabilities.deviceModel,
      'system_version':
          diagnostics['systemVersion'] ??
          _nativeCaptureCapabilities.systemVersion,
      'format_label':
          diagnostics['formatLabel'] ??
          _nativeCaptureCapabilities.preferredMode,
      'target_fps':
          diagnostics['targetFps'] ??
          _nativeCaptureCapabilities.selectedFormat['targetFps'],
      'measured_fps': diagnostics['measuredFps'],
      'width': diagnostics['width'],
      'height': diagnostics['height'],
      'lens_position': diagnostics['lensPosition'],
      'lens_device_type': diagnostics['lensDeviceType'],
      'stabilization_supported': diagnostics['stabilizationSupported'],
      'focus_locked': diagnostics['focusLocked'],
      'exposure_locked': diagnostics['exposureLocked'],
      'white_balance_locked': diagnostics['whiteBalanceLocked'],
      'exposure_duration_seconds': diagnostics['exposureDurationSeconds'],
      'iso': diagnostics['iso'],
      'sample_count': diagnostics['sampleCount'] ?? 0,
      'dropped_frame_count': diagnostics['droppedFrameCount'] ?? 0,
      'first_frame_timestamp_ms': diagnostics['firstFrameTimestampMs'],
      'last_frame_timestamp_ms': diagnostics['lastFrameTimestampMs'],
      'started_at_ms': diagnostics['startedAtMs'],
    };
  }

  Map<String, bool> _tracerAlignmentChecks(String? handedness) {
    final hasTarget =
        (_tracerTargetPoint - _tracerBallAnchor).distanceSquared > 0.015;
    return {
      'ball_visible': _file != null || _cameraController != null,
      'golfer_in_frame': handedness != null || _file != null,
      'ball_anchor_launch_zone': _pointInLaunchZone(_tracerBallAnchor),
      'target_line_set': hasTarget,
      'target_line_forward': _targetLineForward,
      'phone_level': _effectiveTracerReadiness.checks['phone_level'] ?? false,
    };
  }

  Map<String, double> _pointJson(Offset point) {
    return {
      'x': double.parse(point.dx.toStringAsFixed(4)),
      'y': double.parse(point.dy.toStringAsFixed(4)),
    };
  }

  String _formatPoint(Offset point) {
    return '${(point.dx * 100).toStringAsFixed(0)}%, ${(point.dy * 100).toStringAsFixed(0)}%';
  }

  String _formatNumber(Object? value) {
    final number = value is num ? value.toDouble() : null;
    if (number == null) return 'UNKNOWN';
    return number.toStringAsFixed(1);
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

class _TracerCameraOnlyPreview extends StatelessWidget {
  const _TracerCameraOnlyPreview({
    required this.angle,
    required this.cameraController,
    required this.videoController,
    required this.file,
    required this.isRecording,
    required this.status,
    required this.timer,
    required this.cameraNotice,
    required this.tracerBallAnchor,
    required this.tracerTargetPoint,
    required this.tracerStyle,
    required this.tracerPointMode,
    required this.handedness,
    required this.onBack,
    required this.onTracerPointChanged,
  });

  final String angle;
  final CameraController? cameraController;
  final VideoPlayerController? videoController;
  final XFile? file;
  final bool isRecording;
  final String status;
  final String timer;
  final String? cameraNotice;
  final Offset tracerBallAnchor;
  final Offset tracerTargetPoint;
  final String tracerStyle;
  final String tracerPointMode;
  final String handedness;
  final VoidCallback onBack;
  final ValueChanged<Offset> onTracerPointChanged;

  @override
  Widget build(BuildContext context) {
    final cameraReady = cameraController?.value.isInitialized ?? false;
    final videoReady = videoController?.value.isInitialized ?? false;
    return ClipRect(
      key: const ValueKey('tracer-camera-only-preview'),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraReady && file == null)
              CameraPreview(cameraController!)
            else if (videoReady)
              _FullBleedVideoPreview(controller: videoController!)
            else
              _CameraOnlyPlaceholder(status: status),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB8000000),
                    Color(0x18000000),
                    Color(0xD8000000),
                  ],
                  stops: [0, 0.46, 1],
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) =>
                  _handleTracerPoint(details.localPosition, context),
              onPanUpdate: (details) =>
                  _handleTracerPoint(details.localPosition, context),
              child: CustomPaint(
                painter: _CaptureGuidePainter(
                  angle: angle,
                  isRecording: isRecording,
                  tracerMode: true,
                  tracerBallAnchor: tracerBallAnchor,
                  tracerTargetPoint: tracerTargetPoint,
                  tracerStyle: tracerStyle,
                  tracerPointMode: tracerPointMode,
                  handedness: handedness,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: _TracerCameraHud(
                status: status,
                timer: timer,
                recording: isRecording,
                onBack: onBack,
              ),
            ),
            if (cameraNotice != null)
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: _CameraOnlyNotice(message: cameraNotice!),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTracerPoint(Offset localPosition, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return;
    onTracerPointChanged(
      Offset(
        localPosition.dx / box.size.width,
        localPosition.dy / box.size.height,
      ),
    );
  }
}

class _FullBleedVideoPreview extends StatelessWidget {
  const _FullBleedVideoPreview({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.isEmpty) return VideoPlayer(controller);
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _CameraOnlyPlaceholder extends StatelessWidget {
  const _CameraOnlyPlaceholder({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_outlined,
            size: 54,
            color: AppColors.textSecondary.withValues(alpha: 0.72),
          ),
          const SizedBox(height: 14),
          Text(
            status,
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TracerCameraHud extends StatelessWidget {
  const _TracerCameraHud({
    required this.status,
    required this.timer,
    required this.recording,
    required this.onBack,
  });

  final String status;
  final String timer;
  final bool recording;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('tracer-camera-back'),
          tooltip: 'Back',
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            foregroundColor: AppColors.textPrimary,
          ),
          icon: const Icon(Icons.close),
        ),
        Expanded(
          child: Center(
            child: Text(
              timer,
              style: AppTextStyles.title.copyWith(
                fontSize: 24,
                height: 1,
                letterSpacing: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        _TracerCameraHudPill(label: status, active: recording),
      ],
    );
  }
}

class _TracerCameraHudPill extends StatelessWidget {
  const _TracerCameraHudPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0x88FF5B5B) : const Color(0x24FFFFFF),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          active ? 'REC' : label,
          style: AppTextStyles.micro.copyWith(
            color: active ? AppColors.signalRed : AppColors.textPrimary,
            fontSize: 10,
            letterSpacing: 0.9,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _CameraOnlyNotice extends StatelessWidget {
  const _CameraOnlyNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _TracerCameraControls extends StatelessWidget {
  const _TracerCameraControls({
    required this.fileReady,
    required this.recording,
    required this.uploading,
    required this.recordEnabled,
    required this.uploadEnabled,
    required this.recordLabel,
    required this.status,
    required this.onRecord,
    required this.onRetake,
    required this.onUseVideo,
  });

  final bool fileReady;
  final bool recording;
  final bool uploading;
  final bool recordEnabled;
  final bool uploadEnabled;
  final String recordLabel;
  final String status;
  final VoidCallback onRecord;
  final VoidCallback onRetake;
  final VoidCallback onUseVideo;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return DecoratedBox(
      key: const ValueKey('tracer-camera-control-bar'),
      decoration: const BoxDecoration(
        color: Color(0xFF050505),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          16,
          22,
          math.max(18.0, bottomInset + 14.0),
        ),
        child: fileReady ? _buildReviewActions() : _buildRecordActions(),
      ),
    );
  }

  Widget _buildRecordActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CameraRecordButton(
          recording: recording,
          enabled: recordEnabled,
          onPressed: onRecord,
        ),
        const SizedBox(height: 12),
        Text(
          recordLabel,
          style: AppTextStyles.label.copyWith(
            color: recordEnabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          status,
          style: AppTextStyles.micro.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          uploading ? 'UPLOADING' : 'VIDEO READY',
          style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: GhostButton(label: 'RETAKE', onPressed: onRetake),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: uploading ? 'UPLOADING' : 'USE VIDEO',
                onPressed: uploadEnabled ? onUseVideo : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CameraRecordButton extends StatelessWidget {
  const _CameraRecordButton({
    required this.recording,
    required this.enabled,
    required this.onPressed,
  });

  final bool recording;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final activeColor = recording ? AppColors.signalRed : AppColors.signalRed;
    return GestureDetector(
      key: const ValueKey('tracer-camera-main-record'),
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.46,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textPrimary, width: 6),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: recording ? 34 : 68,
              height: recording ? 34 : 68,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(recording ? 9 : 999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CapturePreview extends StatelessWidget {
  const _CapturePreview({
    required this.angle,
    required this.cameraController,
    required this.videoController,
    required this.file,
    required this.isRecording,
    required this.tracerMode,
    required this.tracerBallAnchor,
    required this.tracerTargetPoint,
    required this.tracerStyle,
    required this.tracerPointMode,
    required this.handedness,
    this.onTracerPointChanged,
  });

  final String angle;
  final CameraController? cameraController;
  final VideoPlayerController? videoController;
  final XFile? file;
  final bool isRecording;
  final bool tracerMode;
  final Offset tracerBallAnchor;
  final Offset tracerTargetPoint;
  final String tracerStyle;
  final String tracerPointMode;
  final String handedness;
  final ValueChanged<Offset>? onTracerPointChanged;

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
                    if (tracerMode) return;
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
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: tracerMode
                    ? (details) =>
                          _handleTracerPoint(details.localPosition, context)
                    : null,
                onPanUpdate: tracerMode
                    ? (details) =>
                          _handleTracerPoint(details.localPosition, context)
                    : null,
                child: CustomPaint(
                  painter: _CaptureGuidePainter(
                    angle: angle,
                    isRecording: isRecording,
                    tracerMode: tracerMode,
                    tracerBallAnchor: tracerBallAnchor,
                    tracerTargetPoint: tracerTargetPoint,
                    tracerStyle: tracerStyle,
                    tracerPointMode: tracerPointMode,
                    handedness: handedness,
                  ),
                ),
              ),
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

  void _handleTracerPoint(Offset localPosition, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return;
    onTracerPointChanged?.call(
      Offset(
        localPosition.dx / box.size.width,
        localPosition.dy / box.size.height,
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
  const _CaptureGuidePainter({
    required this.angle,
    required this.isRecording,
    required this.tracerMode,
    required this.tracerBallAnchor,
    required this.tracerTargetPoint,
    required this.tracerStyle,
    required this.tracerPointMode,
    required this.handedness,
  });

  final String angle;
  final bool isRecording;
  final bool tracerMode;
  final Offset tracerBallAnchor;
  final Offset tracerTargetPoint;
  final String tracerStyle;
  final String tracerPointMode;
  final String handedness;

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

    if (tracerMode || angle == 'rear_tracer') {
      _paintTracerGuide(canvas, size);
    } else if (angle == 'face_on') {
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

  void _paintTracerGuide(Canvas canvas, Size size) {
    final silhouetteAlpha = isRecording ? 0.12 : 0.34;
    final guideAlpha = isRecording ? 0.46 : 0.78;
    final accent = _tracerGuideAccent(tracerStyle);
    final linePaint = Paint()
      ..color = accent.withValues(alpha: guideAlpha)
      ..strokeWidth = tracerStyle == 'thin_line' ? 1.4 : 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final markerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    final markerStroke = Paint()
      ..color = accent.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final silhouettePaint = Paint()
      ..color = Colors.white.withValues(alpha: silhouetteAlpha)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (!isRecording) {
      _drawGolferSilhouette(
        canvas,
        size,
        Rect.fromLTWH(
          handedness == 'left' ? size.width * 0.52 : size.width * 0.16,
          size.height * 0.26,
          size.width * 0.32,
          size.height * 0.54,
        ),
        silhouettePaint,
        flip: handedness == 'left',
      );
    }

    final ball = Offset(
      tracerBallAnchor.dx * size.width,
      tracerBallAnchor.dy * size.height,
    );
    final target = Offset(
      tracerTargetPoint.dx * size.width,
      tracerTargetPoint.dy * size.height,
    );
    canvas.drawLine(ball, target, linePaint);
    _drawArrowHead(canvas, ball, target, linePaint);
    canvas.drawCircle(ball, 16, markerPaint);
    canvas.drawCircle(ball, 16, markerStroke);
    canvas.drawCircle(target, 10, markerPaint);
    canvas.drawCircle(target, 10, markerStroke);

    final selected = tracerPointMode == 'target' ? target : ball;
    canvas.drawCircle(
      selected,
      tracerPointMode == 'target' ? 15 : 21,
      Paint()
        ..color = accent.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill,
    );

    final cornerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const inset = 10.0;
    const length = 26.0;
    canvas.drawLine(
      Offset(inset, inset),
      Offset(inset + length, inset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(inset, inset),
      Offset(inset, inset + length),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset - length, inset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + length),
      cornerPaint,
    );
  }

  void _drawGolferSilhouette(
    Canvas canvas,
    Size size,
    Rect rect,
    Paint paint, {
    required bool flip,
  }) {
    double x(double value) => flip
        ? rect.right - (rect.width * value)
        : rect.left + (rect.width * value);
    double y(double value) => rect.top + (rect.height * value);
    final head = Offset(x(0.5), y(0.08));
    canvas.drawCircle(head, rect.width * 0.11, paint);
    final body = Path()
      ..moveTo(x(0.46), y(0.19))
      ..quadraticBezierTo(x(0.35), y(0.34), x(0.38), y(0.48))
      ..lineTo(x(0.47), y(0.56))
      ..lineTo(x(0.62), y(0.50))
      ..quadraticBezierTo(x(0.57), y(0.32), x(0.54), y(0.20));
    canvas.drawPath(body, paint);
    canvas.drawLine(Offset(x(0.43), y(0.54)), Offset(x(0.33), y(0.92)), paint);
    canvas.drawLine(Offset(x(0.59), y(0.53)), Offset(x(0.74), y(0.92)), paint);
    canvas.drawLine(Offset(x(0.47), y(0.36)), Offset(x(0.73), y(0.68)), paint);
    canvas.drawLine(Offset(x(0.56), y(0.36)), Offset(x(0.73), y(0.68)), paint);
    canvas.drawLine(Offset(x(0.73), y(0.68)), Offset(x(1.02), y(0.88)), paint);
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
    final direction = end - start;
    if (direction.distance < 4) return;
    final unit = direction / direction.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final p1 = end - unit * 18 + normal * 8;
    final p2 = end - unit * 18 - normal * 8;
    canvas.drawLine(end, p1, paint);
    canvas.drawLine(end, p2, paint);
  }

  @override
  bool shouldRepaint(covariant _CaptureGuidePainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.isRecording != isRecording ||
        oldDelegate.tracerMode != tracerMode ||
        oldDelegate.tracerBallAnchor != tracerBallAnchor ||
        oldDelegate.tracerTargetPoint != tracerTargetPoint ||
        oldDelegate.tracerStyle != tracerStyle ||
        oldDelegate.tracerPointMode != tracerPointMode ||
        oldDelegate.handedness != handedness;
  }
}

Color _tracerGuideAccent(String style) {
  return switch (style) {
    'signature' ||
    'signature_green_gold' ||
    'green_glow' => const Color(0xFF76FF7A),
    'power_red' => const Color(0xFFFF6A3D),
    _ => Colors.white,
  };
}

class _AlignmentRow extends StatelessWidget {
  const _AlignmentRow({required this.label, required this.passed});

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 18,
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
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
