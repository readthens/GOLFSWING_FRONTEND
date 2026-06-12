import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/favorite_toggle_button.dart';

class TracerExperiencePanel extends ConsumerStatefulWidget {
  const TracerExperiencePanel({
    required this.session,
    required this.accessToken,
    super.key,
  });

  final SwingSession session;
  final String accessToken;

  @override
  ConsumerState<TracerExperiencePanel> createState() =>
      _TracerExperiencePanelState();
}

class _TracerExperiencePanelState extends ConsumerState<TracerExperiencePanel> {
  TracerResult? _result;
  TracerJob? _job;
  Timer? _pollTimer;
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadResult());
  }

  @override
  void didUpdateWidget(covariant TracerExperiencePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.accessToken != widget.accessToken) {
      _pollTimer?.cancel();
      _result = null;
      _job = null;
      _isLoading = true;
      _error = null;
      unawaited(_loadResult());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadResult({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final result = await ref
          .read(apiClientProvider)
          .getTracerResult(widget.accessToken, widget.session.id);
      if (!mounted) return;
      setState(() {
        _result = result;
        _job = null;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load shot tracer result.';
      });
    }
  }

  Future<void> _startTracer() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      final job = await ref
          .read(apiClientProvider)
          .startTracerJob(widget.accessToken, widget.session.id);
      if (!mounted) return;
      setState(() {
        _job = job;
        _isStarting = false;
        _error = null;
      });
      if (job.isActive) {
        _schedulePolling();
      } else if (job.isSucceeded) {
        await _loadResult(showLoading: false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _error = 'Unable to create tracer. Check the backend worker.';
      });
    }
  }

  void _schedulePolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollJob());
    });
    unawaited(_pollJob());
  }

  Future<void> _pollJob() async {
    final jobId = _job?.id;
    if (jobId == null) return;
    try {
      final job = await ref
          .read(apiClientProvider)
          .getTracerJob(widget.accessToken, jobId);
      if (!mounted) return;
      setState(() => _job = job);
      if (job.isSucceeded) {
        _pollTimer?.cancel();
        await _loadResult(showLoading: false);
      } else if (job.isFailed) {
        _pollTimer?.cancel();
      }
    } catch (_) {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() => _error = 'Unable to poll tracer status.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const InfoPanel(
        children: [
          Text('SHOT TRACER', style: AppTextStyles.label),
          LinearProgressIndicator(minHeight: 2),
        ],
      );
    }

    final job = _job;
    if (job != null && job.isActive) {
      return _TracerJobPanel(job: job, error: _error);
    }
    if (job != null && job.isFailed) {
      return InfoPanel(
        children: [
          const Text('TRACER INTERRUPTED', style: AppTextStyles.label),
          Text(job.errorMessage ?? 'The tracer worker could not finish.'),
          PrimaryButton(
            label: _isStarting ? 'STARTING...' : 'RETRY TRACER',
            onPressed: _isStarting ? null : _startTracer,
          ),
        ],
      );
    }

    final result = _result;
    if (result == null) {
      return InfoPanel(
        children: [
          const Text('SHOT TRACER READY', style: AppTextStyles.label),
          const Text(
            'Create a visual shot tracer from this rear-angle video. No launch monitor metrics are estimated.',
          ),
          if (_error != null) Text(_error!),
          PrimaryButton(
            key: const ValueKey('tracer-create-button'),
            label: _isStarting ? 'STARTING...' : 'CREATE TRACER',
            onPressed: _isStarting || widget.session.videos.isEmpty
                ? null
                : _startTracer,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TRACER FILM ROOM', style: AppTextStyles.label),
        const SizedBox(height: 10),
        FavoriteToggleButton(
          accessToken: widget.accessToken,
          entityType: 'tracer_result',
          entityId: result.id,
          saveLabel: 'SAVE TRACER',
          savedLabel: 'TRACER SAVED',
        ),
        if (!result.needsBetterCapture) ...[
          const SizedBox(height: 12),
          _TracerVideoSurface(result: result, accessToken: widget.accessToken),
          const SizedBox(height: 12),
          _TracerBroadcastHud(result: result),
        ],
        const SizedBox(height: 12),
        InfoPanel(
          children: [
            Text('STATUS: ${result.trackingLabel}'),
            Text(
              'TRACKING CONFIDENCE: ${((result.confidence ?? 0) * 100).round()}%',
            ),
            Text(
              'DETECTED POINTS: ${result.observedPointCount} · INTERPOLATED: ${result.interpolatedPointCount} · GAPS: ${result.trackingGapCount}',
            ),
            Text(
              'STYLE: ${(result.style['name'] as String? ?? 'classic_white').replaceAll('_', ' ').toUpperCase()}',
            ),
            if (result.hasFlightMetrics) ...[
              const Text('VISUAL FLIGHT', style: AppTextStyles.label),
              Text('STATUS: ${result.flightStatusLabel}'),
              Text(
                'LAUNCH: ${result.visualLaunchLabel} · START: ${result.startDirectionDeltaLabel}',
              ),
              Text(
                'APEX: ${result.apexRiseLabel} · CURVE: ${result.curveBiasLabel}',
              ),
              Text(result.flightSummary),
            ],
            const Text(
              'VISUAL TRACER ONLY: no ball speed, carry, launch, or spin claims.',
            ),
            if (result.needsBetterCapture)
              const Text(
                'NEEDS BETTER CAPTURE: use the guided rear camera flow with a white ball, stable phone, and visible target line.',
              ),
            if (result.failedCaptureGateGuidance.isNotEmpty) ...[
              const Text('FIX BEFORE RETRY', style: AppTextStyles.label),
              for (final message in result.failedCaptureGateGuidance.take(5))
                Text('- $message'),
            ],
            if (result.needsBetterCapture)
              PrimaryButton(
                key: const ValueKey('record-guided-tracer'),
                label: 'RECORD GUIDED TRACER',
                onPressed: () => context.go('/capture/tracer'),
              ),
            if (result.trackingFailureReasons.isNotEmpty)
              Text(
                'CAPTURE NOTES: ${result.trackingFailureReasons.take(2).join(', ').replaceAll('_', ' ').toUpperCase()}',
              ),
            if (_error != null) Text(_error!),
          ],
        ),
      ],
    );
  }
}

class _TracerJobPanel extends StatelessWidget {
  const _TracerJobPanel({required this.job, this.error});

  final TracerJob job;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final progress = (job.progress.clamp(0, 100).toInt()) / 100;
    return InfoPanel(
      children: [
        const Text('SHOT TRACER', style: AppTextStyles.label),
        Text(
          '${job.jobType.toUpperCase()} · ${job.status.toUpperCase()} · ${job.progress}%',
        ),
        LinearProgressIndicator(value: progress, minHeight: 2),
        const Text('TRACKING BALL PATH AND RENDERING PRIVATE VIDEO'),
        if (error != null) Text(error!),
      ],
    );
  }
}

class _TracerVideoSurface extends ConsumerStatefulWidget {
  const _TracerVideoSurface({required this.result, required this.accessToken});

  final TracerResult result;
  final String accessToken;

  @override
  ConsumerState<_TracerVideoSurface> createState() =>
      _TracerVideoSurfaceState();
}

class _TracerVideoSurfaceState extends ConsumerState<_TracerVideoSurface> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _notice;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void didUpdateWidget(covariant _TracerVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.id != widget.result.id ||
        oldWidget.result.hasRenderVideo != widget.result.hasRenderVideo) {
      unawaited(_prepare());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    await _controller?.dispose();
    _controller = null;
    setState(() {
      _isLoading = true;
      _notice = null;
    });
    if (!widget.result.hasRender) {
      setState(() {
        _isLoading = false;
        _notice = 'Rendered tracer video is not ready yet.';
      });
      return;
    }
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/tracer_${widget.result.id}.mp4';
      await ref
          .read(apiClientProvider)
          .downloadTracerVideoFile(
            accessToken: widget.accessToken,
            resultId: widget.result.id,
            destinationPath: path,
          );
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _notice =
            'Rendered tracer video is ready. Preview is unavailable in this environment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final aspectRatio = controller?.value.aspectRatio;
    return AspectRatio(
      aspectRatio: aspectRatio == null || aspectRatio <= 0
          ? 9 / 16
          : aspectRatio,
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
              if (controller != null && controller.value.isInitialized)
                GestureDetector(
                  onTap: () {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                    setState(() {});
                  },
                  child: VideoPlayer(controller),
                )
              else
                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(_notice ?? 'Tracer preview unavailable.'),
                ),
              Positioned(
                left: 12,
                top: 12,
                child: _TracerBadge(label: widget.result.trackingLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TracerBroadcastHud extends StatelessWidget {
  const _TracerBroadcastHud({required this.result});

  final TracerResult result;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Row(
          children: [
            Expanded(
              child: _HudMetric(
                label: 'IMPACT',
                value: _timeLabel(result.impactTimestampMs),
              ),
            ),
            Expanded(
              child: _HudMetric(
                label: 'APEX',
                value: _timeLabel(result.apexTimestampMs),
              ),
            ),
            Expanded(
              child: _HudMetric(
                label: 'LANDING',
                value: _timeLabel(result.landingTimestampMs),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _TracerTimeline(result: result),
      ],
    );
  }
}

class _HudMetric extends StatelessWidget {
  const _HudMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.micro),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _TracerTimeline extends StatelessWidget {
  const _TracerTimeline({required this.result});

  final TracerResult result;

  @override
  Widget build(BuildContext context) {
    final total = [
      result.impactTimestampMs,
      result.apexTimestampMs,
      result.landingTimestampMs,
    ].whereType<int>().fold<int>(1, (max, value) => value > max ? value : max);
    return SizedBox(
      height: 38,
      child: CustomPaint(
        painter: _TracerTimelinePainter(
          impact: result.impactTimestampMs,
          apex: result.apexTimestampMs,
          landing: result.landingTimestampMs,
          total: total,
          enabled: !result.needsBetterCapture,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TracerTimelinePainter extends CustomPainter {
  const _TracerTimelinePainter({
    required this.impact,
    required this.apex,
    required this.landing,
    required this.total,
    required this.enabled,
  });

  final int? impact;
  final int? apex;
  final int? landing;
  final int total;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * 0.48;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: enabled ? 0.28 : 0.12)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final accent = Paint()
      ..color = enabled ? const Color(0xFF76FF7A) : AppColors.textSecondary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), track);
    final marks = [(impact, 'I'), (apex, 'A'), (landing, 'L')];
    for (final mark in marks) {
      final timestamp = mark.$1;
      if (timestamp == null) continue;
      final x = (timestamp / total).clamp(0.0, 1.0) * size.width;
      canvas.drawLine(Offset(x, baseY - 10), Offset(x, baseY + 10), accent);
      final textPainter = TextPainter(
        text: TextSpan(
          text: mark.$2,
          style: AppTextStyles.micro.copyWith(color: AppColors.textPrimary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, baseY + 13));
    }
  }

  @override
  bool shouldRepaint(covariant _TracerTimelinePainter oldDelegate) {
    return oldDelegate.impact != impact ||
        oldDelegate.apex != apex ||
        oldDelegate.landing != landing ||
        oldDelegate.total != total ||
        oldDelegate.enabled != enabled;
  }
}

class _TracerBadge extends StatelessWidget {
  const _TracerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(label, style: AppTextStyles.micro),
      ),
    );
  }
}

String _timeLabel(int? timestampMs) {
  if (timestampMs == null) return 'N/A';
  return '${(timestampMs / 1000).toStringAsFixed(2)}s';
}
