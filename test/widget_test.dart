import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:swinglens_ai/src/api/api_client.dart';
import 'package:swinglens_ai/src/app.dart';
import 'package:swinglens_ai/src/auth/auth_controller.dart';
import 'package:swinglens_ai/src/models.dart';

class OnboardingTestAuthController extends AuthController {
  OnboardingTestAuthController()
    : super(ApiClient(baseUrl: 'http://localhost:8000')) {
    state = const AuthState(
      user: UserProfile(id: 'local-test-user', email: 'local-test@example.com'),
      accessToken: 'local-access-token',
      refreshToken: 'local-refresh-token',
    );
  }

  int updateProfileCalls = 0;

  @override
  Future<void> updateProfile(Map<String, dynamic> payload) async {
    updateProfileCalls += 1;
    state = state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    await Future<void>.value();

    final current = state.profile;
    state = state.copyWith(
      isLoading: false,
      profile: GolferProfile(
        userId: state.user!.id,
        handedness: payload['handedness'] as String? ?? current?.handedness,
        skillLevel: payload['skill_level'] as String? ?? current?.skillLevel,
        goals:
            (payload['goals'] as List<dynamic>?)?.cast<String>() ??
            current?.goals ??
            const [],
        commonMiss: payload['common_miss'] as String? ?? current?.commonMiss,
      ),
    );
    notifyListeners();
  }
}

class FailingRegisterApiClient extends ApiClient {
  FailingRegisterApiClient({required this.statusCode, required this.data})
    : super(baseUrl: 'http://localhost:8000');

  final int statusCode;
  final Object data;

  @override
  Future<AuthPayload> register({
    required String email,
    required String password,
  }) async {
    final requestOptions = RequestOptions(path: '/v1/auth/register');
    throw DioException(
      requestOptions: requestOptions,
      response: Response(
        requestOptions: requestOptions,
        statusCode: statusCode,
        data: data,
      ),
    );
  }
}

void main() {
  Future<void> pumpSwingLensApp(
    WidgetTester tester, {
    AuthController? auth,
  }) async {
    final controller =
        auth ?? AuthController(ApiClient(baseUrl: 'http://localhost:8000'));
    controller.state = auth?.state ?? const AuthState();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith((ref) => controller)],
        child: const SwingLensApp(),
      ),
    );
    await tester.pump();
  }

  void setPhoneViewportWithKeyboard(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
    });
  }

  testWidgets('shows SwingLens welcome entrypoint', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(tester);

    expect(find.text('SWINGLENS AI'), findsWidgets);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('sign up form stays usable when the keyboard is visible', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(tester);
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    setPhoneViewportWithKeyboard(tester);
    await tester.enterText(find.byType(TextField).first, 'golfer@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('START YOUR ANALYSIS'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  testWidgets('sign in form stays usable when the keyboard is visible', (
    WidgetTester tester,
  ) async {
    await pumpSwingLensApp(tester);
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    setPhoneViewportWithKeyboard(tester);
    await tester.enterText(find.byType(TextField).first, 'golfer@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('MEMBER ACCESS'), findsOneWidget);
    expect(find.text('SIGN IN'), findsWidgets);
  });

  testWidgets(
    'profile onboarding advances without returning to the first screen',
    (WidgetTester tester) async {
      final auth = OnboardingTestAuthController();
      await pumpSwingLensApp(tester, auth: auth);
      await tester.pumpAndSettle();

      expect(find.text('SET YOUR BASELINE'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'CONTINUE'));
      await tester.tap(find.widgetWithText(FilledButton, 'CONTINUE'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(auth.updateProfileCalls, 1);
      expect(find.text('MATCH YOUR SETUP'), findsOneWidget);
      expect(find.text('SET YOUR BASELINE'), findsNothing);
    },
  );

  test('register surfaces duplicate email from the API', () async {
    final auth = AuthController(
      FailingRegisterApiClient(
        statusCode: 409,
        data: {'detail': 'Email is already registered'},
      ),
    );
    auth.state = const AuthState();

    await auth.register('golfer@example.com', 'password123');

    expect(auth.state.error, 'Email is already registered.');
  });

  test('register surfaces validation guidance from the API', () async {
    final auth = AuthController(
      FailingRegisterApiClient(
        statusCode: 422,
        data: {
          'detail': [
            {'msg': 'String should have at least 8 characters'},
          ],
        },
      ),
    );
    auth.state = const AuthState();

    await auth.register('golfer@example.com', 'short');

    expect(
      auth.state.error,
      'Enter a valid email and a password with at least 8 characters.',
    );
  });
}
