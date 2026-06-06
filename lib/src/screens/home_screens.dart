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
                                      Text('OBJECT KEY: ${video.storageKey}'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                const InfoPanel(
                                  children: [
                                    Text(
                                      'AI report is not enabled in Phase 2.',
                                    ),
                                    Text(
                                      'Capture quality is advisory until server media probing arrives.',
                                    ),
                                  ],
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
