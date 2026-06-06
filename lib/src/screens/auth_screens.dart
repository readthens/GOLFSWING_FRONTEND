import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

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
      subtitle: 'Upload a swing, find the issue, and build the next practice plan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(label: 'CREATE ACCOUNT', onPressed: () => context.go('/auth/sign-up')),
          const SizedBox(height: 12),
          GhostButton(label: 'SIGN IN', onPressed: () => context.go('/auth/sign-in')),
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
        onSubmit: () => ref.read(authControllerProvider).login(_email.text, _password.text),
        footer: TextButton(
          onPressed: () => context.go('/auth/sign-up'),
          child: const Text('CREATE PROFILE'),
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
        onSubmit: () => ref.read(authControllerProvider).register(_email.text, _password.text),
        footer: TextButton(
          onPressed: () => context.go('/auth/sign-in'),
          child: const Text('I ALREADY HAVE ACCESS'),
        ),
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
    super.key,
  });

  final TextEditingController email;
  final TextEditingController password;
  final String actionLabel;
  final VoidCallback onSubmit;
  final bool isLoading;
  final String? error;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(controller: email, label: 'EMAIL', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        AppTextField(controller: password, label: 'PASSWORD', obscureText: true),
        const SizedBox(height: 18),
        if (error != null) ErrorText(error!),
        PrimaryButton(label: actionLabel, onPressed: isLoading ? null : onSubmit),
        const SizedBox(height: 12),
        if (footer != null) Center(child: footer!),
      ],
    );
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SWINGLENS AI', style: AppTextStyles.micro),
              const Spacer(),
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
  }
}

