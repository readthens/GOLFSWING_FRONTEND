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
    if (job != null && job.isActive) {
      return InfoPanel(
        children: [
          const Text('ANALYSIS PROTOTYPE', style: AppTextStyles.label),
          Text('${job.status.toUpperCase()} · ${job.progress}%'),
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
          Text(job.errorMessage ?? 'Analysis failed.'),
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
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _AnalysisKeyframeTile extends StatelessWidget {
  const _AnalysisKeyframeTile({
    required this.keyframe,
    required this.accessToken,
    required this.imageUrl,
  });

  final AnalysisKeyframe keyframe;
  final String accessToken;
  final String imageUrl;

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
              aspectRatio: 16 / 9,
              child: Image.network(
                imageUrl,
                headers: {'Authorization': 'Bearer $accessToken'},
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.panelStrong,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined),
                  );
                },
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
              ],
            ),
          ),
        ],
      ),
    );
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
