import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';

import 'package:swinglens_ai/src/api/api_client.dart';
import 'package:swinglens_ai/src/app.dart';
import 'package:swinglens_ai/src/auth/auth_controller.dart';
import 'package:swinglens_ai/src/offline/offline_queue.dart';
import 'package:swinglens_ai/src/router.dart';
import 'package:swinglens_ai/src/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('SMOKE_EMAIL');
  const password = String.fromEnvironment('SMOKE_PASSWORD');

  setUp(() async {
    await const FlutterSecureStorage().deleteAll();
  });

  testWidgets('live Phase 7 automatic sync retries queued work', (
    tester,
  ) async {
    expect(email, isNotEmpty, reason: 'Pass SMOKE_EMAIL with --dart-define.');
    expect(
      password,
      isNotEmpty,
      reason: 'Pass SMOKE_PASSWORD with --dart-define.',
    );

    await tester.pumpWidget(const ProviderScope(child: _Phase7LiveTestApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, email);
    await tester.enterText(find.byType(EditableText).last, password);
    await tester.tap(find.widgetWithText(FilledButton, 'SIGN IN'));
    await _waitForText(
      tester,
      'COMMAND CENTER',
      timeout: const Duration(seconds: 20),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Phase7LiveTestApp)),
      listen: false,
    );
    final token = await _waitForToken(tester, container);
    final api = container.read(apiClientProvider);
    final queue = container.read(offlineQueueProvider);
    await queue.clear();

    final sessions = await api.getSwingSessions(token);
    expect(sessions, isNotEmpty);
    final session = sessions.first;
    for (final favorite in await api.getFavorites(
      token,
      entityType: 'swing_session',
      entityId: session.id,
    )) {
      await api.deleteFavorite(token, favorite.id);
    }

    final favoriteQueueItem = await queue.enqueue(
      action: 'favorite.save',
      title: 'Live favorite queued',
      payload: {
        'entity_type': 'swing_session',
        'entity_id': session.id,
        'metadata': <String, dynamic>{},
      },
    );
    await _waitFor(
      tester,
      () => queue.pendingCount == 0,
      timeout: const Duration(seconds: 20),
      reason: 'favorite queue did not drain',
    );
    final syncedFavorites = await api.getFavorites(
      token,
      entityType: 'swing_session',
      entityId: session.id,
    );
    expect(syncedFavorites, hasLength(1));
    expect(favoriteQueueItem.id, startsWith('offline-favorite.save-'));

    final rounds = await api.getRounds(token);
    expect(rounds, isNotEmpty);
    final round = rounds.first;
    final liveTitle = 'Phase 7 Sync ${DateTime.now().millisecondsSinceEpoch}';
    await queue.enqueue(
      action: 'round.update',
      title: 'Live round edit queued',
      payload: {
        'round_id': round.id,
        'fields': {'title': liveTitle},
      },
    );
    await _waitFor(
      tester,
      () => queue.pendingCount == 0,
      timeout: const Duration(seconds: 20),
      reason: 'round queue did not drain',
    );
    await _waitFor(
      tester,
      () async => (await api.getRound(token, round.id)).title == liveTitle,
      timeout: const Duration(seconds: 20),
      reason: 'round title did not sync',
    );

    final tempDir = await Directory.systemTemp.createTemp('phase7-sync-smoke-');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final uploadFile = File('${tempDir.path}/phase7-sync-smoke.mp4');
    await uploadFile.writeAsBytes(
      List<int>.generate(4096, (index) => index % 255),
    );
    final liveUploadClub =
        'Phase7 Sync ${DateTime.now().millisecondsSinceEpoch}';
    await queue.enqueueSwingUpload(
      file: XFile(uploadFile.path, name: 'phase7-sync-smoke.mp4'),
      club: liveUploadClub,
      angle: 'down_the_line',
      locationType: 'range',
      sessionType: 'analysis',
      durationMs: 4200,
      resolutionWidth: 1920,
      resolutionHeight: 1080,
      captureMetadata: const UploadCaptureMetadata(
        source: 'gallery',
        guideOverlay: false,
        platform: 'ios_simulator',
        fileExtension: '.mp4',
      ).toJson(),
    );
    await _waitFor(
      tester,
      () => queue.pendingCount == 0,
      timeout: const Duration(seconds: 35),
      reason: 'upload queue did not drain',
    );
    await _waitFor(
      tester,
      () async {
        final syncedSessions = await api.getSwingSessions(token);
        return syncedSessions
                .where(
                  (item) =>
                      item.club == liveUploadClub && item.videos.isNotEmpty,
                )
                .length ==
            1;
      },
      timeout: const Duration(seconds: 20),
      reason: 'queued upload did not create exactly one session',
    );

    await queue.enqueue(
      action: 'upload.swing_video',
      title: 'Missing upload queued',
      payload: {
        'local_file_path': '${tempDir.path}/missing-upload.mov',
        'file_name': 'missing-upload.mov',
        'club': '7 iron',
        'angle': 'down_the_line',
        'location_type': 'range',
        'session_type': 'analysis',
        'capture_metadata': const UploadCaptureMetadata(
          source: 'gallery',
          guideOverlay: false,
          fileExtension: '.mov',
        ).toJson(),
      },
    );
    await _waitFor(
      tester,
      () =>
          queue.pendingCount == 1 &&
          queue.items.single.lastError?.contains(
                'Queued upload file is missing',
              ) ==
              true,
      timeout: const Duration(seconds: 20),
      reason: 'missing upload did not enter failed state',
    );
    container.read(routerProvider).go('/profile/sync');
    await _waitForText(tester, 'SYNC CENTER');
    await _waitForText(tester, 'FAILED');
    await _waitForText(tester, 'Queued upload file is missing');

    await queue.clear();
    expect(tester.takeException(), isNull);
  });
}

class _Phase7LiveTestApp extends ConsumerWidget {
  const _Phase7LiveTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return OfflineSyncCoordinator(
      minRetryInterval: Duration.zero,
      child: MaterialApp.router(
        title: 'SwingLens AI',
        debugShowCheckedModeBanner: false,
        theme: buildSwingLensTheme(),
        routerConfig: router,
      ),
    );
  }
}

Future<String> _waitForToken(
  WidgetTester tester,
  ProviderContainer container,
) async {
  String? token;
  await _waitFor(
    tester,
    () {
      token = container.read(authControllerProvider).state.accessToken;
      return token != null;
    },
    timeout: const Duration(seconds: 10),
    reason: 'auth token was not hydrated',
  );
  return token!;
}

Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await _waitFor(
    tester,
    () => find.textContaining(text).evaluate().isNotEmpty,
    timeout: timeout,
    reason: 'Timed out waiting for "$text"',
  );
  await tester.pumpAndSettle();
}

Future<void> _waitFor(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  required Duration timeout,
  required String reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail(reason);
}
