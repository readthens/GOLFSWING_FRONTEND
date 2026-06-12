import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:swinglens_ai/src/app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('SMOKE_EMAIL');
  const password = String.fromEnvironment('SMOKE_PASSWORD');
  const artifactDir = String.fromEnvironment('SMOKE_ARTIFACT_DIR');

  setUp(() async {
    await const FlutterSecureStorage().deleteAll();
  });

  testWidgets('live Phase 4.8 event review and deep report', (tester) async {
    expect(email, isNotEmpty, reason: 'Pass SMOKE_EMAIL with --dart-define.');
    expect(
      password,
      isNotEmpty,
      reason: 'Pass SMOKE_PASSWORD with --dart-define.',
    );

    await tester.pumpWidget(const ProviderScope(child: SwingLensApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, email);
    await tester.enterText(find.byType(EditableText).last, password);
    await tester.tap(find.widgetWithText(FilledButton, 'SIGN IN'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('COMMAND CENTER'), findsOneWidget);
    await tester.tap(find.text('Swing'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('SWING LIBRARY'), findsOneWidget);
    await _markForScreenshot(binding, artifactDir, 'swing_library');

    await tester.tap(find.textContaining('7 IRON').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('SWING DETAIL'), findsOneWidget);
    await _waitForText(tester, 'VIEW FULL BREAKDOWN');
    await tester.ensureVisible(find.text('VIEW FULL BREAKDOWN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIEW FULL BREAKDOWN'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('ANALYSIS BREAKDOWN'), findsOneWidget);
    await _waitForText(tester, 'SWING FILM ROOM');
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('film-room-slider')),
    );

    final videoSurface = find.byKey(const ValueKey('film-room-video-surface'));
    await tester.ensureVisible(videoSurface);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await _markForScreenshot(binding, artifactDir, 'film_room');

    final p4Chip = find.byKey(const ValueKey('phase-chip-P4'));
    await _waitForFinder(tester, p4Chip);
    await tester.ensureVisible(p4Chip);
    await tester.pumpAndSettle();
    await tester.tap(p4Chip);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final adjustButton = find.text('ADJUST EVENTS');
    await tester.ensureVisible(adjustButton);
    await tester.pumpAndSettle();
    await tester.tap(adjustButton);
    await tester.pumpAndSettle();
    expect(find.text('SET P1'), findsOneWidget);
    await _markForScreenshot(binding, artifactDir, 'adjust_mode');

    await tester.tap(find.byKey(const ValueKey('review-phase-P4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('set-review-phase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-event-review')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _waitForText(tester, 'P4 REVIEWED');
    await tester.ensureVisible(find.byKey(const ValueKey('phase-chip-P4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('phase-chip-P4')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await _markForScreenshot(binding, artifactDir, 'reviewed_checkpoint');

    await _waitForText(tester, 'FULL REPORT');
    await tester.ensureVisible(find.text('FULL REPORT'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.textContaining('MOVEMENT SCORE:'), findsOneWidget);
    await _markForScreenshot(binding, artifactDir, 'full_report');

    await tester.ensureVisible(find.text('ADJUST EVENTS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADJUST EVENTS'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reset-event-review')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('P4 REVIEWED'), findsNothing);
    await _markForScreenshot(binding, artifactDir, 'reset_detection');

    expect(tester.takeException(), isNull);
  });
}

Future<void> _markForScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String artifactDir,
  String label,
) async {
  debugPrint('PHASE48 $label');
  final bytes = await binding.takeScreenshot('phase48_$label');
  final outputDir = artifactDir.isEmpty
      ? Directory.systemTemp.path
      : artifactDir;
  final file = File('$outputDir/phase48_$label.png');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('PHASE48_SCREENSHOT ${file.path}');
  await Future<void>.delayed(const Duration(seconds: 2));
}

Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  await _waitForFinder(tester, find.text(text), timeout: timeout);
}

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(seconds: 1));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder.');
}
