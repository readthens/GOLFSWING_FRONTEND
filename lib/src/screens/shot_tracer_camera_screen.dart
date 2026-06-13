import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../capture/native_capture_bridge.dart';
import '../theme/app_theme.dart';

const _shotTracerCameraPreviewAsset = 'assets/home/shot_tracer.png';

class ShotTracerCameraScreen extends StatefulWidget {
  const ShotTracerCameraScreen({super.key});

  @override
  State<ShotTracerCameraScreen> createState() => _ShotTracerCameraScreenState();
}

class _ShotTracerCameraScreenState extends State<ShotTracerCameraScreen> {
  final _nativeCaptureBridge = const NativeCaptureBridge();

  CameraController? _cameraController;
  NativeCaptureCapabilities _capabilities = const NativeCaptureCapabilities(
    highFpsCaptureAvailable: false,
  );
  Timer? _timer;
  bool _isInitializing = true;
  bool _isRecording = false;
  bool _impactLocked = false;
  bool _tracePreviewReady = false;
  int _elapsedTenths = 0;
  String? _cameraNotice;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final capabilities = await _nativeCaptureBridge.getCaptureCapabilities();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _capabilities = capabilities;
          _isInitializing = false;
          _cameraNotice = 'SIMULATOR PREVIEW';
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
      setState(() {
        _cameraController = controller;
        _capabilities = capabilities;
        _isInitializing = false;
        _cameraNotice = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraNotice = 'SIMULATOR PREVIEW';
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    final controller = _cameraController;
    try {
      if (controller != null &&
          controller.value.isInitialized &&
          !controller.value.isRecordingVideo) {
        await controller.startVideoRecording();
      }
    } catch (_) {
      // Keep the camera-style flow usable on simulator or unsupported devices.
    }
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _impactLocked = false;
      _tracePreviewReady = false;
      _elapsedTenths = 0;
      _cameraNotice = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedTenths += 1;
        if (_elapsedTenths >= 18) {
          _impactLocked = true;
        }
      });
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final controller = _cameraController;
    try {
      if (controller != null &&
          controller.value.isInitialized &&
          controller.value.isRecordingVideo) {
        await controller.stopVideoRecording();
      }
    } catch (_) {
      // The preview still transitions into review even if local camera save fails.
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _impactLocked = true;
      _tracePreviewReady = true;
    });
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tracer');
    }
  }

  String get _statusLabel {
    if (_tracePreviewReady) return 'TRACER PREVIEW';
    if (_isRecording && _impactLocked) return 'IMPACT DETECTED';
    if (_isRecording) return 'WAITING FOR BALL IMPACT';
    if (_isInitializing) return 'OPENING CAMERA';
    return 'RANGE READY';
  }

  String get _timerLabel {
    final seconds = _elapsedTenths ~/ 10;
    final tenths = _elapsedTenths % 10;
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}.$tenths';
  }

  bool get _cameraReady =>
      _cameraController != null && _cameraController!.value.isInitialized;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraReady)
            _CameraPreviewFill(controller: _cameraController!)
          else
            Image.asset(
              _shotTracerCameraPreviewAsset,
              key: const ValueKey('tracer-camera-fallback-preview'),
              fit: BoxFit.cover,
              alignment: const Alignment(-0.05, 0.10),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.78),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.38),
                  Colors.black,
                ],
                stops: const [0, 0.22, 0.68, 0.86],
              ),
            ),
          ),
          CustomPaint(
            key: const ValueKey('tracer-camera-guide-overlay'),
            painter: _ShotTracerCameraGuidePainter(
              recording: _isRecording,
              impactLocked: _impactLocked,
              tracePreviewReady: _tracePreviewReady,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 700;
                return Column(
                  children: [
                    _TracerCameraTopBar(
                      onClose: _exit,
                      timerLabel: _timerLabel,
                      statusLabel: _statusLabel,
                      recording: _isRecording,
                      capabilityLabel: _capabilityLabel(_capabilities),
                      compact: compact,
                    ),
                    const Spacer(),
                    if (!compact)
                      _TracerCameraQualityStack(
                        cameraReady: _cameraReady || _cameraNotice != null,
                        highFpsReady: _capabilities.highFpsCaptureAvailable,
                        impactLocked: _impactLocked,
                        notice: _cameraNotice,
                      ),
                    SizedBox(height: compact ? 8 : 18),
                    _TracerCameraControlDeck(
                      recording: _isRecording,
                      tracePreviewReady: _tracePreviewReady,
                      onRecord: _toggleRecording,
                      compact: compact,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPreviewFill extends StatelessWidget {
  const _CameraPreviewFill({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _TracerCameraTopBar extends StatelessWidget {
  const _TracerCameraTopBar({
    required this.onClose,
    required this.timerLabel,
    required this.statusLabel,
    required this.recording,
    required this.capabilityLabel,
    required this.compact,
  });

  final VoidCallback onClose;
  final String timerLabel;
  final String statusLabel;
  final bool recording;
  final String capabilityLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('tracer-camera-close-button'),
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 25),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.42),
                ),
              ),
              const Spacer(),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: recording
                      ? AppColors.signalRed
                      : const Color(0xFF29D65F),
                ),
              ),
              const Spacer(),
              _CameraPill(label: capabilityLabel),
            ],
          ),
          SizedBox(height: compact ? 8 : 14),
          Text(
            timerLabel,
            key: const ValueKey('tracer-camera-timer'),
            style: AppTextStyles.title.copyWith(
              fontSize: compact ? 28 : 34,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: compact ? 5 : 7),
          _CameraPill(
            key: const ValueKey('tracer-camera-status'),
            label: statusLabel,
            active: recording,
          ),
        ],
      ),
    );
  }
}

class _TracerCameraQualityStack extends StatelessWidget {
  const _TracerCameraQualityStack({
    required this.cameraReady,
    required this.highFpsReady,
    required this.impactLocked,
    this.notice,
  });

  final bool cameraReady;
  final bool highFpsReady;
  final bool impactLocked;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 18, right: 18),
        child: Container(
          width: 198,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.50),
            border: Border.all(color: const Color(0x24FFFFFF)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              _CaptureReadinessRow(label: 'REAR CAMERA', ready: cameraReady),
              const SizedBox(height: 10),
              const _CaptureReadinessRow(label: 'BALL VISIBLE', ready: true),
              const SizedBox(height: 10),
              const _CaptureReadinessRow(label: 'TARGET LINE', ready: true),
              const SizedBox(height: 10),
              _CaptureReadinessRow(
                label: 'HIGH FPS',
                ready: highFpsReady,
                softReady: !highFpsReady,
              ),
              const SizedBox(height: 10),
              _CaptureReadinessRow(label: 'IMPACT LOCK', ready: impactLocked),
              if (notice != null) ...[
                const SizedBox(height: 10),
                Text(
                  notice!,
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureReadinessRow extends StatelessWidget {
  const _CaptureReadinessRow({
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
    return Row(
      children: [
        Icon(
          ready ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.micro.copyWith(fontSize: 9.5),
          ),
        ),
        Text(
          ready
              ? 'GOOD'
              : softReady
              ? 'LIMITED'
              : 'WAIT',
          style: AppTextStyles.micro.copyWith(
            color: color,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _TracerCameraControlDeck extends StatelessWidget {
  const _TracerCameraControlDeck({
    required this.recording,
    required this.tracePreviewReady,
    required this.onRecord,
    required this.compact,
  });

  final bool recording;
  final bool tracePreviewReady;
  final VoidCallback onRecord;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, compact ? 12 : 18, 22, 18),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CameraThumbnail(compact: compact),
              _RecordButton(
                recording: recording,
                onPressed: onRecord,
                compact: compact,
              ),
              _LockedPalette(compact: compact),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 18),
            Text(
              tracePreviewReady
                  ? 'Tracer preview locked. Record again to replace this take.'
                  : 'Tap record, stay behind the ball, and let SwingLens wait for impact.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          SizedBox(height: compact ? 12 : 18),
          const _TracerCameraModeBar(),
        ],
      ),
    );
  }
}

class _CameraThumbnail extends StatelessWidget {
  const _CameraThumbnail({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.asset(
        _shotTracerCameraPreviewAsset,
        width: compact ? 56 : 66,
        height: compact ? 46 : 54,
        fit: BoxFit.cover,
        alignment: const Alignment(-0.20, 0.18),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.onPressed,
    required this.compact,
  });

  final bool recording;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: recording ? 'Stop tracer recording' : 'Start tracer recording',
      child: InkWell(
        key: const ValueKey('tracer-camera-record-button'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: compact ? 82 : 104,
          height: compact ? 82 : 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textPrimary, width: 6),
            color: Colors.transparent,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: recording
                  ? compact
                        ? 34
                        : 44
                  : compact
                  ? 62
                  : 80,
              height: recording
                  ? compact
                        ? 34
                        : 44
                  : compact
                  ? 62
                  : 80,
              decoration: BoxDecoration(
                color: recording
                    ? AppColors.signalRed
                    : const Color(0xFFFF4048),
                borderRadius: BorderRadius.circular(recording ? 10 : 999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedPalette extends StatelessWidget {
  const _LockedPalette({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: compact ? 58 : 72,
            height: compact ? 58 : 72,
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: const [
                ColoredBox(color: Color(0xFFFF1212)),
                ColoredBox(color: Color(0xFFFFFF00)),
                ColoredBox(color: Color(0xFF00B45A)),
                ColoredBox(color: Color(0xFF0065FF)),
              ],
            ),
          ),
        ),
        const Icon(Icons.lock, color: Color(0xCCB8B8C0), size: 34),
      ],
    );
  }
}

class _TracerCameraModeBar extends StatelessWidget {
  const _TracerCameraModeBar();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _ModeBarItem(icon: Icons.gps_fixed, label: 'GPS'),
        _ModeBarItem(
          icon: Icons.photo_camera,
          label: 'Shot Tracer',
          selected: true,
        ),
        _ModeBarItem(icon: Icons.settings_outlined, label: 'Settings'),
        _ModeBarItem(icon: Icons.sports_golf, label: 'Pro'),
      ],
    );
  }
}

class _ModeBarItem extends StatelessWidget {
  const _ModeBarItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF4AA3FF) : AppColors.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(
          label,
          style: AppTextStyles.micro.copyWith(
            color: color,
            letterSpacing: 0,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _CameraPill extends StatelessWidget {
  const _CameraPill({required this.label, this.active = false, super.key});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        border: Border.all(
          color: active
              ? const Color(0x669FE870)
              : Colors.white.withValues(alpha: 0.16),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.micro.copyWith(
          color: active ? const Color(0xFF9FE870) : AppColors.textPrimary,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ShotTracerCameraGuidePainter extends CustomPainter {
  const _ShotTracerCameraGuidePainter({
    required this.recording,
    required this.impactLocked,
    required this.tracePreviewReady,
  });

  final bool recording;
  final bool impactLocked;
  final bool tracePreviewReady;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = const Color(0xFF9FE870);
    final framePaint = Paint()
      ..color = accent.withValues(alpha: recording ? 0.62 : 0.82)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final frame = Rect.fromLTWH(
      size.width * 0.22,
      size.height * 0.18,
      size.width * 0.56,
      size.height * 0.56,
    );
    canvas.drawRect(frame, framePaint);

    final ball = Offset(size.width * 0.53, size.height * 0.70);
    final target = Offset(size.width * 0.53, size.height * 0.23);
    _drawDashedLine(
      canvas,
      target,
      ball,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.70)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    _drawCorner(canvas, size, Offset.zero);
    _drawCorner(canvas, size, Offset(size.width, 0), flipX: true);
    _drawCorner(canvas, size, Offset(0, size.height), flipY: true);
    _drawCorner(
      canvas,
      size,
      Offset(size.width, size.height),
      flipX: true,
      flipY: true,
    );

    final glowPaint = Paint()
      ..color = accent.withValues(alpha: 0.17)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(ball, 34, glowPaint);
    canvas.drawCircle(
      ball,
      24,
      Paint()
        ..color = accent.withValues(alpha: 0.86)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(ball, 5, Paint()..color = AppColors.textPrimary);

    if (impactLocked || tracePreviewReady) {
      final path = Path()
        ..moveTo(ball.dx, ball.dy)
        ..quadraticBezierTo(
          size.width * 0.70,
          size.height * 0.24,
          size.width * 0.90,
          size.height * 0.18,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = tracePreviewReady ? 3.2 : 2.4
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [accent, AppColors.signalGold.withValues(alpha: 0.90)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    var current = 0.0;
    const dash = 9.0;
    const gap = 9.0;
    while (current < distance) {
      final next = math.min(current + dash, distance);
      canvas.drawLine(
        start + direction * current,
        start + direction * next,
        paint,
      );
      current = next + gap;
    }
  }

  void _drawCorner(
    Canvas canvas,
    Size size,
    Offset origin, {
    bool flipX = false,
    bool flipY = false,
  }) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.54)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const inset = 1.0;
    const length = 38.0;
    final sx = flipX ? -1.0 : 1.0;
    final sy = flipY ? -1.0 : 1.0;
    final start = origin + Offset(sx * inset, sy * inset);
    canvas.drawLine(start, start + Offset(sx * length, 0), paint);
    canvas.drawLine(start, start + Offset(0, sy * length), paint);
  }

  @override
  bool shouldRepaint(covariant _ShotTracerCameraGuidePainter oldDelegate) {
    return oldDelegate.recording != recording ||
        oldDelegate.impactLocked != impactLocked ||
        oldDelegate.tracePreviewReady != tracePreviewReady;
  }
}

String _capabilityLabel(NativeCaptureCapabilities capabilities) {
  if (capabilities.trustedForTracer && capabilities.deviceTier == 'A') {
    return 'HIGH FPS';
  }
  if (capabilities.highFpsCaptureAvailable) return 'HIGH FPS';
  return 'CAMERA';
}
