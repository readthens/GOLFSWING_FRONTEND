import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('SWINGLENS AI', style: AppTextStyles.micro),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout),
                    onPressed: () => ref.read(authControllerProvider).logout(),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text('TODAY', style: AppTextStyles.label),
              const SizedBox(height: 12),
              const Text('CAPTURE A CLEAN SWING', style: AppTextStyles.title),
              const SizedBox(height: 12),
              Text(
                'Record with the guide or import a saved face-on or down-the-line video. AI analysis stays deferred.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              InfoPanel(
                children: [
                  Text(
                    'PROFILE: ${auth.state.profile?.skillLevel?.toUpperCase() ?? 'SET'}',
                  ),
                  Text(
                    'HANDEDNESS: ${auth.state.profile?.handedness?.toUpperCase() ?? 'SET'}',
                  ),
                  Text(
                    'VIDEO CONSENT: ${auth.state.hasVideoConsent ? 'ACCEPTED' : 'REQUIRED'}',
                  ),
                ],
              ),
              const Spacer(),
              PrimaryButton(
                label: 'CAPTURE SWING',
                onPressed: () => context.go('/capture/review'),
              ),
              const SizedBox(height: 12),
              GhostButton(
                label: 'SWING LIBRARY',
                onPressed: () => context.go('/swings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SwingLibraryScreen extends ConsumerWidget {
  const SwingLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).state;
    final token = auth.accessToken;
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/home'),
              ),
              const Text('SWING LIBRARY', style: AppTextStyles.title),
              const SizedBox(height: 18),
              Expanded(
                child: token == null
                    ? const Center(child: Text('Sign in required.'))
                    : FutureBuilder<List<SwingSession>>(
                        future: ref
                            .read(apiClientProvider)
                            .getSwingSessions(token),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return ErrorText(
                              'Unable to load swings. Start the backend and try again.',
                            );
                          }
                          final sessions = snapshot.data ?? const [];
                          if (sessions.isEmpty) {
                            return const EmptyState(
                              title: 'NO SWINGS YET',
                              body:
                                  'Upload your first face-on or down-the-line swing.',
                            );
                          }
                          return ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              return PanelButton(
                                title:
                                    session.club?.toUpperCase() ??
                                    'SWING SESSION',
                                subtitle:
                                    '${session.status.toUpperCase()} · ${session.videos.length} VIDEO · ${_qualityLabel(session)}',
                                onPressed: () =>
                                    context.go('/swings/${session.id}'),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SwingDetailScreen extends ConsumerWidget {
  const SwingDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/swings'),
              ),
              const Text('SWING DETAIL', style: AppTextStyles.title),
              const SizedBox(height: 18),
              Expanded(
                child: token == null
                    ? const Center(child: Text('Sign in required.'))
                    : FutureBuilder<SwingSession>(
                        future: ref
                            .read(apiClientProvider)
                            .getSwingSession(token, sessionId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return const ErrorText(
                              'Unable to load swing detail.',
                            );
                          }
                          final session = snapshot.data!;
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InfoPanel(
                                  children: [
                                    Text(
                                      'CLUB: ${session.club?.toUpperCase() ?? 'UNKNOWN'}',
                                    ),
                                    Text(
                                      'STATUS: ${session.status.toUpperCase()}',
                                    ),
                                    Text(
                                      'LOCATION: ${session.locationType?.toUpperCase() ?? 'UNSET'}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'VIDEOS',
                                  style: AppTextStyles.label,
                                ),
                                const SizedBox(height: 10),
                                for (final video in session.videos) ...[
                                  InfoPanel(
                                    children: [
                                      Text(
                                        'ANGLE: ${video.angle.toUpperCase()}',
                                      ),
                                      Text(
                                        'QUALITY: ${video.qualityStatus?.toUpperCase() ?? 'PENDING'}',
                                      ),
                                      Text(
                                        'SCORE: ${video.qualityScore == null ? 'UNSET' : video.qualityScore!.toStringAsFixed(0)}',
                                      ),
                                      if (video.durationMs != null)
                                        Text(
                                          'DURATION: ${(video.durationMs! / 1000).toStringAsFixed(1)} SEC',
                                        ),
                                      for (final check
                                          in video.qualityChecks.take(5))
                                        Text(
                                          '${check.severity.toUpperCase()}: ${check.message}',
                                        ),
                                      Text(
                                        'OBJECT KEY: ${video.storageKey}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                AnalysisPrototypePanel(
                                  session: session,
                                  accessToken: token,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _qualityLabel(SwingSession session) {
  if (session.videos.isEmpty) return 'NO QUALITY';
  final status = session.videos.first.qualityStatus;
  return status == null ? 'QUALITY PENDING' : 'QUALITY ${status.toUpperCase()}';
}

class AnalysisPrototypePanel extends ConsumerStatefulWidget {
  const AnalysisPrototypePanel({
    required this.session,
    required this.accessToken,
    super.key,
  });

  final SwingSession session;
  final String accessToken;

  @override
  ConsumerState<AnalysisPrototypePanel> createState() =>
      _AnalysisPrototypePanelState();
}

class _AnalysisPrototypePanelState
    extends ConsumerState<AnalysisPrototypePanel> {
  AnalysisResult? _result;
  AnalysisJob? _job;
  bool _isLoading = true;
  bool _isStarting = false;
  bool _isPolling = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadExistingResult());
  }

  @override
  void didUpdateWidget(covariant AnalysisPrototypePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.accessToken != widget.accessToken) {
      _pollTimer?.cancel();
      _result = null;
      _job = null;
      _error = null;
      _isLoading = true;
      unawaited(_loadExistingResult());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExistingResult() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(apiClientProvider)
          .getAnalysisResult(widget.accessToken, widget.session.id);
      if (!mounted) return;
      setState(() {
        _result = result;
        _job = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load analysis result.';
        _isLoading = false;
      });
    }
  }

  Future<void> _startAnalysis() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      final job = await ref
          .read(apiClientProvider)
          .startAnalysisJob(widget.accessToken, widget.session.id);
      if (!mounted) return;
      setState(() {
        _job = job;
        _isStarting = false;
      });
      if (job.isSucceeded) {
        await _loadExistingResult();
      } else if (job.isActive) {
        _schedulePolling();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to start analysis. Check the backend worker.';
        _isStarting = false;
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
    if (jobId == null || _isPolling) return;
    _isPolling = true;
    try {
      final job = await ref
          .read(apiClientProvider)
          .getAnalysisJob(widget.accessToken, jobId);
      if (!mounted) return;
      setState(() => _job = job);
      if (job.isSucceeded) {
        _pollTimer?.cancel();
        await _loadExistingResult();
      } else if (job.isFailed) {
        _pollTimer?.cancel();
      }
    } catch (_) {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() => _error = 'Unable to poll analysis status.');
    } finally {
      _isPolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const InfoPanel(
        children: [
          Text('ANALYSIS PROTOTYPE', style: AppTextStyles.label),
          LinearProgressIndicator(minHeight: 2),
        ],
      );
    }

    final result = _result;
    if (result != null) {
      return _AnalysisResultView(
        result: result,
        accessToken: widget.accessToken,
      );
    }

    final job = _job;
    if (_error != null && job != null && job.isActive) {
      return InfoPanel(
        children: [
          const Text('ANALYSIS PROTOTYPE', style: AppTextStyles.label),
          Text('${job.status.toUpperCase()} · ${job.progress}%'),
          Text(_error!),
          PrimaryButton(label: 'CHECK STATUS', onPressed: _pollJob),
        ],
      );
    }

    if (job != null && job.isActive) {
      return InfoPanel(
        children: [
          const Text('ANALYSIS PROTOTYPE', style: AppTextStyles.label),
          Text('${job.status.toUpperCase()} · ${job.progress}%'),
          if (job.maxAttempts > 1)
            Text(
              'ATTEMPT ${job.attemptCount.clamp(1, job.maxAttempts)} OF ${job.maxAttempts}',
            ),
          LinearProgressIndicator(value: job.progress.clamp(0, 100) / 100),
          const Text(
            'Server pose extraction is running. This is not a diagnosis yet.',
          ),
        ],
      );
    }

    if (job != null && job.isFailed) {
      return InfoPanel(
        children: [
          const Text('ANALYSIS PROTOTYPE', style: AppTextStyles.label),
          Text(_friendlyAnalysisFailure(job.errorMessage)),
          if (job.errorMessage != null) Text('DETAIL: ${job.errorMessage}'),
          PrimaryButton(
            label: _isStarting ? 'STARTING...' : 'RETRY ANALYSIS',
            onPressed: _isStarting ? null : _startAnalysis,
          ),
        ],
      );
    }

    return InfoPanel(
      children: [
        const Text('ANALYSIS PROTOTYPE', style: AppTextStyles.label),
        const Text(
          'Run the server pose and phase prototype. This is not a swing diagnosis yet.',
        ),
        if (_error != null) Text(_error!),
        PrimaryButton(
          label: _isStarting ? 'STARTING...' : 'RUN ANALYSIS',
          onPressed: _isStarting || widget.session.videos.isEmpty
              ? null
              : _startAnalysis,
        ),
      ],
    );
  }
}

class _AnalysisResultView extends ConsumerWidget {
  const _AnalysisResultView({required this.result, required this.accessToken});

  final AnalysisResult result;
  final String accessToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confidence = result.report['confidence_label'] as String?;
    final recommendation =
        result.report['next_capture_recommendation'] as String?;
    final limitations =
        (result.report['limitations'] as List<dynamic>? ?? const [])
            .cast<String>();
    final warnings =
        (result.report['quality_warnings'] as List<dynamic>? ?? const [])
            .cast<String>();
    final diagnosis = _mapValue(result.report['diagnosis']);
    final visualEvidence = _mapValue(diagnosis?['visual_evidence']);
    final overlaySegments = _mapList(visualEvidence?['segments']);
    final frameAspectRatio = _frameAspectRatio(result.metrics);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoPanel(
          children: [
            const Text('ANALYSIS PROTOTYPE', style: AppTextStyles.label),
            Text(result.summary),
            Text(
              'SCORE: ${result.prototypeScore == null ? 'UNSET' : result.prototypeScore!.toStringAsFixed(0)}',
            ),
            if (confidence != null)
              Text('CONFIDENCE: ${confidence.toUpperCase()}'),
            Text(
              'POSE COVERAGE: ${_percent(result.poseSummary['pose_coverage'])}',
            ),
            if (recommendation != null) Text(recommendation),
            for (final warning in warnings.take(3)) Text('WARN: $warning'),
            for (final limitation in limitations.take(2)) Text(limitation),
          ],
        ),
        if (diagnosis != null) ...[
          const SizedBox(height: 12),
          _DiagnosisPanel(diagnosis: diagnosis),
        ],
        const SizedBox(height: 18),
        const Text('ROUGH PHASES', style: AppTextStyles.label),
        const SizedBox(height: 10),
        if (result.keyframes.isEmpty)
          const InfoPanel(children: [Text('No keyframes were produced.')])
        else
          for (final keyframe in result.keyframes) ...[
            _AnalysisKeyframeTile(
              keyframe: keyframe,
              accessToken: accessToken,
              imageUrl: ref
                  .read(apiClientProvider)
                  .analysisKeyframeImageUrl(keyframe.id),
              overlay: _overlayForPhase(visualEvidence, keyframe.phaseCode),
              overlaySegments: overlaySegments,
              frameAspectRatio: frameAspectRatio,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _DiagnosisPanel extends StatelessWidget {
  const _DiagnosisPanel({required this.diagnosis});

  final Map<String, dynamic> diagnosis;

  @override
  Widget build(BuildContext context) {
    final status = diagnosis['status'] as String? ?? 'limited';
    final primary = _mapValue(diagnosis['primary_fault']);
    final limitations = _stringList(diagnosis['limitations']);
    final faults = _mapList(diagnosis['faults']);

    if (primary == null) {
      return InfoPanel(
        children: [
          const Text('MVP DIAGNOSIS', style: AppTextStyles.label),
          Text(
            status == 'limited'
                ? 'DIAGNOSIS LIMITED'
                : 'NO PRIMARY FAULT FOUND',
          ),
          for (final limitation in limitations.take(3)) Text(limitation),
        ],
      );
    }

    final supportingFaults = faults
        .where((fault) => fault['code'] != primary['code'])
        .take(2);
    return InfoPanel(
      children: [
        const Text('MVP DIAGNOSIS', style: AppTextStyles.label),
        Text(
          'PRIMARY: ${((primary['label'] as String?) ?? 'Swing pattern').toUpperCase()}',
        ),
        Text('CONFIDENCE: ${_percent(primary['confidence'])}'),
        if (primary['evidence'] is String) Text(primary['evidence'] as String),
        if (primary['drill'] is String) Text('DRILL: ${primary['drill']}'),
        if (primary['next_practice_goal'] is String)
          Text('NEXT GOAL: ${primary['next_practice_goal']}'),
        for (final fault in supportingFaults)
          Text(
            'WATCH: ${((fault['label'] as String?) ?? (fault['code'] as String?) ?? 'Pattern').toUpperCase()} ${_percent(fault['confidence'])}',
          ),
        const Text('Pose-based MVP guidance. Not a coach-grade diagnosis yet.'),
      ],
    );
  }
}

class _AnalysisKeyframeTile extends StatelessWidget {
  const _AnalysisKeyframeTile({
    required this.keyframe,
    required this.accessToken,
    required this.imageUrl,
    required this.overlay,
    required this.overlaySegments,
    required this.frameAspectRatio,
  });

  final AnalysisKeyframe keyframe;
  final String accessToken;
  final String imageUrl;
  final Map<String, dynamic>? overlay;
  final List<Map<String, dynamic>> overlaySegments;
  final double frameAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: AspectRatio(
              aspectRatio: frameAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    headers: {'Authorization': 'Bearer $accessToken'},
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.panelStrong,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
                      );
                    },
                  ),
                  if (overlay != null)
                    CustomPaint(
                      painter: _SwingSkeletonPainter(
                        overlay: overlay!,
                        segments: overlaySegments,
                      ),
                    ),
                  if (overlay != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: Text(
                            'SKELETON',
                            style: AppTextStyles.micro.copyWith(fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _phaseLabel(keyframe.phaseCode),
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 6),
                Text(
                  '${(keyframe.timestampMs / 1000).toStringAsFixed(2)} SEC · FRAME ${keyframe.frameIndex}',
                  style: AppTextStyles.body,
                ),
                if (keyframe.confidence != null)
                  Text(
                    'CONFIDENCE ${(keyframe.confidence! * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.body,
                  ),
                if (overlay != null)
                  const Text(
                    'LINES: SPINE · SHOULDERS · HIPS',
                    style: AppTextStyles.body,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwingSkeletonPainter extends CustomPainter {
  const _SwingSkeletonPainter({required this.overlay, required this.segments});

  final Map<String, dynamic> overlay;
  final List<Map<String, dynamic>> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final points = _mapValue(overlay['points']);
    if (points == null) return;

    final skeletonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final jointPaint = Paint()..color = Colors.white;
    final guidePaint = Paint()
      ..color = const Color(0xFFB9FF66).withValues(alpha: 0.92)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final faultPaint = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.95)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    for (final segment in segments) {
      final start = _pointOffset(points, segment['from'], size);
      final end = _pointOffset(points, segment['to'], size);
      if (start != null && end != null) {
        canvas.drawLine(start, end, skeletonPaint);
      }
    }

    for (final line in _mapList(overlay['guide_lines'])) {
      final paint = line['style'] == 'fault_reference'
          ? faultPaint
          : guidePaint;
      final start = _pointOffset(points, line['from'], size);
      final end = _pointOffset(points, line['to'], size);
      if (start != null && end != null) {
        canvas.drawLine(start, end, paint);
        continue;
      }
      final x = line['x'];
      if (x is num) {
        final y1 = (line['y1'] as num? ?? 0).clamp(0, 1).toDouble();
        final y2 = (line['y2'] as num? ?? 1).clamp(0, 1).toDouble();
        final dx = x.clamp(0, 1).toDouble() * size.width;
        canvas.drawLine(
          Offset(dx, y1 * size.height),
          Offset(dx, y2 * size.height),
          paint,
        );
      }
    }

    for (final value in points.values) {
      final point = _pointOffsetFromMap(value, size);
      if (point != null) {
        canvas.drawCircle(
          point,
          5.8,
          Paint()..color = Colors.black.withValues(alpha: 0.28),
        );
        canvas.drawCircle(point, 3.4, jointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SwingSkeletonPainter oldDelegate) {
    return oldDelegate.overlay != overlay || oldDelegate.segments != segments;
  }
}

String _phaseLabel(String phaseCode) {
  return switch (phaseCode) {
    'P1' => 'P1 SETUP',
    'P4' => 'P4 TOP',
    'P7' => 'P7 IMPACT',
    'P10' => 'P10 FINISH',
    _ => phaseCode.toUpperCase(),
  };
}

String _percent(Object? value) {
  if (value is num) return '${(value * 100).toStringAsFixed(0)}%';
  return 'UNKNOWN';
}

Map<String, dynamic>? _mapValue(Object? value) {
  if (value == null) return null;
  return Map<String, dynamic>.from(value as Map);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value == null) return const [];
  return (value as List<dynamic>)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  return (value as List<dynamic>).whereType<String>().toList();
}

Map<String, dynamic>? _overlayForPhase(
  Map<String, dynamic>? visualEvidence,
  String phaseCode,
) {
  final overlays = _mapList(visualEvidence?['phase_overlays']);
  for (final overlay in overlays) {
    if (overlay['phase_code'] == phaseCode) return overlay;
  }
  return null;
}

Offset? _pointOffset(Map<String, dynamic> points, Object? name, Size size) {
  if (name is! String) return null;
  return _pointOffsetFromMap(points[name], size);
}

Offset? _pointOffsetFromMap(Object? rawPoint, Size size) {
  if (rawPoint is! Map) return null;
  final x = rawPoint['x'];
  final y = rawPoint['y'];
  if (x is! num || y is! num) return null;
  return Offset(
    x.clamp(0, 1).toDouble() * size.width,
    y.clamp(0, 1).toDouble() * size.height,
  );
}

double _frameAspectRatio(Map<String, dynamic> metrics) {
  final width = metrics['resolution_width'];
  final height = metrics['resolution_height'];
  if (width is num && height is num && width > 0 && height > 0) {
    return (width / height).clamp(0.42, 1.9).toDouble();
  }
  return 16 / 9;
}

String _friendlyAnalysisFailure(String? message) {
  final lower = (message ?? '').toLowerCase();
  if (lower.contains('no frames') || lower.contains('sampled')) {
    return 'The video could not be read frame by frame. Try a shorter MOV or MP4 recorded at normal speed.';
  }
  if (lower.contains('open uploaded video') || lower.contains('opencv')) {
    return 'The uploaded file could not be opened as a supported video. Choose a fresh camera recording and upload again.';
  }
  if (lower.contains('storage') || lower.contains('private storage')) {
    return 'Private video storage was temporarily unavailable. Retry analysis when the backend is healthy.';
  }
  if (lower.contains('timeout')) {
    return 'Analysis took too long for this prototype. Try a shorter 2 to 15 second swing clip.';
  }
  return 'Analysis failed. Try again with a clear 2 to 15 second swing video.';
}
