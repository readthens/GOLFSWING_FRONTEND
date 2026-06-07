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
  const expectDiagnosis = bool.fromEnvironment('EXPECT_DIAGNOSIS');

  setUp(() async {
    await const FlutterSecureStorage().deleteAll();
  });

  testWidgets('live Phase 3 account can open analysis detail', (tester) async {
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

    expect(find.text('CAPTURE A CLEAN SWING'), findsOneWidget);

    await tester.tap(find.text('SWING LIBRARY'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('SWING LIBRARY'), findsOneWidget);
    await tester.tap(find.textContaining('7 IRON').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('SWING DETAIL'), findsOneWidget);
    expect(find.text('ANALYSIS PROTOTYPE'), findsOneWidget);
    expect(find.textContaining('Prototype analysis sampled'), findsOneWidget);
    if (expectDiagnosis) {
      expect(find.text('MVP DIAGNOSIS'), findsOneWidget);
    }
    expect(find.text('P1 SETUP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
