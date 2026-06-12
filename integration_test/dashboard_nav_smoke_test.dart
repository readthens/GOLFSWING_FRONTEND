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

  testWidgets(
    'live dashboard tabs and persisted phase screens render after login',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: SwingLensApp()));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();
      if (email.isNotEmpty && password.isNotEmpty) {
        await tester.enterText(find.byType(EditableText).first, email);
        await tester.enterText(find.byType(EditableText).last, password);
      } else {
        await tester.tap(find.text('USE LOCAL TEST ACCOUNT'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'SIGN IN'));

      await _waitForText(
        tester,
        'COMMAND CENTER',
        timeout: const Duration(seconds: 20),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('home-action-stats')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-action-stats')));
      await _waitForText(tester, 'STATS OVERVIEW');

      await tester.tap(find.byKey(const ValueKey('stats-route-swings')));
      await _waitForText(tester, 'SWING STATS');
      await tester.tap(find.byKey(const ValueKey('stats-route-tracer')));
      await _waitForText(tester, 'SHOT TRACER STATS');
      await tester.tap(find.byKey(const ValueKey('stats-route-rounds')));
      await _waitForText(tester, 'ROUND STATS');
      await tester.tap(find.byKey(const ValueKey('stats-route-clubs')));
      await _waitForText(tester, 'CLUB PERFORMANCE');
      await tester.tap(find.byKey(const ValueKey('stats-route-faults')));
      await _waitForText(tester, 'FAULT TRENDS');
      await tester.tap(find.byKey(const ValueKey('stats-route-overview')));
      await _waitForText(tester, 'STATS OVERVIEW');

      await tester.tap(find.text('Home'));
      await _waitForText(tester, 'COMMAND CENTER');

      await tester.tap(find.text('Tracer'));
      await _waitForText(tester, 'SHOT TRACER');

      await tester.tap(find.text('Profile'));
      await _waitForText(tester, 'PROFILE');
      await tester.tap(find.text('CLUB BAG'));
      await _waitForText(tester, 'ADD CLUB');
      await _waitForText(tester, '6 IRON');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await _waitForText(tester, 'PROFILE');
      await tester.tap(find.text('FAVORITES'));
      await _waitForText(tester, 'FAVORITES');
      await _waitForText(tester, 'PRIORITY REVIEWS');

      await tester.tap(find.text('Rounds'));
      await _waitForText(tester, 'ROUNDS');
      await _waitForText(tester, 'FRONT NINE CHECK');

      await _openHomeRoot(tester);
      await tester.tap(find.byKey(const ValueKey('home-notifications-button')));
      await _waitForText(tester, 'NOTIFICATIONS');
      await _waitForText(tester, 'TRACER NEEDS REVIEW');

      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openHomeRoot(WidgetTester tester) async {
  await tester.tap(find.text('Home'));
  await tester.pumpAndSettle();
  if (find.text('COMMAND CENTER').evaluate().isEmpty) {
    await tester.tap(find.text('Home'));
  }
  await _waitForText(tester, 'COMMAND CENTER');
}

Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.text(text).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Timed out waiting for "$text".');
}
