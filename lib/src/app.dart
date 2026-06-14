import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'auth/auth_controller.dart';
import 'offline/offline_queue.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class SwingLensApp extends ConsumerWidget {
  const SwingLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return OfflineSyncCoordinator(
      child: MaterialApp.router(
        title: 'SwingLens AI',
        debugShowCheckedModeBanner: false,
        theme: buildSwingLensTheme(),
        routerConfig: router,
      ),
    );
  }
}

class OfflineSyncCoordinator extends ConsumerStatefulWidget {
  const OfflineSyncCoordinator({
    required this.child,
    this.minRetryInterval = const Duration(seconds: 3),
    super.key,
  });

  final Widget child;
  final Duration minRetryInterval;

  @override
  ConsumerState<OfflineSyncCoordinator> createState() =>
      _OfflineSyncCoordinatorState();
}

class _OfflineSyncCoordinatorState extends ConsumerState<OfflineSyncCoordinator>
    with WidgetsBindingObserver {
  bool _syncScheduled = false;
  DateTime? _lastAutoSyncAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleAutoSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleAutoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      authControllerProvider.select(
        (controller) => controller.state.accessToken,
      ),
      (_, token) {
        if (token != null) _scheduleAutoSync();
      },
    );
    ref.listen<int>(
      offlineQueueProvider.select((queue) => queue.pendingCount),
      (_, pendingCount) {
        if (pendingCount > 0) _scheduleAutoSync();
      },
    );
    return widget.child;
  }

  void _scheduleAutoSync() {
    if (_syncScheduled || !mounted) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncScheduled = false;
      _tryAutoSync();
    });
  }

  Future<void> _tryAutoSync() async {
    final auth = ref.read(authControllerProvider).state;
    final token = auth.accessToken;
    final ownerUserId = auth.user?.id;
    if (token == null || ownerUserId == null) return;
    final queue = ref.read(offlineQueueProvider);
    await queue.load();
    if (!mounted ||
        queue.pendingCountFor(ownerUserId) == 0 ||
        queue.isSyncing) {
      return;
    }

    final now = DateTime.now();
    final lastAutoSyncAt = _lastAutoSyncAt;
    if (lastAutoSyncAt != null &&
        now.difference(lastAutoSyncAt) < widget.minRetryInterval) {
      return;
    }
    _lastAutoSyncAt = now;
    await queue.retryAll(
      accessToken: token,
      apiClient: ref.read(apiClientProvider),
      ownerUserId: ownerUserId,
    );
  }
}
