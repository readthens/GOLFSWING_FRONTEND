import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _skillLevel = 'beginner';

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      eyebrow: 'PROFILE',
      title: 'SET YOUR BASELINE',
      subtitle: 'Choose the level that best matches your current game.',
      child: Column(
        children: [
          SegmentedChoices(
            values: const ['beginner', 'intermediate', 'advanced'],
            selected: _skillLevel,
            onSelected: (value) => setState(() => _skillLevel = value),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'CONTINUE',
            onPressed: () async {
              await ref.read(authControllerProvider).updateProfile({
                'skill_level': _skillLevel,
              });
              if (context.mounted) context.go('/onboarding/handedness');
            },
          ),
        ],
      ),
    );
  }
}

class HandednessScreen extends ConsumerStatefulWidget {
  const HandednessScreen({super.key});

  @override
  ConsumerState<HandednessScreen> createState() => _HandednessScreenState();
}

class _HandednessScreenState extends ConsumerState<HandednessScreen> {
  String _handedness = 'right';

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      eyebrow: 'HANDEDNESS',
      title: 'MATCH YOUR SETUP',
      subtitle: 'Swing analysis depends on left/right orientation.',
      child: Column(
        children: [
          SegmentedChoices(
            values: const ['right', 'left'],
            selected: _handedness,
            onSelected: (value) => setState(() => _handedness = value),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'CONTINUE',
            onPressed: () async {
              await ref.read(authControllerProvider).updateProfile({
                'handedness': _handedness,
              });
              if (context.mounted) context.go('/onboarding/goals');
            },
          ),
        ],
      ),
    );
  }
}

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final Set<String> _goals = {'Fix slice'};

  @override
  Widget build(BuildContext context) {
    const options = [
      'Fix slice',
      'Better contact',
      'More distance',
      'Consistency',
    ];
    return OnboardingShell(
      eyebrow: 'GOALS',
      title: 'CHOOSE YOUR TARGET',
      subtitle:
          'We keep the first report focused on one clear practice direction.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option.toUpperCase()),
                  selected: _goals.contains(option),
                  onSelected: (_) {
                    setState(() {
                      _goals.contains(option)
                          ? _goals.remove(option)
                          : _goals.add(option);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'CONTINUE',
            onPressed: _goals.isEmpty
                ? null
                : () async {
                    await ref.read(authControllerProvider).updateProfile({
                      'goals': _goals.toList(),
                    });
                    if (context.mounted) {
                      context.go('/onboarding/privacy-consent');
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class PrivacyConsentScreen extends ConsumerWidget {
  const PrivacyConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return OnboardingShell(
      eyebrow: 'PRIVACY CONSENT',
      title: 'VIDEO PROCESSING',
      subtitle:
          'Swing videos are private and used to create analysis. You can delete uploads later.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoPanel(
            children: [
              Text('We store videos in private object storage.'),
              Text('We use signed upload links, not public video URLs.'),
              Text(
                'Model training consent will be separate from analysis consent.',
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (auth.state.error != null) ErrorText(auth.state.error!),
          PrimaryButton(
            label: 'I CONSENT',
            onPressed: auth.state.isLoading
                ? null
                : () async {
                    await ref.read(authControllerProvider).acceptVideoConsent();
                    if (context.mounted) context.go('/home');
                  },
          ),
        ],
      ),
    );
  }
}

class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
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
                      Text(eyebrow, style: AppTextStyles.label),
                      const SizedBox(height: 16),
                      Text(title, style: AppTextStyles.title),
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
