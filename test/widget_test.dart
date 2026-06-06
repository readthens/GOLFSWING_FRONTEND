import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:swinglens_ai/src/api/api_client.dart';
import 'package:swinglens_ai/src/app.dart';
import 'package:swinglens_ai/src/auth/auth_controller.dart';
import 'package:swinglens_ai/src/screens/home_screens.dart';
import 'package:swinglens_ai/src/screens/upload_screens.dart';
import 'package:swinglens_ai/src/theme/app_theme.dart';
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

class ReadyTestAuthController extends AuthController {
  ReadyTestAuthController()
    : super(ApiClient(baseUrl: 'http://localhost:8000')) {
    state = const AuthState(
      user: UserProfile(id: 'local-test-user', email: 'local-test@example.com'),
      profile: GolferProfile(
        userId: 'local-test-user',
        handedness: 'right',
        skillLevel: 'intermediate',
        goals: ['clean_contact'],
      ),
      accessToken: 'local-access-token',
      refreshToken: 'local-refresh-token',
      hasVideoConsent: true,
    );
  }
}

class NoConsentTestAuthController extends AuthController {
  NoConsentTestAuthController()
    : super(ApiClient(baseUrl: 'http://localhost:8000')) {
    state = const AuthState(
      user: UserProfile(id: 'local-test-user', email: 'local-test@example.com'),
      accessToken: 'local-access-token',
      refreshToken: 'local-refresh-token',
    );
  }
}

class SwingDetailApiClient extends ApiClient {
  SwingDetailApiClient() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<SwingSession> getSwingSession(
    String accessToken,
    String sessionId,
  ) async {
    return SwingSession.fromJson({
      'id': sessionId,
      'status': 'video_uploaded',
      'club': '7 iron',
      'location_type': 'range',
      'created_at': '2026-06-06T00:00:00Z',
      'videos': [
        {
          'id': 'video-1',
          'upload_id': 'upload-1',
          'storage_key': 'users/local/uploads/upload-1/swing.mp4',
          'angle': 'down_the_line',
          'duration_ms': 4200,
          'quality_score': 80,
          'quality_status': 'warn',
          'quality_checks': [
            {
              'id': 'guide_overlay',
              'severity': 'warn',
              'message':
                  'Gallery videos may not use the SwingLens capture guide.',
            },
          ],
        },
      ],
    });
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

  Future<void> pumpStandalone(
    WidgetTester tester, {
    required Widget child,
    required AuthController auth,
    ApiClient? apiClient,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
        ],
        child: MaterialApp(theme: buildSwingLensTheme(), home: child),
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

  testWidgets('guided capture requires video consent', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const UploadScreen(),
      auth: NoConsentTestAuthController(),
    );

    expect(find.text('GUIDED CAPTURE'), findsOneWidget);
    expect(
      find.text('Video-processing consent is required before upload.'),
      findsOneWidget,
    );
    expect(find.text('REVIEW CONSENT'), findsOneWidget);
    expect(find.text('RECORD VIDEO'), findsNothing);
  });

  testWidgets(
    'guided capture exposes phase 2 controls and disables upload without media',
    (WidgetTester tester) async {
      await pumpStandalone(
        tester,
        child: const UploadScreen(),
        auth: ReadyTestAuthController(),
      );

      expect(find.text('RECORD VIDEO'), findsOneWidget);
      expect(find.text('CHOOSE VIDEO'), findsOneWidget);
      expect(find.text('FACE ON'), findsOneWidget);
      expect(find.text('DOWN THE LINE'), findsOneWidget);
      expect(find.text('REAR TRACER'), findsNothing);
      expect(find.text('DRIVER'), findsOneWidget);
      expect(find.text('RANGE'), findsOneWidget);

      final upload = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'UPLOAD SWING'),
      );
      expect(upload.onPressed, isNull);
    },
  );

  testWidgets('swing detail renders backend quality results', (
    WidgetTester tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: ReadyTestAuthController(),
      apiClient: SwingDetailApiClient(),
    );
    await tester.pumpAndSettle();

    expect(find.text('QUALITY: WARN'), findsOneWidget);
    expect(find.text('SCORE: 80'), findsOneWidget);
    expect(find.text('DURATION: 4.2 SEC'), findsOneWidget);
    expect(
      find.text(
        'WARN: Gallery videos may not use the SwingLens capture guide.',
      ),
      findsOneWidget,
    );
  });

  test('upload capture metadata serializes phase 2 fields', () {
    const metadata = UploadCaptureMetadata(
      source: 'camera',
      guideOverlay: true,
      platform: 'ios',
      cameraLensDirection: 'back',
      nativeHighFpsAvailable: false,
      fileExtension: '.mov',
    );

    expect(metadata.toJson(), {
      'source': 'camera',
      'guide_overlay': true,
      'platform': 'ios',
      'camera_lens_direction': 'back',
      'native_high_fps_available': false,
      'file_extension': '.mov',
    });
  });
}
