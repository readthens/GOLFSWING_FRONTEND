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
        qualityChecks: qualityChecks,
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
    required List<_LocalQualityCheck> qualityChecks,
    required bool hasHardFailure,
    required TracerReadinessResult tracerReadiness,
  }) {
    final handedness = auth.profile?.handedness?.toLowerCase() ?? 'right';
    final cameraReady = _cameraController?.value.isInitialized ?? false;
    final recordEnabled =
        !_isInitializingCamera &&
        cameraReady &&
        (_isRecording || tracerReadiness.canRecord);
    final recordLabel = _tracerRecordLabel(cameraReady, tracerReadiness);
    return AppScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/tracer'),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SHOT TRACER',
                      style: AppTextStyles.title.copyWith(fontSize: 28),
                    ),
                  ),
                  _TracerCameraPill(
                    label: _nativeCaptureCapabilities.highFpsCaptureAvailable
                        ? 'HIGH FPS'
                        : 'CAMERA',
                    active: cameraReady,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Rear camera capture with live guide framing. Import video stays on the Shot Tracer intro.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              _TracerCameraPreviewFrame(
                status: _tracerLiveStatus(cameraReady, tracerReadiness),
                timer: _tracerRecordingTimerLabel,
                recording: _isRecording,
                child: _CapturePreview(
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
                  handedness: handedness,
                  aspectRatio: 9 / 14,
                  borderRadius: 22,
                  onTracerPointChanged: _updateTracerPoint,
                ),
              ),
              const SizedBox(height: 16),
              _TracerCameraChecklist(
                readiness: tracerReadiness,
                cameraReady: cameraReady,
                impactWindowActive: _tracerImpactWindowActive,
                highFpsAvailable:
                    _nativeCaptureCapabilities.highFpsCaptureAvailable,
              ),
              const SizedBox(height: 16),
              _TracerCameraRecordDeck(
                label: recordLabel,
                recording: _isRecording,
                enabled: recordEnabled,
                onPressed: _recordOrStop,
              ),
              if (_cameraNotice != null) ...[
                const SizedBox(height: 12),
                InfoPanel(children: [Text(_cameraNotice!)]),
              ],
              const SizedBox(height: 18),
              _TracerCameraSetupBar(
                pointMode: _tracerPointMode,
                whiteBallConfirmed: _whiteBallConfirmed,
                onPointModeChanged: (value) =>
                    setState(() => _tracerPointMode = value),
                onWhiteBallChanged: (value) =>
                    setState(() => _whiteBallConfirmed = value),
              ),
              const SizedBox(height: 18),
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
              if (_file != null) ...[
                const SizedBox(height: 18),
                _buildTracerCameraReviewPanel(qualityChecks, tracerReadiness),
              ],
              if (_mediaNotice != null) ...[
                const SizedBox(height: 12),
                InfoPanel(children: [Text(_mediaNotice!)]),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorText(_error!),
              ],
              const SizedBox(height: 14),
              PrimaryButton(
                label: _isUploading ? 'UPLOADING' : 'UPLOAD TRACER VIDEO',
                onPressed: _file == null || hasHardFailure || _isUploading
                    ? null
                    : () => _upload(auth.accessToken),
              ),
            ],
          ),
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
    if (_isRecording) return 'STOP RECORDING';
    if (_isInitializingCamera) return 'OPENING CAMERA';
    if (!cameraReady) return 'CAMERA UNAVAILABLE';
    if (!readiness.canRecord) return 'HOLD FRAME STEADY';
    return 'START RECORDING';
  }

  String _tracerLiveStatus(bool cameraReady, TracerReadinessResult readiness) {
    if (_file != null) return 'READY TO UPLOAD';
    if (_isRecording && _tracerImpactWindowActive) return 'IMPACT WINDOW';
    if (_isRecording) return 'WAITING FOR IMPACT';
    if (_isInitializingCamera) return 'OPENING CAMERA';
    if (!cameraReady) return 'CAMERA UNAVAILABLE';
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

  Widget _buildTracerCameraReviewPanel(
    List<_LocalQualityCheck> qualityChecks,
    TracerReadinessResult tracerReadiness,
  ) {
    final blockingIssues = qualityChecks
        .where((check) => check.severity == 'fail')
        .toList(growable: false);
    return InfoPanel(
      children: [
        const Text('CAPTURE READY', style: AppTextStyles.label),
        Text('SOURCE: ${_source.toUpperCase()}'),
        Text('DURATION: ${_formatDuration(_durationMs).toUpperCase()}'),
        Text('RESOLUTION: ${_formatResolution().toUpperCase()}'),
        Text(
          'AUTO TRACKING: ${tracerReadiness.autoEligible ? 'ELIGIBLE' : 'VISUAL REVIEW'}',
        ),
        if (blockingIssues.isEmpty)
          const Text('Upload this take to create the visual tracer.')
        else
          for (final issue in blockingIssues) Text(issue.message),
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

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initializeCamera();
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isTracerMode && !_tracerReadiness.canRecord) {
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
        _cameraNotice =
            'Camera recording is unavailable on this device. Choose a saved video instead.';
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
          _cameraNotice =
              'Native high-FPS recording could not be saved. Try recording again.';
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
        _cameraNotice =
            'Camera is unavailable here. Choose a saved video to keep testing.';
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

class _TracerCameraPreviewFrame extends StatelessWidget {
  const _TracerCameraPreviewFrame({
    required this.child,
    required this.status,
    required this.timer,
    required this.recording,
  });

  final Widget child;
  final String status;
  final String timer;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('tracer-camera-capture-frame'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7CFF9B).withValues(alpha: 0.12),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          child,
          Positioned(
            left: 16,
            right: 16,
            top: 14,
            child: Row(
              children: [
                _TracerCameraPill(label: status, active: recording),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x20FFFFFF)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Text(
                      timer,
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TracerCameraPill extends StatelessWidget {
  const _TracerCameraPill({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0x669FE870) : const Color(0x22FFFFFF),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          label,
          style: AppTextStyles.micro.copyWith(
            color: active ? const Color(0xFF9FE870) : AppColors.textPrimary,
            fontSize: 10,
            letterSpacing: 0.75,
          ),
        ),
      ),
    );
  }
}

class _TracerCameraChecklist extends StatelessWidget {
  const _TracerCameraChecklist({
    required this.readiness,
    required this.cameraReady,
    required this.impactWindowActive,
    required this.highFpsAvailable,
  });

  final TracerReadinessResult readiness;
  final bool cameraReady;
  final bool impactWindowActive;
  final bool highFpsAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('tracer-camera-readiness-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TracerReadinessChip(
                  label: 'REAR CAMERA',
                  ready: cameraReady,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TracerReadinessChip(
                  label: 'HIGH FPS',
                  ready: highFpsAvailable,
                  softReady: !highFpsAvailable,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TracerReadinessChip(
                  label: 'BALL',
                  ready: readiness.checks['white_ball_confirmed'] == true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TracerReadinessChip(
                  label: 'TARGET',
                  ready: readiness.checks['target_line_set'] == true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TracerReadinessChip(
                  label: 'IMPACT',
                  ready: impactWindowActive,
                  softReady: !impactWindowActive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TracerReadinessChip extends StatelessWidget {
  const _TracerReadinessChip({
    required this.label,
    required this.ready,
    this.softReady = false,
  });

  final String label;
  final bool ready;
  final bool softReady;

  @override
  Widget build(BuildContext context) {
    final color = ready
        ? const Color(0xFF9FE870)
        : softReady
        ? AppColors.signalGold
        : AppColors.textMuted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ready ? Icons.check_circle_outline : Icons.circle_outlined,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.micro.copyWith(
                  color: color,
                  fontSize: 9,
                  letterSpacing: 0.55,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TracerCameraRecordDeck extends StatelessWidget {
  const _TracerCameraRecordDeck({
    required this.label,
    required this.recording,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool recording;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.44),
        border: Border.all(color: const Color(0x22FFFFFF)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          InkWell(
            key: const ValueKey('tracer-existing-record-button'),
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                  width: 6,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: recording ? 38 : 72,
                  height: recording ? 38 : 72,
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.signalRed : AppColors.textMuted,
                    borderRadius: BorderRadius.circular(recording ? 10 : 999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recording
                ? 'Keep the phone locked behind the ball until the shot is away.'
                : 'Record from behind the ball. SwingLens will use this clip for the visual tracer.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TracerCameraSetupBar extends StatelessWidget {
  const _TracerCameraSetupBar({
    required this.pointMode,
    required this.whiteBallConfirmed,
    required this.onPointModeChanged,
    required this.onWhiteBallChanged,
  });

  final String pointMode;
  final bool whiteBallConfirmed;
  final ValueChanged<String> onPointModeChanged;
  final ValueChanged<bool> onWhiteBallChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GUIDE LOCK', style: AppTextStyles.label),
          const SizedBox(height: 10),
          SegmentedChoices(
            values: const ['ball', 'target'],
            selected: pointMode,
            onSelected: onPointModeChanged,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: whiteBallConfirmed,
            onChanged: (value) => onWhiteBallChanged(value ?? false),
            title: const Text('WHITE BALL VISIBLE'),
            subtitle: const Text('Required for automatic visual tracking.'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
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
    this.aspectRatio = 9 / 13,
    this.borderRadius = 8,
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
  final double aspectRatio;
  final double borderRadius;
  final ValueChanged<Offset>? onTracerPointChanged;

  @override
  Widget build(BuildContext context) {
    final cameraReady = cameraController?.value.isInitialized ?? false;
    final videoReady = videoController?.value.isInitialized ?? false;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
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
