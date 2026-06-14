import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../auth/apple_sign_in_service.dart';
import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

const _configuredDevLoginEmail = String.fromEnvironment('DEV_LOGIN_EMAIL');
const _configuredDevLoginPassword = String.fromEnvironment(
  'DEV_LOGIN_PASSWORD',
);
const _defaultLocalDevLoginEmail = '';
const _defaultLocalDevLoginPassword = '';
const _devLoginEmail = _configuredDevLoginEmail == ''
    ? _defaultLocalDevLoginEmail
    : _configuredDevLoginEmail;
const _devLoginPassword = _configuredDevLoginPassword == ''
    ? _defaultLocalDevLoginPassword
    : _configuredDevLoginPassword;

bool get _devLoginAvailable =>
    kDebugMode && _devLoginEmail.isNotEmpty && _devLoginPassword.isNotEmpty;

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AuthShell(
      eyebrow: 'SYSTEM BOOT',
      title: 'SWINGLENS AI',
      subtitle: 'Loading your performance workspace.',
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      eyebrow: 'AI GOLF LAB',
      title: 'FIX THE FRAME THAT MATTERS',
      subtitle:
          'Upload a swing, find the issue, and build the next practice plan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: 'CREATE ACCOUNT',
            onPressed: () => context.go('/auth/sign-up'),
          ),
          const SizedBox(height: 12),
          GhostButton(
            label: 'SIGN IN',
            onPressed: () => context.go('/auth/sign-in'),
          ),
        ],
      ),
    );
  }
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  void _fillDevLogin() {
    _email.text = _devLoginEmail;
    _password.text = _devLoginPassword;
    _email.selection = TextSelection.collapsed(offset: _email.text.length);
    _password.selection = TextSelection.collapsed(
      offset: _password.text.length,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthShell(
      eyebrow: 'MEMBER ACCESS',
      title: 'SIGN IN',
      subtitle: 'Continue your swing analysis.',
      child: AuthForm(
        email: _email,
        password: _password,
        actionLabel: 'SIGN IN',
        isLoading: auth.state.isLoading,
        error: auth.state.error,
        onSubmit: () => ref
            .read(authControllerProvider)
            .login(_email.text.trim(), _password.text),
        footer: TextButton(
          onPressed: () => context.go('/auth/sign-up'),
          child: const Text('CREATE PROFILE'),
        ),
        secondary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_devLoginAvailable) ...[
              GhostButton(
                label: 'USE LOCAL TEST ACCOUNT',
                onPressed: _fillDevLogin,
              ),
              const SizedBox(height: 12),
            ],
            const _AppleSignInAction(),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthShell(
      eyebrow: 'CREATE PROFILE',
      title: 'START YOUR ANALYSIS',
      subtitle: 'Save swings and track progress.',
      child: AuthForm(
        email: _email,
        password: _password,
        actionLabel: 'CREATE ACCOUNT',
        isLoading: auth.state.isLoading,
        error: auth.state.error,
        onSubmit: () => ref
            .read(authControllerProvider)
            .register(_email.text.trim(), _password.text),
        footer: TextButton(
          onPressed: () => context.go('/auth/sign-in'),
          child: const Text('I ALREADY HAVE ACCESS'),
        ),
        secondary: const _AppleSignInAction(),
      ),
    );
  }
}

class AuthForm extends StatelessWidget {
  const AuthForm({
    required this.email,
    required this.password,
    required this.actionLabel,
    required this.onSubmit,
    required this.isLoading,
    this.error,
    this.footer,
    this.secondary,
    super.key,
  });

  final TextEditingController email;
  final TextEditingController password;
  final String actionLabel;
  final VoidCallback onSubmit;
  final bool isLoading;
  final String? error;
  final Widget? footer;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: email,
          label: 'EMAIL',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: password,
          label: 'PASSWORD',
          obscureText: true,
        ),
        const SizedBox(height: 18),
        if (error != null) ErrorText(error!),
        PrimaryButton(
          label: actionLabel,
          onPressed: isLoading ? null : onSubmit,
        ),
        if (secondary != null) ...[const SizedBox(height: 12), secondary!],
        const SizedBox(height: 12),
        if (footer != null) Center(child: footer!),
      ],
    );
  }
}

class _AppleSignInAction extends ConsumerStatefulWidget {
  const _AppleSignInAction();

  @override
  ConsumerState<_AppleSignInAction> createState() => _AppleSignInActionState();
}

class _AppleSignInActionState extends ConsumerState<_AppleSignInAction> {
  final _apple = AppleSignInService();
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    if (!appleSignInEnabled) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GhostButton(
          label: _isLoading ? 'WAITING FOR APPLE...' : 'CONTINUE WITH APPLE',
          onPressed: _isLoading ? null : _signIn,
        ),
        if (_error != null) ErrorText(_error!),
      ],
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final nonce = await ref.read(apiClientProvider).createAppleNonce();
      final credential = await _apple.signIn(nonce: nonce.nonceSha256);
      await ref
          .read(authControllerProvider)
          .loginWithApple(
            identityToken: credential.identityToken,
            nonce: credential.nonce,
            fullName: credential.fullName,
            authorizationCode: credential.authorizationCode,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Apple sign-in was not completed.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
            final compact = keyboardVisible || constraints.maxHeight < 680;
            final introGap = compact
                ? 36.0
                : (constraints.maxHeight * 0.38).clamp(120.0, 280.0).toDouble();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48)
                        .clamp(0, double.infinity)
                        .toDouble(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SWINGLENS AI', style: AppTextStyles.micro),
                      SizedBox(height: introGap),
                      Text(eyebrow, style: AppTextStyles.label),
                      const SizedBox(height: 14),
                      Text(title, style: AppTextStyles.hero),
                      const SizedBox(height: 12),
                      Text(subtitle, style: AppTextStyles.body),
                      const SizedBox(height: 30),
                      child,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
