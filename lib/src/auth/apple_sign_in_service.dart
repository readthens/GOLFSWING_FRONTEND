import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const appleSignInEnabled = bool.fromEnvironment(
  'APPLE_SIGN_IN_ENABLED',
  defaultValue: false,
);

class AppleSignInPayload {
  const AppleSignInPayload({
    required this.identityToken,
    required this.nonce,
    this.authorizationCode,
    this.fullName,
  });

  final String identityToken;
  final String nonce;
  final String? authorizationCode;
  final String? fullName;
}

class AppleSignInService {
  Future<AppleSignInPayload> signIn({required String nonce}) async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw StateError('Apple did not return an identity token.');
    }
    final givenName = credential.givenName;
    final familyName = credential.familyName;
    final fullName = [
      givenName,
      familyName,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' ');
    return AppleSignInPayload(
      identityToken: identityToken,
      nonce: nonce,
      authorizationCode: credential.authorizationCode,
      fullName: fullName.isEmpty ? null : fullName,
    );
  }
}
