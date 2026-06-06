import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:swinglens_ai/src/api/api_client.dart';
import 'package:swinglens_ai/src/auth/auth_controller.dart';
import 'package:swinglens_ai/src/models.dart';
import 'package:swinglens_ai/src/screens/home_screens.dart';
import 'package:swinglens_ai/src/screens/upload_screens.dart';
import 'package:swinglens_ai/src/theme/app_theme.dart';

class _ReadyAuthController extends AuthController {
  _ReadyAuthController() : super(ApiClient(baseUrl: 'http://localhost:8000')) {
    state = const AuthState(
      user: UserProfile(
        id: 'integration-user',
        email: 'integration@example.com',
      ),
      profile: GolferProfile(
        userId: 'integration-user',
        handedness: 'right',
        skillLevel: 'intermediate',
        goals: ['clean_contact'],
      ),
      accessToken: 'integration-access-token',
      refreshToken: 'integration-refresh-token',
      hasVideoConsent: true,
    );
  }
}

class _NoConsentAuthController extends AuthController {
  _NoConsentAuthController()
    : super(ApiClient(baseUrl: 'http://localhost:8000')) {
    state = const AuthState(
      user: UserProfile(
        id: 'integration-user',
        email: 'integration@example.com',
      ),
      accessToken: 'integration-access-token',
      refreshToken: 'integration-refresh-token',
    );
  }
}

class _SwingDetailApiClient extends ApiClient {
  _SwingDetailApiClient() : super(baseUrl: 'http://localhost:8000');

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
          'storage_key': 'users/integration/uploads/upload-1/swing.mp4',
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    await tester.pumpAndSettle();
  }

  testWidgets('Phase 2 capture consent gate renders on simulator', (
    tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const UploadScreen(),
      auth: _NoConsentAuthController(),
    );

    expect(find.text('GUIDED CAPTURE'), findsOneWidget);
    expect(
      find.text('Video-processing consent is required before upload.'),
      findsOneWidget,
    );
    expect(find.text('REVIEW CONSENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 2 capture controls render on simulator', (tester) async {
    await pumpStandalone(
      tester,
      child: const UploadScreen(),
      auth: _ReadyAuthController(),
    );

    expect(find.text('RECORD VIDEO'), findsOneWidget);
    expect(find.text('CHOOSE VIDEO'), findsOneWidget);
    expect(find.text('FACE ON'), findsOneWidget);
    expect(find.text('DOWN THE LINE'), findsOneWidget);
    expect(find.text('REAR TRACER'), findsNothing);
    expect(find.text('UPLOAD SWING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 2 record fallback does not block simulator testing', (
    tester,
  ) async {
    await pumpStandalone(
      tester,
      child: const UploadScreen(),
      auth: _ReadyAuthController(),
    );

    await tester.tap(find.text('RECORD VIDEO'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final unavailableNotice = find.text(
      'Camera is unavailable here. Choose a saved video to keep testing.',
    );
    final noCameraNotice = find.text(
      'No camera is available here. Choose a saved video to keep testing.',
    );
    final recordingState = find.text('STOP RECORDING');
    expect(
      unavailableNotice.evaluate().isNotEmpty ||
          noCameraNotice.evaluate().isNotEmpty ||
          recordingState.evaluate().isNotEmpty,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 2 quality detail renders on simulator', (tester) async {
    await pumpStandalone(
      tester,
      child: const SwingDetailScreen(sessionId: 'session-1'),
      auth: _ReadyAuthController(),
      apiClient: _SwingDetailApiClient(),
    );

    expect(find.text('QUALITY: WARN'), findsOneWidget);
    expect(find.text('SCORE: 80'), findsOneWidget);
    expect(find.text('DURATION: 4.2 SEC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
