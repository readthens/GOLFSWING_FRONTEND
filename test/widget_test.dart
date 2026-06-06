import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swinglens_ai/src/api/api_client.dart';
import 'package:swinglens_ai/src/app.dart';
import 'package:swinglens_ai/src/auth/auth_controller.dart';

void main() {
  testWidgets('shows SwingLens welcome entrypoint', (WidgetTester tester) async {
    final auth = AuthController(ApiClient(baseUrl: 'http://localhost:8000'));
    auth.state = const AuthState(isLoading: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith((ref) => auth)],
        child: const SwingLensApp(),
      ),
    );
    await tester.pump();

    expect(find.text('SWINGLENS AI'), findsWidgets);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
  });
}
