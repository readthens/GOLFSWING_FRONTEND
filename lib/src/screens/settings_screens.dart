import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../billing/revenuecat_service.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).state;
    return _SettingsShell(
      title: 'SETTINGS',
      onBack: () => context.go('/home'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoPanel(
            children: [
              const Text('ACCOUNT', style: AppTextStyles.label),
              Text(auth.user?.email.toUpperCase() ?? 'SIGNED IN'),
              Text(
                'USER ID: ${auth.user?.id ?? 'UNKNOWN'}',
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 12),
          PanelButton(
            title: 'SUBSCRIPTION',
            subtitle: 'Entitlement, restore, and App Store management.',
            onPressed: () => context.go('/settings/subscription'),
          ),
          const SizedBox(height: 12),
          PanelButton(
            title: 'PRIVACY AND DATA',
            subtitle: 'Data inventory, policy links, and account controls.',
            onPressed: () => context.go('/settings/privacy'),
          ),
          const SizedBox(height: 12),
          PanelButton(
            title: 'DELETE ACCOUNT',
            subtitle: 'Remove account records and private swing media.',
            onPressed: () => context.go('/settings/delete-account'),
          ),
          const Spacer(),
          GhostButton(
            label: 'SIGN OUT',
            onPressed: () => ref.read(authControllerProvider).logout(),
          ),
        ],
      ),
    );
  }
}

class PrivacyDataScreen extends ConsumerWidget {
  const PrivacyDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    return _SettingsShell(
      title: 'PRIVACY',
      onBack: () => context.go('/settings'),
      child: token == null
          ? const ErrorText('Sign in required.')
          : FutureBuilder<PrivacyInventory>(
              future: ref.read(apiClientProvider).getPrivacyInventory(token),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const ErrorText('Unable to load privacy inventory.');
                }
                final inventory = snapshot.data!;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoPanel(
                        children: [
                          const Text(
                            'DATA INVENTORY',
                            style: AppTextStyles.label,
                          ),
                          _InventoryLine(
                            label: 'UPLOADS',
                            value: inventory.uploads['count'],
                          ),
                          _InventoryLine(
                            label: 'VIDEOS',
                            value: inventory.swingVideos['count'],
                          ),
                          _InventoryLine(
                            label: 'ANALYSIS RESULTS',
                            value: inventory.analysis['results'],
                          ),
                          _InventoryLine(
                            label: 'TRACER RESULTS',
                            value: inventory.shotTracer['results'],
                          ),
                          _InventoryLine(
                            label: 'CLUB BAG ITEMS',
                            value: inventory.clubBag['count'],
                          ),
                          _InventoryLine(
                            label: 'FAVORITES',
                            value: inventory.favorites['count'],
                          ),
                          _InventoryLine(
                            label: 'FAVORITE FOLDERS',
                            value: inventory.favorites['folders'],
                          ),
                          _InventoryLine(
                            label: 'POSE FRAMES',
                            value: inventory.analysis['pose_frames'],
                          ),
                          _InventoryLine(
                            label: 'ENTITLEMENTS',
                            value: inventory.entitlements['count'],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GhostButton(
                        label: 'PRIVACY POLICY',
                        onPressed: () =>
                            _launch(inventory.links['privacy_policy']),
                      ),
                      const SizedBox(height: 12),
                      GhostButton(
                        label: 'TERMS',
                        onPressed: () => _launch(inventory.links['terms']),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  late Future<RevenueCatCustomer> _future;
  bool _isRestoring = false;
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<RevenueCatCustomer> _load() async {
    final token = ref.read(authControllerProvider).state.accessToken;
    if (token == null) throw StateError('Sign in required.');
    return ref.read(apiClientProvider).getRevenueCatCustomer(token);
  }

  Future<void> _sync() async {
    final token = ref.read(authControllerProvider).state.accessToken;
    if (token == null) return;
    setState(() {
      _restoreError = null;
      _future = ref.read(apiClientProvider).syncRevenueCatCustomer(token);
    });
  }

  Future<void> _restorePurchases() async {
    final token = ref.read(authControllerProvider).state.accessToken;
    if (token == null || _isRestoring) return;
    setState(() {
      _isRestoring = true;
      _restoreError = null;
    });
    try {
      await ref.read(revenueCatServiceProvider).restorePurchases();
      final synced = ref.read(apiClientProvider).syncRevenueCatCustomer(token);
      setState(() {
        _future = synced;
      });
      await synced;
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoreError = 'Unable to restore purchases.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      title: 'SUBSCRIPTION',
      onBack: () => context.go('/settings'),
      child: FutureBuilder<RevenueCatCustomer>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const ErrorText('Unable to load subscription status.');
          }
          final customer = snapshot.data!;
          final entitlement = customer.activeEntitlements.isEmpty
              ? null
              : customer.activeEntitlements.first;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoPanel(
                  children: [
                    const Text('ENTITLEMENT', style: AppTextStyles.label),
                    Text(customer.isEntitled ? 'ACTIVE' : 'NOT ACTIVE'),
                    Text(
                      'APP USER ID: ${customer.appUserId}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('ENTITLEMENT ID: ${customer.entitlementId}'),
                    if (entitlement?.productId != null)
                      Text('PRODUCT: ${entitlement!.productId}'),
                    if (entitlement?.expiresAt != null)
                      Text('EXPIRES: ${entitlement!.expiresAt}'),
                  ],
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: 'SYNC ENTITLEMENT', onPressed: _sync),
                const SizedBox(height: 12),
                GhostButton(
                  label: _isRestoring ? 'RESTORING...' : 'RESTORE PURCHASES',
                  onPressed: _isRestoring ? null : _restorePurchases,
                ),
                if (_restoreError != null) ...[
                  const SizedBox(height: 8),
                  ErrorText(_restoreError!),
                ],
                const SizedBox(height: 12),
                GhostButton(
                  label: 'MANAGE APP STORE SUBSCRIPTION',
                  onPressed: () =>
                      _launch('https://apps.apple.com/account/subscriptions'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmation = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confirmation.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).state;
    final canDelete = _confirmation.text.trim() == 'DELETE' && !auth.isLoading;
    return _SettingsShell(
      title: 'DELETE ACCOUNT',
      onBack: () => context.go('/settings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoPanel(
            children: [
              Text('ACCOUNT DELETION', style: AppTextStyles.label),
              Text(
                'Private videos, swing sessions, analysis results, and local entitlement records will be removed.',
              ),
              Text(
                'App Store subscriptions must be cancelled through Apple account settings.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(controller: _confirmation, label: 'TYPE DELETE'),
          const SizedBox(height: 12),
          if (auth.error != null) ErrorText(auth.error!),
          PrimaryButton(
            label: auth.isLoading ? 'DELETING...' : 'DELETE ACCOUNT',
            onPressed: canDelete ? _delete : null,
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    await ref.read(authControllerProvider).deleteAccount();
    if (mounted && !ref.read(authControllerProvider).state.isAuthenticated) {
      context.go('/welcome');
    }
  }
}

class _InventoryLine extends StatelessWidget {
  const _InventoryLine({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Text('$label: ${value ?? 0}');
  }
}

class _SettingsShell extends StatelessWidget {
  const _SettingsShell({
    required this.title,
    required this.child,
    required this.onBack,
  });

  final String title;
  final Widget child;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              Text(title, style: AppTextStyles.title),
              const SizedBox(height: 18),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _launch(String? url) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
