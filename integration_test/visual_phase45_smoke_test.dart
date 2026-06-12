import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:swinglens_ai/src/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('SMOKE_EMAIL');
  const password = String.fromEnvironment('SMOKE_PASSWORD');

  setUp(() async {
    await const FlutterSecureStorage().deleteAll();
  });

  testWidgets('visual Phase 4.5 upload, running, and diagnosis states', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const ValueKey('home-action-record_swing')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('GUIDED CAPTURE'), findsOneWidget);
    debugPrint('VISUAL_PHASE upload_screen');
    await tester.pump(const Duration(seconds: 6));

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Swing'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.textContaining('7 IRON').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('START ANALYSIS'), findsOneWidget);

    await tester.ensureVisible(find.text('START ANALYSIS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START ANALYSIS'));
    await tester.pump(const Duration(milliseconds: 600));
    await _waitForAnyText(tester, const ['PENDING ·', 'RUNNING ·']);
    debugPrint('VISUAL_PHASE analysis_running');
    await tester.pump(const Duration(seconds: 6));

    await _waitForText(
      tester,
      'ANALYSIS REVIEW',
      timeout: const Duration(seconds: 90),
    );
    await tester.ensureVisible(find.text('VIEW FULL BREAKDOWN'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('EVIDENCE REPLAY'), findsOneWidget);
    debugPrint('VISUAL_PHASE diagnosis_result');
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(seconds: 1));
    if (find.text(text).evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for "$text".');
}

Future<void> _waitForAnyText(
  WidgetTester tester,
  List<String> textParts, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(seconds: 1));
    final hasMatch = textParts.any(
      (text) => find.textContaining(text).evaluate().isNotEmpty,
    );
    if (hasMatch) return;
  }
  fail('Timed out waiting for any of: ${textParts.join(', ')}.');
}
