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

  setUp(() async {
    await const FlutterSecureStorage().deleteAll();
  });

  testWidgets('live Phase 4.7 corrected film room checkpoints', (tester) async {
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
    await _markForScreenshot(binding, 'swing_library');

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
    await _markForScreenshot(binding, 'film_room_initial');

    for (final phaseCode in const ['P1', 'P4', 'P7', 'P10']) {
      final chip = find.byKey(ValueKey('phase-chip-$phaseCode'));
      await _waitForFinder(tester, chip);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('EVENT '), findsWidgets);
      await _markForScreenshot(binding, 'checkpoint_$phaseCode');
    }

    final slowChip = find.byKey(const ValueKey('speed-chip-0.25'));
    await tester.ensureVisible(slowChip);
    await tester.pumpAndSettle();
    await tester.tap(slowChip);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await _markForScreenshot(binding, 'slow_motion');

    expect(
      find.byKey(const ValueKey('fault-chip-loss_of_posture')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _markForScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String label,
) async {
  debugPrint('PHASE47 $label');
  final bytes = await binding.takeScreenshot('phase47_$label');
  final file = File('${Directory.systemTemp.path}/phase47_$label.png');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('PHASE47_SCREENSHOT ${file.path}');
  await Future<void>.delayed(const Duration(seconds: 5));
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
