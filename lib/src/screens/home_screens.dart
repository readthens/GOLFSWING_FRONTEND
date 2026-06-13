import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../models.dart';
import '../offline/offline_queue.dart';
import '../theme/app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/favorite_toggle_button.dart';
import '../widgets/swing_overlay_painter.dart';
import 'shot_tracer_screens.dart';
import 'swing_film_room.dart';

const _homeGolferProAsset = 'assets/home/center_golfer_pro.png';
const _homeGolferAmateurAsset = 'assets/home/center_golfer_amateur.png';
const _homeGolferJuniorAsset = 'assets/home/center_golfer_junior.png';
const _homeGolferGoldAsset = 'assets/home/center_golfer_gold.png';
const _homeAvatarAsset = 'assets/home/avatar_golfer_camera.png';
const _homeFallbackAvatarAsset = 'assets/home/avatar_fallback.png';
const _homeGolfCourseAsset = 'assets/home/golfcourse.png';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _dashboardToken;
  Future<HomeDashboard>? _dashboardFuture;

  Future<HomeDashboard> _loadDashboard(String token) {
    return ref.read(apiClientProvider).getHomeDashboard(token);
  }

  Future<void> _refreshDashboard() async {
    final token = ref.read(authControllerProvider).state.accessToken;
    if (token == null) return;
    final future = _loadDashboard(token);
    setState(() {
      _dashboardFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // The FutureBuilder owns the visible offline/session-expired state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).state;
    final token = auth.accessToken;
    if (token != null && token != _dashboardToken) {
      _dashboardToken = token;
      _dashboardFuture = _loadDashboard(token);
    }
    return AppScaffold(
      child: SafeArea(
        child: token == null
            ? const EmptyState(
                title: 'SIGN IN REQUIRED',
                body: 'Open SwingLens with an authenticated account.',
              )
            : FutureBuilder<HomeDashboard>(
                future: _dashboardFuture,
                builder: (context, snapshot) {
                  if (_isAuthError(snapshot.error)) {
                    _scheduleLogout();
                    return const EmptyState(
                      title: 'SESSION EXPIRED',
                      body: 'Sign in again to refresh your dashboard.',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _DashboardLoadingState();
                  }
                  final dashboard = snapshot.data ?? _fallbackDashboard(auth);
                  return _HomeDashboardView(
                    accessToken: token,
                    dashboard: dashboard,
                    loadFailed: snapshot.hasError,
                    onRefresh: _refreshDashboard,
                  );
                },
              ),
      ),
    );
  }

  void _scheduleLogout() {
    unawaited(
      Future<void>.microtask(() async {
        if (!mounted) return;
        await ref.read(authControllerProvider).logout();
      }),
    );
  }
}

class _HomeDashboardView extends StatelessWidget {
  const _HomeDashboardView({
    required this.accessToken,
    required this.dashboard,
    required this.loadFailed,
    required this.onRefresh,
  });

  final String accessToken;
  final HomeDashboard dashboard;
  final bool loadFailed;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.textPrimary,
      backgroundColor: AppColors.elevated,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHeader(user: dashboard.user, accessToken: accessToken),
            const SizedBox(height: 20),
            if (loadFailed) ...[
              const _DashboardNotice(
                status: 'OFFLINE',
                body:
                    'Dashboard service unavailable. Core capture actions are still ready.',
              ),
              const SizedBox(height: 18),
            ],
            if (dashboard.priorityItem != null) ...[
              _PriorityRow(item: dashboard.priorityItem),
              const SizedBox(height: 18),
            ],
            _LastGameHeroCard(item: _lastGameItem(dashboard)),
            const SizedBox(height: 24),
            _PerformanceHeroSection(
              user: dashboard.user,
              hero: dashboard.hero,
              section: dashboard.performanceSnapshot,
              focus: dashboard.todayFocus,
            ),
            const SizedBox(height: 24),
            _QuickActionGrid(actions: dashboard.quickActions),
            const SizedBox(height: 24),
            _RecentActivityList(items: dashboard.recentActivity),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('SWINGLENS AI', style: AppTextStyles.micro),
          SizedBox(height: 10),
          Text('COMMAND CENTER', style: AppTextStyles.title),
          SizedBox(height: 18),
          _DashboardNotice(
            status: 'SYNCING',
            body: 'Loading current swing, tracer, and performance state.',
          ),
          SizedBox(height: 44),
          Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader({required this.user, required this.accessToken});

  final Map<String, dynamic> user;
  final String accessToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = _dashboardDisplayName(user);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _HomeWordmark()),
            IconButton(
              key: const ValueKey('home-notifications-button'),
              tooltip: 'Notifications',
              icon: _NotificationBell(accessToken: accessToken),
              onPressed: () => context.go('/notifications'),
            ),
            const SizedBox(width: 8),
            InkWell(
              key: const ValueKey('home-profile-button'),
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.go('/profile'),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x33FFFFFF)),
                  image: const DecorationImage(
                    image: AssetImage(_homeAvatarAsset),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning, $name.',
                    style: AppTextStyles.title.copyWith(
                      fontSize: 27,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Every shot you track makes you better.',
                    style: AppTextStyles.body.copyWith(
                      color: const Color(0xFFB7C0C8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const _WeatherStatusPill(),
          ],
        ),
      ],
    );
  }
}

class _HomeWordmark extends StatelessWidget {
  const _HomeWordmark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.micro.copyWith(
          fontSize: 13,
          letterSpacing: 1.9,
          color: const Color(0xFFF4F6F8),
        ),
        children: const [
          TextSpan(text: 'SWINGLENS '),
          TextSpan(
            text: 'AI',
            style: TextStyle(color: Color(0xFF9FE870)),
          ),
        ],
      ),
    );
  }
}

class _WeatherStatusPill extends StatelessWidget {
  const _WeatherStatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('home-weather-pill'),
      width: 126,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC101418),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wb_sunny_outlined,
            size: 20,
            color: AppColors.signalGold,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '--°',
                  style: AppTextStyles.micro.copyWith(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  'Weather off',
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell({required this.accessToken});

  final String accessToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: ref
          .read(apiClientProvider)
          .getNotificationUnreadCount(accessToken),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none),
            if (count > 0)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  key: const ValueKey('home-notifications-badge'),
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.signalGold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: AppTextStyles.micro.copyWith(color: Colors.black),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({required this.item});

  final DashboardItem? item;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    if (item == null) {
      return const _DashboardNotice(
        status: 'READY',
        body: 'Record a swing or trace a shot when your setup is clean.',
      );
    }
    return InkWell(
      key: const ValueKey('home-priority-row'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openDashboardRoute(context, item.route),
      child: _DashboardNotice(
        status: item.status ?? item.type.toUpperCase(),
        body: item.body ?? item.title,
        trailing: Icons.chevron_right,
      ),
    );
  }
}

class _DashboardNotice extends StatelessWidget {
  const _DashboardNotice({
    required this.status,
    required this.body,
    this.trailing,
  });

  final String status;
  final String body;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _StatusPill(label: status),
          const SizedBox(width: 12),
          Expanded(child: Text(body, style: AppTextStyles.body)),
          if (trailing != null) Icon(trailing, size: 18),
        ],
      ),
    );
  }
}

class _LastGameHeroCard extends StatelessWidget {
  const _LastGameHeroCard({required this.item});

  final DashboardItem item;

  @override
  Widget build(BuildContext context) {
    final stats = _lastGameStats(item);
    final title = _lastGameTitle(item);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final height = compact ? 192.0 : 202.0;
        final leftPadding = compact ? 18.0 : 22.0;
        final leftWidth = constraints.maxWidth * (compact ? 0.62 : 0.58);
        final statsWidth = compact
            ? constraints.maxWidth * 0.53
            : constraints.maxWidth * 0.50;
        return InkWell(
          key: const ValueKey('home-hero-card'),
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openDashboardRoute(context, item.route),
          child: Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E12),
              border: Border.all(color: const Color(0x14FFFFFF)),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9FE870).withValues(alpha: 0.055),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned.fill(child: _LastGameBackground(item: item)),
                  Positioned(
                    left: leftPadding,
                    top: compact ? 18 : 20,
                    width: leftWidth,
                    child: _LastGameHeader(
                      title: title,
                      meta: _lastGameMeta(item),
                    ),
                  ),
                  Positioned(
                    left: leftPadding,
                    bottom: compact ? 17 : 20,
                    width: statsWidth,
                    child: _LastGameStatsRow(stats: stats),
                  ),
                  Positioned(
                    right: compact ? 16 : 20,
                    top: null,
                    bottom: compact ? 38 : 30,
                    child: const _TracerRecapButton(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LastGameHeader extends StatelessWidget {
  const _LastGameHeader({required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _lastGameLabel(),
          style: AppTextStyles.label.copyWith(
            color: const Color(0xFF9FE870),
            fontSize: 11,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: AppTextStyles.title.copyWith(fontSize: 19, height: 1.18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 5),
        Text(
          meta,
          style: AppTextStyles.body.copyWith(
            fontSize: 12.5,
            color: AppColors.textSecondary.withValues(alpha: 0.72),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _LastGameStatsRow extends StatelessWidget {
  const _LastGameStatsRow({required this.stats});

  final List<_LastGameStat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 314;
        final gap = compact ? 12.0 : 22.0;
        return Row(
          children: [
            Expanded(
              child: _HeroStat(
                value: stats[0].value,
                label: stats[0].label,
                valueColor: _scoreAccent(stats[0].value),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _HeroStat(value: stats[1].value, label: stats[1].label),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _HeroStat(value: stats[2].value, label: stats[2].label),
            ),
          ],
        );
      },
    );
  }
}

class _LastGameBackground extends StatelessWidget {
  const _LastGameBackground({required this.item});

  final DashboardItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _lastGameImageUrl(item);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(color: Color(0xFF080A0D))),
        _CourseImage(url: imageUrl),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF050607).withValues(alpha: 0.96),
                const Color(0xFF050607).withValues(alpha: 0.86),
                const Color(0xFF050607).withValues(alpha: 0.48),
                const Color(0xFF050607).withValues(alpha: 0.15),
              ],
              stops: const [0, 0.35, 0.55, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.22),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.38),
              ],
            ),
          ),
        ),
        CustomPaint(painter: _LastGameVisualPainter()),
      ],
    );
  }
}

class _CourseImage extends StatelessWidget {
  const _CourseImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('assets/')) {
        return Image.asset(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        );
      }
      return Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        errorBuilder: (context, error, stackTrace) => _fallbackCourseImage(),
      );
    }
    return _fallbackCourseImage();
  }

  Widget _fallbackCourseImage() {
    return Image.asset(
      _homeGolfCourseAsset,
      key: const ValueKey('home-last-game-course-image'),
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
    );
  }
}

class _TracerRecapButton extends StatelessWidget {
  const _TracerRecapButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF050607).withValues(alpha: 0.48),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VIEW RECAP',
              style: AppTextStyles.micro.copyWith(
                fontSize: 10.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.05,
              ),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.chevron_right, size: 15),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value.toUpperCase(),
              style: AppTextStyles.title.copyWith(
                fontSize: 25,
                height: 0.98,
                color: valueColor ?? AppColors.textPrimary,
                letterSpacing: 0,
              ),
              maxLines: 1,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTextStyles.micro.copyWith(
            fontSize: 9.5,
            color: AppColors.textMuted.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.65,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _LastGameVisualPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tracerPaint = Paint()
      ..color = const Color(0xFF9FE870).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.68)
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.26,
        size.width * 0.82,
        size.height * 0.18,
        size.width * 0.94,
        size.height * 0.36,
      );
    canvas.drawPath(path, tracerPaint);
    final glowPaint = Paint()
      ..color = const Color(0xFF9FE870).withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.68),
      5,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.94, size.height * 0.36),
      5,
      glowPaint,
    );

    final goldPaint = Paint()
      ..color = AppColors.signalGold.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.56,
        size.height * 0.20,
        size.width * 0.34,
        size.height * 0.48,
      ),
      -0.8,
      2.8,
      false,
      goldPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LastGameVisualPainter oldDelegate) => false;
}

class _PerformanceHeroSection extends StatelessWidget {
  const _PerformanceHeroSection({
    required this.user,
    required this.hero,
    required this.section,
    required this.focus,
  });

  final Map<String, dynamic> user;
  final DashboardItem hero;
  final DashboardSection section;
  final DashboardItem focus;

  @override
  Widget build(BuildContext context) {
    final asset = _homeGolferAsset(user);
    final score = hero.metadata['score'];
    final confidence = hero.metadata['confidence'];
    final consistency = _consistencyValue(score, confidence, hero.type);
    final leftMetrics = _leftPerformanceMetrics(section.metrics);
    final rightMetrics = _rightPerformanceMetrics(section.metrics);
    return Container(
      key: const ValueKey('home-performance-hero'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0D10), Color(0xFF030405)],
        ),
        border: Border.all(color: Color(0x12FFFFFF)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PERFORMANCE LAB',
                  style: AppTextStyles.label.copyWith(
                    color: const Color(0xFFF4F6F8),
                  ),
                ),
              ),
              _StatusPill(label: _polishedFocusStatus(focus.status)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 468,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _PerformanceHaloPainter()),
                ),
                Positioned(
                  top: 14,
                  bottom: 76,
                  left: 42,
                  right: 42,
                  child: Image.asset(
                    asset,
                    key: const ValueKey('home-center-golfer-asset'),
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 44,
                  width: 118,
                  child: _MetricColumn(metrics: leftMetrics),
                ),
                Positioned(
                  right: 0,
                  top: 44,
                  width: 118,
                  child: _MetricColumn(metrics: rightMetrics, alignEnd: true),
                ),
                Positioned(
                  bottom: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _openDashboardRoute(context, hero.route),
                    child: Container(
                      width: 206,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.36),
                        border: Border.all(color: const Color(0x339FE870)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'SWING CONSISTENCY',
                            style: AppTextStyles.micro.copyWith(
                              color: const Color(0xFF9FE870),
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            consistency,
                            style: AppTextStyles.title.copyWith(fontSize: 28),
                          ),
                          Text(
                            _consistencyCaption(score, confidence),
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeVisualMetric {
  const _HomeVisualMetric(
    this.label,
    this.value, {
    this.caption,
    this.route,
    this.active = true,
  });

  final String label;
  final String value;
  final String? caption;
  final String? route;
  final bool active;
}

class _LastGameStat {
  const _LastGameStat({required this.label, required this.value});

  final String label;
  final String value;
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.metrics, this.alignEnd = false});

  final List<_HomeVisualMetric> metrics;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        for (final metric in metrics) ...[
          _HomeMetricPod(metric: metric, alignEnd: alignEnd),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HomeMetricPod extends StatelessWidget {
  const _HomeMetricPod({required this.metric, required this.alignEnd});

  final _HomeVisualMetric metric;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: metric.route == null
          ? null
          : () => _openDashboardRoute(context, metric.route),
      child: SizedBox(
        width: 118,
        child: Column(
          crossAxisAlignment: alignEnd
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              metric.label,
              style: AppTextStyles.micro.copyWith(
                color: AppColors.textMuted.withValues(alpha: 0.92),
                letterSpacing: 0.9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Align(
              alignment: alignEnd
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: alignEnd
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Text(
                  _cleanPrimaryMetricValue(metric.value),
                  textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                  style: AppTextStyles.title.copyWith(
                    fontSize: 23,
                    height: 0.98,
                    color: metric.active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    letterSpacing: 0,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.82),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            if (metric.caption != null) ...[
              const SizedBox(height: 5),
              Text(
                metric.caption!,
                textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 7),
            _Sparkline(alignEnd: alignEnd, active: metric.active),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.alignEnd, required this.active});

  final bool alignEnd;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(76, 16),
      painter: _SparklinePainter(alignEnd: alignEnd, active: active),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.alignEnd, required this.active});

  final bool alignEnd;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (active ? const Color(0xFF9FE870) : AppColors.textMuted)
          .withValues(alpha: active ? 0.58 : 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path();
    final points = alignEnd
        ? const [0.54, 0.42, 0.62, 0.36, 0.45, 0.22]
        : const [0.66, 0.48, 0.56, 0.30, 0.38, 0.18];
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height * points[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.alignEnd != alignEnd || oldDelegate.active != active;
  }
}

class _PerformanceHaloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final ringRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.82,
      height: size.width * 0.82,
    );
    canvas.drawCircle(
      center,
      size.width * 0.30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.045),
    );
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = const SweepGradient(
        colors: [
          Color(0x119FE870),
          Color(0x44D8B24C),
          Color(0x669FE870),
          Color(0x119FE870),
        ],
      ).createShader(ringRect);
    canvas.drawArc(ringRect, -2.9, 5.6, false, haloPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFF9FE870).withValues(alpha: 0.26)
      ..style = PaintingStyle.fill;
    for (var index = 0; index < 44; index++) {
      final angle = index * 0.142;
      final radius = size.width * 0.38;
      final offset = Offset(
        center.dx + radius * 0.96 * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(offset, index.isEven ? 1.0 : 0.65, dotPaint);
    }

    final baseRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.78),
      width: size.width * 0.62,
      height: 68,
    );
    canvas.drawOval(
      baseRect.inflate(18),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9FE870).withValues(alpha: 0.22),
            const Color(0xFF9FE870).withValues(alpha: 0.0),
          ],
        ).createShader(baseRect.inflate(34)),
    );
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF9FE870).withValues(alpha: 0.72);
    canvas.drawOval(baseRect, basePaint);
    canvas.drawOval(
      baseRect.inflate(14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.signalGold.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(covariant _PerformanceHaloPainter oldDelegate) => false;
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.actions});

  final List<DashboardAction> actions;

  @override
  Widget build(BuildContext context) {
    final visible = actions.isEmpty ? _fallbackActions() : actions;
    final rowActions = visible.take(4).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK ACTIONS', style: AppTextStyles.label),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < rowActions.length; index++) ...[
              Expanded(child: _QuickActionTile(action: rowActions[index])),
              if (index != rowActions.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final DashboardAction action;

  @override
  Widget build(BuildContext context) {
    final subtitle = _actionSubtitle(action);
    return InkWell(
      key: ValueKey('home-action-${action.id}'),
      borderRadius: BorderRadius.circular(18),
      onTap: action.enabled
          ? () => _openDashboardRoute(context, action.route)
          : null,
      child: Container(
        height: 118,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1014),
          border: Border.all(color: const Color(0x1FFFFFFF)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _actionIcon(action.id),
              size: 22,
              color: _actionAccent(action.id),
            ),
            const Spacer(),
            Text(
              action.title.toUpperCase(),
              style: AppTextStyles.micro.copyWith(
                color: AppColors.textPrimary,
                letterSpacing: 0.8,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PerformanceSnapshot extends StatelessWidget {
  const _PerformanceSnapshot({required this.section});

  final DashboardSection section;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: section.title.isEmpty ? 'Performance Snapshot' : section.title,
      actionLabel: 'VIEW STATS',
      onAction: () => context.go('/stats'),
      child: section.empty || section.metrics.isEmpty
          ? Text(
              section.body ??
                  'Record a swing or trace a shot to build your snapshot.',
              style: AppTextStyles.body,
            )
          : _MetricGrid(metrics: section.metrics),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final twoColumn = constraints.maxWidth >= 320;
        final width = twoColumn
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              _MetricTile(metric: metric, width: width),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, this.width});

  final DashboardMetric metric;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: metric.route == null
          ? null
          : () => _openDashboardRoute(context, metric.route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width ?? double.infinity,
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.panelStrong,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.label.toUpperCase(),
              style: AppTextStyles.micro,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Text(
              metric.value,
              style: AppTextStyles.title.copyWith(fontSize: 26),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (metric.delta != null)
              Text(
                metric.delta!,
                style: AppTextStyles.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({required this.items});

  final List<DashboardItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _SectionPanel(
        title: 'Recent Activity',
        actionLabel: 'VIEW ALL',
        onAction: () => context.go('/activity'),
        child: const Text(
          'Your swing analyses, tracer reviews, and future round summaries will appear here.',
          style: AppTextStyles.body,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('RECENT ACTIVITY', style: AppTextStyles.label),
            ),
            TextButton(
              onPressed: () => context.go('/activity'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('VIEW ALL'),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in items.take(4)) ...[
                _RecentActivityCard(item: item),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.item});

  final DashboardItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: item.route == null
          ? null
          : () => _openDashboardRoute(context, item.route),
      child: Container(
        width: 146,
        height: 172,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x1FFFFFFF)),
          image: DecorationImage(
            image: AssetImage(_activityAsset(item)),
            fit: BoxFit.cover,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.36),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActivityBadge(label: _activityBadge(item)),
                const Spacer(),
                Text(
                  item.title,
                  style: AppTextStyles.micro.copyWith(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.body != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.body!,
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        border: Border.all(color: const Color(0x339FE870)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: AppTextStyles.micro.copyWith(
            color: const Color(0xFF9FE870),
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final DashboardItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.route == null
          ? null
          : () => _openDashboardRoute(context, item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title.toUpperCase(), style: AppTextStyles.label),
                  if (item.body != null)
                    Text(
                      item.body!,
                      style: AppTextStyles.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (item.status != null) ...[
              const SizedBox(width: 10),
              Flexible(child: _StatusPill(label: item.status!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title.toUpperCase(), style: AppTextStyles.label),
              ),
              if (actionLabel != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _statusColor(label).withValues(alpha: 0.12),
        border: Border.all(color: _statusColor(label).withValues(alpha: 0.58)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.micro.copyWith(color: _statusColor(label)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

HomeDashboard _fallbackDashboard(AuthState auth) {
  final user = auth.user;
  final profile = auth.profile;
  return HomeDashboard(
    user: {
      'id': user?.id,
      'email': user?.email,
      'first_name': _firstName(user?.email),
      'skill_level': profile?.skillLevel,
      'handedness': profile?.handedness,
    },
    hero: DashboardItem(
      type: 'empty',
      title: 'Build your first performance profile',
      body: 'Record a swing or trace a shot to start seeing honest trends.',
      status: 'START',
      route: '/swing/record',
      createdAt: DateTime.now(),
    ),
    quickActions: _fallbackActions(),
    performanceSnapshot: const DashboardSection(
      title: 'Performance Snapshot',
      body:
          'Not enough data yet. Record a swing or trace a shot to build your snapshot.',
      empty: true,
    ),
    todayFocus: DashboardItem(
      type: 'capture_focus',
      title: "Today's Focus",
      body: 'Start with one clean guided capture. Good data comes first.',
      status: 'CAPTURE',
      route: '/swing/record',
      createdAt: DateTime.now(),
    ),
    favoritesPreview: const [],
    recentActivity: const [],
    capabilities: const {
      'home_dashboard': false,
      'swing_analysis': true,
      'shot_tracer': true,
      'rounds': true,
      'favorites': false,
      'notifications': false,
    },
  );
}

List<DashboardAction> _fallbackActions() {
  return const [
    DashboardAction(
      id: 'record_swing',
      title: 'Record Swing',
      subtitle: 'AI analysis',
      route: '/swing/record',
    ),
    DashboardAction(
      id: 'shot_tracer',
      title: 'Shot Tracer',
      subtitle: 'Track ball flight',
      route: '/tracer/new',
    ),
    DashboardAction(
      id: 'play_round',
      title: 'Play Round',
      subtitle: 'Scorecard',
      route: '/rounds',
    ),
    DashboardAction(
      id: 'stats',
      title: 'Stats',
      subtitle: 'Performance',
      route: '/stats',
    ),
  ];
}

DashboardItem _lastGameItem(HomeDashboard dashboard) {
  for (final item in dashboard.recentActivity) {
    final type = item.type.toLowerCase();
    if (type.contains('round')) return item;
  }
  return dashboard.hero;
}

String _lastGameLabel() {
  return 'LAST GAME';
}

String _lastGameTitle(DashboardItem item) {
  if (_isApprovedDemoLastGame(item)) return 'Riverside Golf Club';
  if (item.type.toLowerCase().contains('round')) {
    return _metadataText(item, const ['course_name']) ??
        _trimmedOrNull(item.title) ??
        'Last Round';
  }
  return 'Last Round';
}

String _lastGameMeta(DashboardItem item) {
  if (_isApprovedDemoLastGame(item)) return 'May 18, 2025 · 18 Holes';
  final holes = _metadataText(item, const ['holes', 'holes_planned']);
  final date = item.createdAt == null ? null : _displayDate(item.createdAt!);
  if (date != null && holes != null && holes.trim().isNotEmpty) {
    return '$date · $holes Holes';
  }
  final body = item.body?.trim();
  if (body != null && body.isNotEmpty) return body;
  if (item.type.toLowerCase().contains('round')) {
    return date ?? 'Recent activity';
  }
  return 'Recent activity';
}

List<_LastGameStat> _lastGameStats(DashboardItem item) {
  final type = item.type.toLowerCase();
  final score = item.metadata['score'];
  if (_isApprovedDemoLastGame(item)) {
    return const [
      _LastGameStat(label: 'SCORE', value: '74 (-2)'),
      _LastGameStat(label: 'FAIRWAYS', value: '86%'),
      _LastGameStat(label: 'PUTTS', value: '31'),
    ];
  }
  if (type.contains('round')) {
    return [
      _LastGameStat(
        label: 'SCORE',
        value:
            _roundScoreFromBody(item.body) ??
            _metadataValue(item, const ['score', 'total_strokes']),
      ),
      _LastGameStat(
        label: 'FAIRWAYS',
        value:
            _ratioToPercent(
              _metadataValue(item, const ['fairways', 'fairways_hit']),
            ) ??
            _metadataValue(item, const ['fairways_percent']),
      ),
      _LastGameStat(
        label: 'PUTTS',
        value: _metadataValue(item, const ['putts', 'total_putts']),
      ),
    ];
  }
  return [
    _LastGameStat(
      label: 'SCORE',
      value: score == null ? '--' : score.toString(),
    ),
    _LastGameStat(label: 'FAIRWAYS', value: '--'),
    const _LastGameStat(label: 'PUTTS', value: '--'),
  ];
}

String _metadataValue(DashboardItem item, List<String> keys) {
  final value = _metadataText(item, keys);
  return value ?? '--';
}

String? _metadataText(DashboardItem item, List<String> keys) {
  for (final key in keys) {
    final value = item.metadata[key] ?? item.metadata[_camelKey(key)];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String _camelKey(String key) {
  final parts = key.split('_');
  if (parts.length == 1) return key;
  return [
    parts.first,
    for (final part in parts.skip(1))
      if (part.isNotEmpty) '${part[0].toUpperCase()}${part.substring(1)}',
  ].join();
}

String? _lastGameImageUrl(DashboardItem item) {
  return _metadataText(item, const [
    'course_image_url',
    'course_image',
    'image_url',
    'image',
  ]);
}

bool _isApprovedDemoLastGame(DashboardItem item) {
  final haystack = [
    item.title,
    item.body ?? '',
    _metadataText(item, const ['course_name']) ?? '',
  ].join(' ').toLowerCase();
  return haystack.contains('practice loop') ||
      haystack.contains('swinglens demo club');
}

Color? _scoreAccent(String value) {
  if (RegExp(r'\(-\d+\)').hasMatch(value)) return const Color(0xFF9FE870);
  if (RegExp(r'\(\+\d+\)').hasMatch(value)) return AppColors.signalRed;
  return null;
}

String _displayDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String? _roundScoreFromBody(String? body) {
  if (body == null) return null;
  final match = RegExp(r'(\d+\s*\([^)]+\))').firstMatch(body);
  return match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ');
}

List<_HomeVisualMetric> _leftPerformanceMetrics(List<DashboardMetric> metrics) {
  final drivingAccuracy = _metricValueForLabels(metrics, const [
    'Driving Accuracy',
    'Fairways',
  ]);
  final avgDrive = _metricValueForLabels(metrics, const [
    'Average Drive',
    'Avg. Drive',
    'Avg Drive',
    'Drive Distance',
  ]);
  final gir = _metricValueForLabels(metrics, const ['GIR', 'Greens']);
  return [
    _HomeVisualMetric(
      'DRIVING ACCURACY',
      _ratioToPercent(drivingAccuracy) ?? drivingAccuracy ?? '--',
      caption: drivingAccuracy == null ? 'Track rounds' : 'Tracked fairways',
      route: '/stats/rounds',
      active: drivingAccuracy != null,
    ),
    _HomeVisualMetric(
      'AVG. DRIVE',
      avgDrive ?? '--',
      caption: avgDrive == null ? 'Track shots' : 'Tracked shots',
      route: '/stats/clubs',
      active: avgDrive != null,
    ),
    _HomeVisualMetric(
      'GIR',
      _ratioToPercent(gir) ?? gir ?? '--',
      caption: gir == null ? 'Track rounds' : 'Greens in regulation',
      route: '/stats/rounds',
      active: gir != null,
    ),
  ];
}

List<_HomeVisualMetric> _rightPerformanceMetrics(
  List<DashboardMetric> metrics,
) {
  final bestClub = _metricValueForLabels(metrics, const [
    'Best Club',
    'Most Used Club',
    'Captured Club',
  ]);
  final scoringAverage = _metricValueForLabels(metrics, const [
    'Scoring Average',
    'Average Score',
  ]);
  return [
    const _HomeVisualMetric(
      'HANDICAP',
      '--',
      caption: 'Not calculated',
      route: '/stats/rounds',
      active: false,
    ),
    _HomeVisualMetric(
      'BEST CLUB',
      bestClub ?? 'No club',
      caption: bestClub == null ? 'Track a club' : 'Captured club',
      route: '/stats/clubs',
      active: bestClub != null,
    ),
    _HomeVisualMetric(
      'SCORING AVG.',
      scoringAverage ?? '--',
      caption: scoringAverage == null ? 'Track rounds' : 'Tracked rounds',
      route: '/stats/rounds',
      active: scoringAverage != null,
    ),
  ];
}

String? _metricValueForLabels(
  List<DashboardMetric> metrics,
  List<String> labels,
) {
  for (final label in labels) {
    final needle = label.toLowerCase();
    for (final metric in metrics) {
      if (metric.label.toLowerCase().contains(needle)) {
        final value = metric.value.trim();
        if (value.isNotEmpty) return value;
      }
    }
  }
  return null;
}

String? _ratioToPercent(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s*$').firstMatch(value);
  if (match == null) return null;
  final numerator = int.tryParse(match.group(1)!);
  final denominator = int.tryParse(match.group(2)!);
  if (numerator == null || denominator == null || denominator == 0) {
    return null;
  }
  return '${(numerator / denominator * 100).round()}%';
}

String _consistencyValue(Object? score, Object? confidence, String type) {
  final value = _heroValue(score, confidence, type).trim();
  if (value == 'START' || value == 'READY') return '--';
  if (value.endsWith('%')) return value;
  final numeric = num.tryParse(value);
  return numeric == null ? value : '${numeric.round()}%';
}

String _consistencyCaption(Object? score, Object? confidence) {
  if (score != null) return 'Latest swing score';
  if (confidence != null) return 'Tracer confidence';
  return 'Track a swing';
}

String _polishedFocusStatus(String? status) {
  final upper = (status ?? '').toUpperCase();
  if (upper.contains('POSE')) return 'TRACKED DATA';
  if (upper.contains('ANALYSIS')) return 'ANALYSIS';
  if (upper.contains('CAPTURE')) return 'READY';
  if (upper.contains('REVIEW')) return 'NEEDS REVIEW';
  if (upper.trim().isEmpty) return 'READY';
  return upper;
}

String _cleanPrimaryMetricValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '--';
  final lower = trimmed.toLowerCase();
  if (lower.contains('not enough')) return '--';
  if (lower.contains('club b') || lower == 'club bag') return 'No club';
  if (lower.contains('rounds v')) return '--';
  if (lower.contains('open stats')) return '--';
  if (lower.contains('no estimate')) return '--';
  return trimmed.toUpperCase();
}

String _homeGolferAsset(Map<String, dynamic> user) {
  final skill = (user['skill_level'] as String? ?? '').toLowerCase();
  if (skill.contains('junior') || skill.contains('beginner')) {
    return _homeGolferJuniorAsset;
  }
  if (skill.contains('advanced') ||
      skill.contains('elite') ||
      skill.contains('pro')) {
    return _homeGolferProAsset;
  }
  return _homeGolferAmateurAsset;
}

String _activityAsset(DashboardItem item) {
  final type = item.type.toLowerCase();
  if (type.contains('tracer')) return _homeGolferGoldAsset;
  if (type.contains('favorite')) return _homeFallbackAvatarAsset;
  if (type.contains('round')) return _homeGolferJuniorAsset;
  return _homeGolferProAsset;
}

String _activityBadge(DashboardItem item) {
  final type = item.type.toLowerCase();
  if (type.contains('tracer')) return 'DR';
  if (type.contains('round')) return '18H';
  if (type.contains('favorite')) return 'PIN';
  if (type.contains('swing')) return '7i';
  return item.status?.toUpperCase().split(' ').first ?? 'LOG';
}

void _openDashboardRoute(BuildContext context, String? route) {
  if (route == null || route.isEmpty) return;
  if (!_isAllowedDashboardRoute(route)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dashboard route unavailable.')),
    );
    return;
  }
  context.go(route);
}

bool _isAllowedDashboardRoute(String route) {
  const exactRoutes = {
    '/activity',
    '/capture/review',
    '/capture/tracer',
    '/favorites',
    '/home',
    '/notifications',
    '/performance-snapshot',
    '/profile',
    '/rounds',
    '/settings',
    '/settings/privacy',
    '/settings/subscription',
    '/swing',
    '/tracer',
  };
  if (exactRoutes.contains(route)) return true;
  return route.startsWith('/stats') ||
      route.startsWith('/profile/') ||
      route.startsWith('/rounds/') ||
      route.startsWith('/swings/') ||
      route.startsWith('/swing/') ||
      route.startsWith('/tracer/');
}

bool _isAuthError(Object? error) {
  if (error is! DioException) return false;
  final statusCode = error.response?.statusCode;
  return statusCode == 401 || statusCode == 403;
}

Color _statusColor(String status) {
  final upper = status.toUpperCase();
  if (upper.contains('REVIEW') || upper.contains('FOCUS')) {
    return AppColors.signalGold;
  }
  if (upper.contains('FAIL') || upper.contains('OFFLINE')) {
    return AppColors.signalRed;
  }
  if (upper.contains('READY') ||
      upper.contains('TRACKED') ||
      upper.contains('AVAILABLE')) {
    return AppColors.signalGreen;
  }
  return AppColors.textSecondary;
}

String _heroValue(Object? score, Object? confidence, String type) {
  if (score != null) return score.toString();
  if (confidence != null) return '$confidence%';
  if (type == 'empty') return 'START';
  return 'READY';
}

IconData _actionIcon(String id) {
  return switch (id) {
    'record_swing' => Icons.videocam_outlined,
    'shot_tracer' => Icons.track_changes_outlined,
    'play_round' => Icons.flag_outlined,
    'stats' => Icons.query_stats_outlined,
    _ => Icons.chevron_right,
  };
}

String? _actionSubtitle(DashboardAction action) {
  return switch (action.id) {
    'record_swing' => 'AI Analysis',
    'shot_tracer' => 'Track Ball Flight',
    'play_round' => 'Scorecard',
    'stats' => 'Performance Trends',
    _ => action.subtitle,
  };
}

Color _actionAccent(String id) {
  return switch (id) {
    'record_swing' => const Color(0xFFF4F6F8),
    'shot_tracer' => const Color(0xFF9FE870),
    'play_round' => AppColors.signalGold,
    'stats' => const Color(0xFFE6EEF5),
    _ => AppColors.textSecondary,
  };
}

String _firstName(String? email) {
  final local = email?.split('@').first ?? 'Golfer';
  return local.replaceAll('.', ' ').replaceAll('_', ' ').trim().isEmpty
      ? 'Golfer'
      : local.replaceAll('.', ' ').replaceAll('_', ' ');
}

String _dashboardDisplayName(Map<String, dynamic> user) {
  final raw = (user['first_name'] as String?)?.trim();
  if (raw == null || raw.isEmpty) return 'Golfer';
  final compact = raw.replaceAll(RegExp(r'\s+'), ' ');
  if (compact.length > 24 || RegExp(r'\d').hasMatch(compact)) {
    return 'Golfer';
  }
  return compact.split(' ').first;
}

String _statsTitle(String kind) {
  return switch (kind) {
    'swings' => 'Swing Stats',
    'tracer' => 'Shot Tracer Stats',
    'rounds' => 'Round Stats',
    'clubs' => 'Club Performance',
    'faults' => 'Fault Trends',
    _ => 'Stats',
  };
}

String _statsFallbackBody(String kind) {
  return switch (kind) {
    'swings' => 'Pose-based swing metrics from completed SwingLens reports.',
    'tracer' =>
      'Visual-only tracer confidence and review status. Not launch-monitor data.',
    'rounds' =>
      'Scorecard totals from saved rounds. No GPS, handicap, or launch-monitor estimates.',
    'clubs' =>
      'Club bag presets and captured club labels. Not measured carry data.',
    'faults' =>
      'Recurring fault labels from completed SwingLens swing reports.',
    _ =>
      'Stats use completed swing analyses, visual tracer results, and saved scorecards.',
  };
}

String _statsEmptyBody(String kind) {
  return switch (kind) {
    'tracer' =>
      'Guided tracer results will build visual path confidence and review state here. Carry, ball speed, spin, and launch-monitor metrics are intentionally absent.',
    'faults' =>
      'Fault trends need completed reports with labeled findings before SwingLens can show a recurring focus area.',
    'rounds' => 'Start a 9 or 18 hole scorecard to build round history.',
    'clubs' => 'Add clubs in Profile to build a saved club bag summary.',
    'swings' =>
      'Completed swing reports will add score history, capture count, and likely focus patterns.',
    _ =>
      'Record a swing or trace a shot to build the first honest performance snapshot.',
  };
}

class RoundsScreen extends ConsumerStatefulWidget {
  const RoundsScreen({super.key});

  @override
  ConsumerState<RoundsScreen> createState() => _RoundsScreenState();
}

class _RoundsScreenState extends ConsumerState<RoundsScreen> {
  String? _roundsToken;
  Future<List<GolfRound>>? _roundsFuture;

  Future<void> _refresh(String token) async {
    final future = ref.read(apiClientProvider).getRounds(token);
    setState(() {
      _roundsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    if (token != null && token != _roundsToken) {
      _roundsToken = token;
      _roundsFuture = ref.read(apiClientProvider).getRounds(token);
    }
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ROUNDS', style: AppTextStyles.title),
              const SizedBox(height: 12),
              Text(
                'Scorecards, hole stats, and honest round summaries. GPS and handicap calculations are not included.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                key: const ValueKey('rounds-start-button'),
                label: 'START ROUND',
                onPressed: token == null
                    ? null
                    : () => context.go('/rounds/start'),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: token == null
                    ? const EmptyState(
                        title: 'SIGN IN REQUIRED',
                        body: 'Sign in to score and review rounds.',
                      )
                    : FutureBuilder<List<GolfRound>>(
                        future: _roundsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return const ErrorText('Unable to load rounds.');
                          }
                          final rounds = snapshot.data ?? const [];
                          if (rounds.isEmpty) {
                            return const EmptyState(
                              title: 'NO ROUNDS YET',
                              body:
                                  'Start a 9 or 18 hole scorecard to build round history.',
                            );
                          }
                          return RefreshIndicator(
                            color: AppColors.textPrimary,
                            backgroundColor: AppColors.elevated,
                            onRefresh: () => _refresh(token),
                            child: ListView.separated(
                              itemCount: rounds.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final round = rounds[index];
                                return PanelButton(
                                  key: ValueKey('round-row-${round.id}'),
                                  title: _roundDisplayTitle(
                                    round,
                                  ).toUpperCase(),
                                  subtitle: _roundSubtitle(round),
                                  onPressed: () =>
                                      context.go('/rounds/${round.id}'),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundStartScreen extends ConsumerStatefulWidget {
  const RoundStartScreen({super.key});

  @override
  ConsumerState<RoundStartScreen> createState() => _RoundStartScreenState();
}

class _RoundStartScreenState extends ConsumerState<RoundStartScreen> {
  final _titleController = TextEditingController();
  final _courseController = TextEditingController();
  final _teeController = TextEditingController();
  final _notesController = TextEditingController();
  int _holesPlanned = 9;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _courseController.dispose();
    _teeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _startRound(String token) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final round = await ref
          .read(apiClientProvider)
          .createRound(
            token,
            {
              'title': _trimmedOrNull(_titleController.text),
              'course_name': _trimmedOrNull(_courseController.text),
              'tee_name': _trimmedOrNull(_teeController.text),
              'holes_planned': _holesPlanned,
              'notes': _trimmedOrNull(_notesController.text),
            }..removeWhere((_, value) => value == null),
          );
      if (mounted) context.go('/rounds/${round.id}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to start round.')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    return AppScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('START ROUND', style: AppTextStyles.title),
              const SizedBox(height: 12),
              Text(
                'Create a scorecard. Course maps, GPS, and offline sync come later.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              InfoPanel(
                children: [
                  AppTextField(controller: _titleController, label: 'Title'),
                  AppTextField(controller: _courseController, label: 'Course'),
                  AppTextField(controller: _teeController, label: 'Tee'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('HOLES', style: AppTextStyles.label),
                      const SizedBox(height: 10),
                      SegmentedChoices(
                        values: const ['9', '18'],
                        selected: _holesPlanned.toString(),
                        onSelected: (value) =>
                            setState(() => _holesPlanned = int.parse(value)),
                      ),
                    ],
                  ),
                  AppTextField(controller: _notesController, label: 'Notes'),
                ],
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                key: const ValueKey('round-start-submit-button'),
                label: _isSaving ? 'STARTING...' : 'START SCORECARD',
                onPressed: token == null || _isSaving
                    ? null
                    : () => _startRound(token),
              ),
              const SizedBox(height: 12),
              GhostButton(
                label: 'BACK TO ROUNDS',
                onPressed: () => context.go('/rounds'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundDetailScreen extends ConsumerStatefulWidget {
  const RoundDetailScreen({required this.roundId, super.key});

  final String roundId;

  @override
  ConsumerState<RoundDetailScreen> createState() => _RoundDetailScreenState();
}

class _RoundDetailScreenState extends ConsumerState<RoundDetailScreen> {
  String? _roundToken;
  Future<GolfRound>? _roundFuture;

  Future<GolfRound> _load(String token) {
    return ref.read(apiClientProvider).getRound(token, widget.roundId);
  }

  Future<void> _refresh(String token) async {
    final future = _load(token);
    setState(() {
      _roundFuture = future;
    });
    await future;
  }

  Future<void> _replaceRound(Future<GolfRound> operation) async {
    final future = operation.then((round) => round);
    setState(() {
      _roundFuture = future;
    });
    await future;
  }

  Future<void> _retryOfflineQueue(String token) async {
    await ref
        .read(offlineQueueProvider)
        .retryAll(accessToken: token, apiClient: ref.read(apiClientProvider));
    if (mounted) await _refresh(token);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    if (token != null && token != _roundToken) {
      _roundToken = token;
      _roundFuture = _load(token);
    }
    return AppScaffold(
      child: SafeArea(
        child: token == null
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: EmptyState(
                  title: 'SIGN IN REQUIRED',
                  body: 'Sign in to review this round.',
                ),
              )
            : FutureBuilder<GolfRound>(
                future: _roundFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: EmptyState(
                        title: 'ROUND UNAVAILABLE',
                        body: 'This scorecard could not be loaded.',
                      ),
                    );
                  }
                  final round = snapshot.data!;
                  final offlineQueue = ref.watch(offlineQueueProvider);
                  return RefreshIndicator(
                    color: AppColors.textPrimary,
                    backgroundColor: AppColors.elevated,
                    onRefresh: () => _refresh(token),
                    child: ListView(
                      key: ValueKey('round-detail-${round.id}'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        _RoundDetailHeader(round: round),
                        const SizedBox(height: 14),
                        if (offlineQueue.pendingCount > 0) ...[
                          _OfflineQueuePanel(
                            pendingCount: offlineQueue.pendingCount,
                            isSyncing: offlineQueue.isSyncing,
                            onRetry: () => _retryOfflineQueue(token),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _RoundSummaryPanel(summary: round.summary),
                        const SizedBox(height: 14),
                        FavoriteToggleButton(
                          accessToken: token,
                          entityType: 'round',
                          entityId: round.id,
                          saveLabel: 'SAVE ROUND',
                          savedLabel: 'SAVED ROUND',
                        ),
                        const SizedBox(height: 12),
                        _RoundActionButtons(
                          round: round,
                          onEdit: () => _showRoundEditDialog(token, round),
                          onComplete: () => _completeRound(token, round),
                          onReopen: () => _replaceRound(
                            ref
                                .read(apiClientProvider)
                                .reopenRound(token, round.id),
                          ),
                          onDelete: () => _deleteRound(token, round),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'HOLE SCORECARD',
                          style: AppTextStyles.label,
                        ),
                        const SizedBox(height: 12),
                        for (final hole in round.holes) ...[
                          _RoundHoleRow(
                            hole: hole,
                            onPressed: () =>
                                _showHoleDialog(token: token, hole: hole),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _completeRound(String token, GolfRound round) async {
    try {
      await _replaceRound(
        ref.read(apiClientProvider).completeRound(token, round.id),
      );
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? (error.response?.data as Map)['detail']?.toString()
          : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail ?? 'Unable to complete round.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to complete round.')),
        );
      }
    }
  }

  Future<void> _deleteRound(String token, GolfRound round) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete round'),
        content: Text('Delete ${_roundDisplayTitle(round)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).deleteRound(token, round.id);
      if (mounted) context.go('/rounds');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete round.')),
        );
      }
    }
  }

  Future<void> _showRoundEditDialog(String token, GolfRound round) async {
    final titleController = TextEditingController(text: round.title ?? '');
    final courseController = TextEditingController(
      text: round.courseName ?? '',
    );
    final teeController = TextEditingController(text: round.teeName ?? '');
    final notesController = TextEditingController(text: round.notes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit round'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: titleController, label: 'Title'),
                AppTextField(controller: courseController, label: 'Course'),
                AppTextField(controller: teeController, label: 'Tee'),
                AppTextField(controller: notesController, label: 'Notes'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () async {
                final fields = {
                  'title': _trimmedOrNull(titleController.text),
                  'course_name': _trimmedOrNull(courseController.text),
                  'tee_name': _trimmedOrNull(teeController.text),
                  'notes': _trimmedOrNull(notesController.text),
                };
                try {
                  await ref
                      .read(apiClientProvider)
                      .updateRound(token, round.id, fields);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } on DioException catch (error) {
                  if (shouldQueueOffline(error)) {
                    await _queueRoundUpdate(roundId: round.id, fields: fields);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(false);
                    }
                    return;
                  }
                  final detail = error.response?.data is Map
                      ? (error.response?.data as Map)['detail']?.toString()
                      : null;
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(detail ?? 'Unable to save round.'),
                      ),
                    );
                  }
                } catch (_) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Unable to save round.')),
                    );
                  }
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
    _disposeControllersLater([
      titleController,
      courseController,
      teeController,
      notesController,
    ]);
    if (saved == true && mounted) await _refresh(token);
  }

  Future<void> _showHoleDialog({
    required String token,
    required RoundHole hole,
  }) async {
    final strokesController = TextEditingController(
      text: hole.strokes?.toString() ?? '',
    );
    final puttsController = TextEditingController(
      text: hole.putts?.toString() ?? '',
    );
    final penaltiesController = TextEditingController(
      text: hole.penalties.toString(),
    );
    final notesController = TextEditingController(text: hole.notes ?? '');
    var par = hole.par;
    var fairway = _hitState(hole.fairwayHit);
    var gir = _hitState(hole.greenInRegulation);
    final updatedRound = await showDialog<GolfRound>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Hole ${hole.holeNumber}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PAR', style: AppTextStyles.label),
                    const SizedBox(height: 10),
                    SegmentedChoices(
                      values: const ['3', '4', '5', '6'],
                      selected: par.toString(),
                      onSelected: (value) =>
                          setDialogState(() => par = int.parse(value)),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: strokesController,
                      label: 'Strokes',
                      keyboardType: TextInputType.number,
                    ),
                    AppTextField(
                      controller: puttsController,
                      label: 'Putts',
                      keyboardType: TextInputType.number,
                    ),
                    AppTextField(
                      controller: penaltiesController,
                      label: 'Penalties',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    const Text('FAIRWAY', style: AppTextStyles.label),
                    const SizedBox(height: 10),
                    SegmentedChoices(
                      values: const ['unset', 'hit', 'miss'],
                      selected: fairway,
                      onSelected: (value) =>
                          setDialogState(() => fairway = value),
                    ),
                    const SizedBox(height: 12),
                    const Text('GIR', style: AppTextStyles.label),
                    const SizedBox(height: 10),
                    SegmentedChoices(
                      values: const ['unset', 'hit', 'miss'],
                      selected: gir,
                      onSelected: (value) => setDialogState(() => gir = value),
                    ),
                    AppTextField(controller: notesController, label: 'Notes'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () async {
                    final fields = {
                      'par': par,
                      'strokes': _optionalInt(strokesController.text),
                      'putts': _optionalInt(puttsController.text),
                      'fairway_hit': _hitFromState(fairway),
                      'green_in_regulation': _hitFromState(gir),
                      'penalties':
                          int.tryParse(penaltiesController.text.trim()) ?? 0,
                      'notes': _trimmedOrNull(notesController.text),
                    };
                    try {
                      final updated = await ref
                          .read(apiClientProvider)
                          .updateRoundHole(
                            token,
                            widget.roundId,
                            hole.holeNumber,
                            fields,
                          );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(updated);
                      }
                    } on DioException catch (error) {
                      if (shouldQueueOffline(error)) {
                        await _queueRoundHole(
                          roundId: widget.roundId,
                          holeNumber: hole.holeNumber,
                          fields: fields,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        return;
                      }
                      final detail = error.response?.data is Map
                          ? (error.response?.data as Map)['detail']?.toString()
                          : null;
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(detail ?? 'Unable to save hole.'),
                          ),
                        );
                      }
                    } catch (_) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Unable to save hole.')),
                        );
                      }
                    }
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
    _disposeControllersLater([
      strokesController,
      puttsController,
      penaltiesController,
      notesController,
    ]);
    if (updatedRound != null && mounted) {
      final future = Future<GolfRound>.value(updatedRound);
      setState(() {
        _roundFuture = future;
      });
    }
  }

  Future<void> _queueRoundUpdate({
    required String roundId,
    required Map<String, dynamic> fields,
  }) async {
    await ref
        .read(offlineQueueProvider)
        .enqueue(
          action: 'round.update',
          title: 'Round edit queued',
          payload: {'round_id': roundId, 'fields': fields},
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved offline. Sync will retry later.')),
    );
  }

  Future<void> _queueRoundHole({
    required String roundId,
    required int holeNumber,
    required Map<String, dynamic> fields,
  }) async {
    await ref
        .read(offlineQueueProvider)
        .enqueue(
          action: 'round.hole.update',
          title: 'Hole $holeNumber score queued',
          payload: {
            'round_id': roundId,
            'hole_number': holeNumber,
            'fields': fields,
          },
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved offline. Sync will retry later.')),
    );
  }
}

class _RoundDetailHeader extends StatelessWidget {
  const _RoundDetailHeader({required this.round});

  final GolfRound round;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roundDisplayTitle(round).toUpperCase(),
                    style: AppTextStyles.title.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(_roundSubtitle(round)),
                ],
              ),
            ),
            _StatusPill(label: round.status.replaceAll('_', ' ')),
          ],
        ),
        Text(
          'Started ${_shortDate(round.startedAt)}'
          '${round.completedAt == null ? '' : ' · Completed ${_shortDate(round.completedAt!)}'}',
        ),
        if (round.notes != null && round.notes!.trim().isNotEmpty)
          Text(round.notes!),
      ],
    );
  }
}

class _OfflineQueuePanel extends StatelessWidget {
  const _OfflineQueuePanel({
    required this.pendingCount,
    required this.isSyncing,
    required this.onRetry,
  });

  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$pendingCount PENDING SYNC',
                style: AppTextStyles.label,
              ),
            ),
            TextButton(
              key: const ValueKey('offline-queue-retry-button'),
              onPressed: isSyncing ? null : onRetry,
              child: Text(isSyncing ? 'SYNCING' : 'RETRY'),
            ),
          ],
        ),
        Text(
          'Offline uploads, round edits, or favorite changes are saved on this device and will retry with safe request IDs.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _RoundSummaryPanel extends StatelessWidget {
  const _RoundSummaryPanel({required this.summary});

  final RoundSummary summary;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _RoundMetric(label: 'Score', value: _roundScoreLabel(summary)),
            _RoundMetric(
              label: 'Holes',
              value: '${summary.holesCompleted}/${summary.holesPlanned}',
            ),
            _RoundMetric(
              label: 'Putts',
              value: summary.totalPutts?.toString() ?? 'Not enough data',
            ),
            _RoundMetric(
              label: 'Fairways',
              value: _ratio(summary.fairwaysHit, summary.fairwaysTotal),
            ),
            _RoundMetric(
              label: 'GIR',
              value: _ratio(summary.greensInRegulation, summary.greensTotal),
            ),
            _RoundMetric(
              label: 'Penalties',
              value: summary.penalties.toString(),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundMetric extends StatelessWidget {
  const _RoundMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panelStrong,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: AppTextStyles.micro),
              const SizedBox(height: 6),
              Text(value, style: AppTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundActionButtons extends StatelessWidget {
  const _RoundActionButtons({
    required this.round,
    required this.onEdit,
    required this.onComplete,
    required this.onReopen,
    required this.onDelete,
  });

  final GolfRound round;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final completed = round.status == 'completed';
    return Column(
      children: [
        PrimaryButton(
          key: const ValueKey('round-complete-button'),
          label: completed ? 'ROUND COMPLETED' : 'COMPLETE ROUND',
          onPressed: completed ? null : onComplete,
        ),
        const SizedBox(height: 12),
        GhostButton(
          label: completed ? 'REOPEN ROUND' : 'EDIT ROUND',
          onPressed: completed ? onReopen : onEdit,
        ),
        const SizedBox(height: 12),
        GhostButton(label: 'DELETE ROUND', onPressed: onDelete),
      ],
    );
  }
}

class _RoundHoleRow extends StatelessWidget {
  const _RoundHoleRow({required this.hole, required this.onPressed});

  final RoundHole hole;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final score = hole.strokes == null
        ? 'UNSCORED'
        : '${hole.strokes} (${_toParLabel(hole.strokes! - hole.par)})';
    final details = [
      'PAR ${hole.par}',
      score,
      if (hole.putts != null) '${hole.putts} PUTTS',
      if (hole.penalties > 0) '${hole.penalties} PEN',
      if (hole.fairwayHit != null)
        hole.fairwayHit! ? 'FAIRWAY' : 'MISS FAIRWAY',
      if (hole.greenInRegulation != null)
        hole.greenInRegulation! ? 'GIR' : 'MISS GIR',
    ].join(' · ');
    return PanelButton(
      key: ValueKey('round-hole-${hole.holeNumber}'),
      title: 'HOLE ${hole.holeNumber}',
      subtitle: details,
      onPressed: onPressed,
    );
  }
}

String _roundDisplayTitle(GolfRound round) {
  return _trimmedOrNull(round.title ?? '') ??
      _trimmedOrNull(round.courseName ?? '') ??
      'Round';
}

String _roundSubtitle(GolfRound round) {
  final summary = round.summary;
  final score = _roundScoreLabel(summary);
  return [
    round.status.replaceAll('_', ' ').toUpperCase(),
    if (round.courseName != null && round.courseName!.isNotEmpty)
      round.courseName!.toUpperCase(),
    '${summary.holesCompleted}/${summary.holesPlanned} HOLES',
    score.toUpperCase(),
  ].join(' · ');
}

String _roundScoreLabel(RoundSummary summary) {
  if (summary.totalStrokes == null) return 'Not enough data';
  return '${summary.totalStrokes} (${_toParLabel(summary.scoreToPar ?? 0)})';
}

String _syncActionLabel(String action) {
  return switch (action) {
    'upload.swing_video' => 'VIDEO UPLOAD',
    'favorite.save' => 'SAVE FAVORITE',
    'favorite.delete' => 'REMOVE FAVORITE',
    'round.update' => 'ROUND EDIT',
    'round.hole.update' => 'HOLE SCORE',
    _ => action.replaceAll('.', ' ').replaceAll('_', ' ').toUpperCase(),
  };
}

String _syncStatusLabel(OfflineQueueItemStatus status) {
  return switch (status) {
    OfflineQueueItemStatus.pending => 'PENDING',
    OfflineQueueItemStatus.syncing => 'SYNCING',
    OfflineQueueItemStatus.failed => 'FAILED',
  };
}

String _toParLabel(int value) {
  if (value == 0) return 'E';
  return value > 0 ? '+$value' : value.toString();
}

String _ratio(int value, int total) {
  if (total == 0) return 'Not enough data';
  return '$value/$total';
}

String _shortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String? _trimmedOrNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

void _disposeControllersLater(List<TextEditingController> controllers) {
  unawaited(
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    }),
  );
}

String _hitState(bool? value) {
  if (value == null) return 'unset';
  return value ? 'hit' : 'miss';
}

bool? _hitFromState(String value) {
  return switch (value) {
    'hit' => true,
    'miss' => false,
    _ => null,
  };
}

class TracerHubScreen extends ConsumerWidget {
  const TracerHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SHOT TRACER', style: AppTextStyles.title),
              const SizedBox(height: 12),
              Text(
                'Capture a guided rear-angle ball flight. Tracer metrics are visual-only and not launch-monitor data.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'RECORD GUIDED TRACER',
                onPressed: () => context.go('/tracer/new'),
              ),
              const SizedBox(height: 12),
              GhostButton(
                label: 'RECENT TRACERS',
                onPressed: () => context.go('/swing'),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: token == null
                    ? const EmptyState(
                        title: 'SIGN IN REQUIRED',
                        body: 'Sign in to review tracer sessions.',
                      )
                    : FutureBuilder<List<SwingSession>>(
                        future: ref
                            .read(apiClientProvider)
                            .getSwingSessions(token),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final sessions = (snapshot.data ?? const [])
                              .where(_isTracerSession)
                              .toList();
                          if (sessions.isEmpty) {
                            return const EmptyState(
                              title: 'NO TRACERS YET',
                              body:
                                  'Record a guided tracer to build visual ball-flight history.',
                            );
                          }
                          return ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              return PanelButton(
                                title:
                                    session.club?.toUpperCase() ??
                                    'TRACER SESSION',
                                subtitle:
                                    '${session.status.toUpperCase()} · ${_qualityLabel(session)}',
                                onPressed: () =>
                                    context.go('/swings/${session.id}'),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileHubScreen extends ConsumerWidget {
  const ProfileHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).state;
    final offlineQueue = ref.watch(offlineQueueProvider);
    final profile = auth.profile;
    final goals = profile == null || profile.goals.isEmpty
        ? 'NONE SET'
        : profile.goals.join(', ').toUpperCase();
    return AppScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PROFILE', style: AppTextStyles.title),
              const SizedBox(height: 16),
              InfoPanel(
                children: [
                  Text('EMAIL: ${auth.user?.email ?? 'UNKNOWN'}'),
                  Text(
                    'SKILL: ${profile?.skillLevel?.toUpperCase() ?? 'SET DURING ONBOARDING'}',
                  ),
                  Text(
                    'HANDEDNESS: ${profile?.handedness?.toUpperCase() ?? 'SET DURING ONBOARDING'}',
                  ),
                  Text(
                    'UNITS: ${profile?.unitsSystem.toUpperCase() ?? 'IMPERIAL'} · ${profile?.distanceUnit.toUpperCase() ?? 'YARDS'}',
                  ),
                  Text(
                    'DEFAULT CAPTURE: ${profile?.defaultCaptureMode.toUpperCase() ?? 'ANALYSIS'}',
                  ),
                  Text('GOALS: $goals'),
                  Text(
                    'VIDEO CONSENT: ${auth.hasVideoConsent ? 'ACCEPTED' : 'REQUIRED'}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PanelButton(
                title: 'GOLF PROFILE',
                subtitle:
                    'Units, handedness, skill, goals, and default capture.',
                onPressed: () => context.go('/profile/preferences'),
              ),
              const SizedBox(height: 12),
              PanelButton(
                title: 'CLUB BAG',
                subtitle: 'Active clubs and user-entered distance presets.',
                onPressed: () => context.go('/profile/club-bag'),
              ),
              const SizedBox(height: 12),
              PanelButton(
                title: 'FAVORITES',
                subtitle: 'Saved swings, reports, and tracer results.',
                onPressed: () => context.go('/favorites'),
              ),
              const SizedBox(height: 12),
              PanelButton(
                title: 'SYNC CENTER',
                subtitle: offlineQueue.pendingCount == 0
                    ? 'No offline uploads or edits waiting.'
                    : '${offlineQueue.pendingCount} pending uploads or edits.',
                onPressed: () => context.go('/profile/sync'),
              ),
              const SizedBox(height: 12),
              PanelButton(
                title: 'SUBSCRIPTION',
                subtitle: 'Plan status and restore purchases',
                onPressed: () => context.go('/settings/subscription'),
              ),
              const SizedBox(height: 12),
              PanelButton(
                title: 'PRIVACY',
                subtitle: 'Video controls and data inventory',
                onPressed: () => context.go('/settings/privacy'),
              ),
              const SizedBox(height: 12),
              PanelButton(
                title: 'ACCOUNT SETTINGS',
                subtitle: 'Account ID, deletion controls, and app settings.',
                onPressed: () => context.go('/settings'),
              ),
              const SizedBox(height: 24),
              GhostButton(
                label: 'SIGN OUT',
                onPressed: () => ref.read(authControllerProvider).logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SyncCenterScreen extends ConsumerWidget {
  const SyncCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    final queue = ref.watch(offlineQueueProvider);
    return AppScaffold(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            IconButton(
              alignment: Alignment.centerLeft,
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/profile'),
            ),
            const Text('SYNC CENTER', style: AppTextStyles.title),
            const SizedBox(height: 12),
            Text(
              'Queued uploads, scorecard edits, and saved-item changes retry here. Upload analysis starts only after sync succeeds.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            InfoPanel(
              children: [
                Row(
                  children: [
                    const Icon(Icons.sync_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        queue.isSyncing
                            ? 'SYNCING'
                            : '${queue.pendingCount} PENDING',
                        style: AppTextStyles.label,
                      ),
                    ),
                  ],
                ),
                Text(
                  queue.pendingCount == 0
                      ? 'No device-local changes are waiting.'
                      : queue.failedCount == 0
                      ? 'These items use stable request IDs so a retry does not duplicate accepted backend writes.'
                      : '${queue.failedCount} failed item${queue.failedCount == 1 ? '' : 's'} need review. Remove stale failures or retry after fixing the issue.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (queue.pendingCount > 0) ...[
              PrimaryButton(
                key: const ValueKey('sync-center-retry-all-button'),
                label: queue.isSyncing ? 'SYNCING' : 'RETRY ALL',
                onPressed: token == null || queue.isSyncing
                    ? null
                    : () async {
                        await ref
                            .read(offlineQueueProvider)
                            .retryAll(
                              accessToken: token,
                              apiClient: ref.read(apiClientProvider),
                            );
                      },
              ),
              if (queue.failedCount > 0) ...[
                const SizedBox(height: 12),
                GhostButton(
                  key: const ValueKey('sync-center-clear-failed-button'),
                  label: 'CLEAR FAILED',
                  onPressed: queue.isSyncing
                      ? null
                      : () => ref.read(offlineQueueProvider).clearFailed(),
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (queue.pendingCount == 0)
              const EmptyState(
                title: 'NO PENDING SYNC',
                body:
                    'Offline uploads and edits will appear here when the network is unavailable.',
              )
            else
              for (final item in queue.items) ...[
                _SyncQueueRow(item: item, status: queue.statusFor(item)),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _SyncQueueRow extends ConsumerWidget {
  const _SyncQueueRow({required this.item, required this.status});

  final OfflineQueueItem item;
  final OfflineQueueItemStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InfoPanel(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title.toUpperCase(), style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  Text(
                    [
                      _syncActionLabel(item.action),
                      _syncStatusLabel(status),
                      'ATTEMPTS ${item.attemptCount}',
                      _shortDate(item.createdAt),
                    ].join(' · '),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: ValueKey('sync-center-remove-${item.id}'),
              onPressed: () => ref.read(offlineQueueProvider).remove(item.id),
              child: const Text('REMOVE'),
            ),
          ],
        ),
        if (item.lastError != null && item.lastError!.trim().isNotEmpty)
          Text(
            'LAST ERROR: ${item.lastError}',
            style: AppTextStyles.micro.copyWith(color: AppColors.signalGold),
          ),
      ],
    );
  }
}

class ProfilePreferencesScreen extends ConsumerStatefulWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  ConsumerState<ProfilePreferencesScreen> createState() =>
      _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState
    extends ConsumerState<ProfilePreferencesScreen> {
  final _goalsController = TextEditingController();
  final _commonMissController = TextEditingController();
  bool _didHydrate = false;
  bool _isSaving = false;
  String _handedness = 'right';
  String _skillLevel = 'beginner';
  String _unitsSystem = 'imperial';
  String _distanceUnit = 'yards';
  String _defaultCaptureMode = 'analysis';

  @override
  void dispose() {
    _goalsController.dispose();
    _commonMissController.dispose();
    super.dispose();
  }

  void _hydrate(GolferProfile? profile) {
    if (_didHydrate) return;
    _didHydrate = true;
    _handedness = profile?.handedness ?? 'right';
    _skillLevel = profile?.skillLevel ?? 'beginner';
    _unitsSystem = profile?.unitsSystem ?? 'imperial';
    _distanceUnit = profile?.distanceUnit ?? 'yards';
    _defaultCaptureMode = profile?.defaultCaptureMode ?? 'analysis';
    _goalsController.text = profile?.goals.join(', ') ?? '';
    _commonMissController.text = profile?.commonMiss ?? '';
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final goals = _goalsController.text
        .split(',')
        .map((goal) => goal.trim())
        .where((goal) => goal.isNotEmpty)
        .toList(growable: false);
    final commonMiss = _commonMissController.text.trim();
    await ref.read(authControllerProvider).updateProfile({
      'handedness': _handedness,
      'skill_level': _skillLevel,
      'goals': goals,
      'common_miss': commonMiss.isEmpty ? null : commonMiss,
      'units_system': _unitsSystem,
      'distance_unit': _distanceUnit,
      'default_capture_mode': _defaultCaptureMode,
    });
    if (!mounted) return;
    final error = ref.read(authControllerProvider).state.error;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Profile preferences saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).state;
    _hydrate(auth.profile);
    return AppScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/profile'),
              ),
              const Text('GOLF PROFILE', style: AppTextStyles.title),
              const SizedBox(height: 16),
              InfoPanel(
                children: [
                  const Text('UNITS', style: AppTextStyles.label),
                  SegmentedChoices(
                    values: const ['imperial', 'metric'],
                    selected: _unitsSystem,
                    onSelected: (value) {
                      setState(() {
                        _unitsSystem = value;
                        _distanceUnit = value == 'metric' ? 'meters' : 'yards';
                      });
                    },
                  ),
                  const Text('DISTANCE UNIT', style: AppTextStyles.label),
                  SegmentedChoices(
                    values: const ['yards', 'meters'],
                    selected: _distanceUnit,
                    onSelected: (value) =>
                        setState(() => _distanceUnit = value),
                  ),
                  const Text('DEFAULT CAPTURE', style: AppTextStyles.label),
                  SegmentedChoices(
                    values: const ['analysis', 'tracer'],
                    selected: _defaultCaptureMode,
                    onSelected: (value) =>
                        setState(() => _defaultCaptureMode = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InfoPanel(
                children: [
                  const Text('PLAYER', style: AppTextStyles.label),
                  SegmentedChoices(
                    values: const ['right', 'left'],
                    selected: _handedness,
                    onSelected: (value) => setState(() => _handedness = value),
                  ),
                  const Text('SKILL', style: AppTextStyles.label),
                  SegmentedChoices(
                    values: const ['beginner', 'intermediate', 'advanced'],
                    selected: _skillLevel,
                    onSelected: (value) => setState(() => _skillLevel = value),
                  ),
                  AppTextField(
                    controller: _goalsController,
                    label: 'Goals, comma separated',
                  ),
                  AppTextField(
                    controller: _commonMissController,
                    label: 'Common miss',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                key: const ValueKey('profile-preferences-save'),
                label: _isSaving ? 'SAVING...' : 'SAVE PROFILE',
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClubBagScreen extends ConsumerStatefulWidget {
  const ClubBagScreen({super.key});

  @override
  ConsumerState<ClubBagScreen> createState() => _ClubBagScreenState();
}

class _ClubBagScreenState extends ConsumerState<ClubBagScreen> {
  String? _clubBagToken;
  Future<List<ClubBagItem>>? _clubsFuture;

  Future<List<ClubBagItem>> _load(String token) {
    return ref.read(apiClientProvider).getClubBag(token);
  }

  void _refresh(String token) {
    setState(() {
      _clubsFuture = _load(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).state;
    final token = auth.accessToken;
    if (token != null && token != _clubBagToken) {
      _clubBagToken = token;
      _clubsFuture = _load(token);
    }
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
                onPressed: () => context.go('/profile'),
              ),
              const Text('CLUB BAG', style: AppTextStyles.title),
              const SizedBox(height: 12),
              Text(
                'Distance presets are user-entered references only, not launch-monitor measurements.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                key: const ValueKey('club-bag-add-button'),
                label: 'ADD CLUB',
                onPressed: token == null
                    ? null
                    : () => _showClubDialog(token: token),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: token == null
                    ? const EmptyState(
                        title: 'SIGN IN REQUIRED',
                        body: 'Sign in to manage your club bag.',
                      )
                    : FutureBuilder<List<ClubBagItem>>(
                        future: _clubsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return const ErrorText('Unable to load club bag.');
                          }
                          final clubs = snapshot.data ?? const [];
                          if (clubs.isEmpty) {
                            return const EmptyState(
                              title: 'NO CLUBS SAVED',
                              body:
                                  'Add active clubs to personalize capture and profile views.',
                            );
                          }
                          return RefreshIndicator(
                            color: AppColors.textPrimary,
                            backgroundColor: AppColors.elevated,
                            onRefresh: () async => _refresh(token),
                            child: ListView.separated(
                              itemCount: clubs.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final club = clubs[index];
                                return PanelButton(
                                  title: club.label.toUpperCase(),
                                  subtitle: _clubBagSubtitle(club),
                                  onPressed: () =>
                                      _showClubDialog(token: token, club: club),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showClubDialog({
    required String token,
    ClubBagItem? club,
  }) async {
    final labelController = TextEditingController(text: club?.label ?? '');
    final carryController = TextEditingController(
      text: club?.carryDistance?.toString() ?? '',
    );
    final totalController = TextEditingController(
      text: club?.totalDistance?.toString() ?? '',
    );
    final orderController = TextEditingController(
      text: (club?.displayOrder ?? 0).toString(),
    );
    var clubType = club?.clubType ?? 'iron';
    var distanceUnit =
        club?.distanceUnit ??
        ref.read(authControllerProvider).state.profile?.distanceUnit ??
        'yards';
    var isActive = club?.isActive ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(club == null ? 'Add club' : 'Edit club'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(controller: labelController, label: 'Label'),
                    const SizedBox(height: 12),
                    SegmentedChoices(
                      values: const [
                        'driver',
                        'wood',
                        'hybrid',
                        'iron',
                        'wedge',
                        'putter',
                      ],
                      selected: clubType,
                      onSelected: (value) =>
                          setDialogState(() => clubType = value),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: carryController,
                      label: 'Carry preset',
                      keyboardType: TextInputType.number,
                    ),
                    AppTextField(
                      controller: totalController,
                      label: 'Total preset',
                      keyboardType: TextInputType.number,
                    ),
                    AppTextField(
                      controller: orderController,
                      label: 'Display order',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SegmentedChoices(
                      values: const ['yards', 'meters'],
                      selected: distanceUnit,
                      onSelected: (value) =>
                          setDialogState(() => distanceUnit = value),
                    ),
                    SwitchListTile(
                      value: isActive,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
              actions: [
                if (club != null)
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(apiClientProvider)
                          .deleteClubBagItem(token, club.id);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    },
                    child: const Text('DELETE'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () async {
                    final label = labelController.text.trim();
                    if (label.isEmpty) return;
                    final payload = {
                      'label': label,
                      'club_type': clubType,
                      'is_active': isActive,
                      'display_order':
                          int.tryParse(orderController.text.trim()) ?? 0,
                      'carry_distance': _optionalInt(carryController.text),
                      'total_distance': _optionalInt(totalController.text),
                      'distance_unit': distanceUnit,
                    }..removeWhere((_, value) => value == null);
                    final api = ref.read(apiClientProvider);
                    if (club == null) {
                      await api.createClubBagItem(token, payload);
                    } else {
                      await api.updateClubBagItem(token, club.id, payload);
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
    labelController.dispose();
    carryController.dispose();
    totalController.dispose();
    orderController.dispose();
    if (saved == true && mounted) _refresh(token);
  }
}

String _clubBagSubtitle(ClubBagItem club) {
  final status = club.isActive ? 'ACTIVE' : 'INACTIVE';
  final carry = club.carryDistance == null
      ? null
      : 'CARRY ${club.carryDistance} ${club.distanceUnit.toUpperCase()}';
  final total = club.totalDistance == null
      ? null
      : 'TOTAL ${club.totalDistance} ${club.distanceUnit.toUpperCase()}';
  final distances = [carry, total].whereType<String>().join(' · ');
  return [
    club.clubType.toUpperCase(),
    status,
    if (distances.isNotEmpty) distances else 'NO DISTANCE PRESET',
  ].join(' · ');
}

int? _optionalInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}

class StatsOverviewScreen extends ConsumerStatefulWidget {
  const StatsOverviewScreen({super.key});

  @override
  ConsumerState<StatsOverviewScreen> createState() =>
      _StatsOverviewScreenState();
}

class _StatsOverviewScreenState extends ConsumerState<StatsOverviewScreen> {
  String? _statsToken;
  Future<StatsDashboard>? _statsFuture;

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    if (token != null && token != _statsToken) {
      _statsToken = token;
      _statsFuture = ref.read(apiClientProvider).getStatsOverview(token);
    }
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: token == null
              ? const EmptyState(
                  title: 'SIGN IN REQUIRED',
                  body: 'Sign in to view stats.',
                )
              : FutureBuilder<StatsDashboard>(
                  future: _statsFuture,
                  builder: (context, snapshot) {
                    final stats = snapshot.data;
                    return _StatsDashboardFrame(
                      kind: 'overview',
                      title: stats?.title ?? 'Stats Overview',
                      body:
                          stats?.body ??
                          'Stats use completed swing analyses and visual tracer results.',
                      loading:
                          snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData,
                      loadFailed: snapshot.hasError || stats == null,
                      stats: stats,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class StatsDetailScreen extends ConsumerStatefulWidget {
  const StatsDetailScreen({required this.kind, super.key});

  final String kind;

  @override
  ConsumerState<StatsDetailScreen> createState() => _StatsDetailScreenState();
}

class _StatsDetailScreenState extends ConsumerState<StatsDetailScreen> {
  String? _statsToken;
  String? _statsKind;
  Future<StatsDashboard>? _statsFuture;

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    if (token != null && (token != _statsToken || widget.kind != _statsKind)) {
      _statsToken = token;
      _statsKind = widget.kind;
      _statsFuture = switch (widget.kind) {
        'swings' => ref.read(apiClientProvider).getSwingStats(token),
        'tracer' => ref.read(apiClientProvider).getTracerStats(token),
        'rounds' => ref.read(apiClientProvider).getRoundStats(token),
        'clubs' => ref.read(apiClientProvider).getClubStats(token),
        'faults' => ref.read(apiClientProvider).getFaultStats(token),
        _ => ref.read(apiClientProvider).getStatsOverview(token),
      };
    }
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: token == null
              ? const EmptyState(
                  title: 'SIGN IN REQUIRED',
                  body: 'Sign in to view stats.',
                )
              : FutureBuilder<StatsDashboard>(
                  future: _statsFuture,
                  builder: (context, snapshot) {
                    final stats = snapshot.data;
                    return _StatsDashboardFrame(
                      kind: widget.kind,
                      title: stats?.title ?? _statsTitle(widget.kind),
                      body: stats?.body ?? _statsFallbackBody(widget.kind),
                      loading:
                          snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData,
                      loadFailed: snapshot.hasError || stats == null,
                      stats: stats,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _StatsDashboardFrame extends StatelessWidget {
  const _StatsDashboardFrame({
    required this.kind,
    required this.title,
    required this.body,
    required this.loading,
    required this.loadFailed,
    required this.stats,
  });

  final String kind;
  final String title;
  final String body;
  final bool loading;
  final bool loadFailed;
  final StatsDashboard? stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTextStyles.title),
        const SizedBox(height: 12),
        Text(body, style: AppTextStyles.body),
        const SizedBox(height: 18),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : loadFailed
              ? const EmptyState(
                  title: 'STATS UNAVAILABLE',
                  body: 'Try again after the backend is reachable.',
                )
              : _StatsDashboardList(kind: kind, stats: stats!),
        ),
      ],
    );
  }
}

class _StatsDashboardList extends StatelessWidget {
  const _StatsDashboardList({required this.kind, required this.stats});

  final String kind;
  final StatsDashboard stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _StatsRouteSwitcher(activeKind: kind),
        const SizedBox(height: 14),
        if (stats.empty || stats.metrics.isEmpty)
          _StatsEmptyPanel(kind: kind)
        else
          _MetricGrid(metrics: stats.metrics),
        const SizedBox(height: 18),
        for (final section in stats.sections) ...[
          _StatsSectionCard(section: section),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StatsRouteSwitcher extends StatelessWidget {
  const _StatsRouteSwitcher({required this.activeKind});

  final String activeKind;

  @override
  Widget build(BuildContext context) {
    const routes = [
      _StatsRouteOption(
        kind: 'overview',
        title: 'Overview',
        subtitle: 'All current signals',
        route: '/stats',
        icon: Icons.query_stats_outlined,
      ),
      _StatsRouteOption(
        kind: 'swings',
        title: 'Swings',
        subtitle: 'Pose reports',
        route: '/stats/swings',
        icon: Icons.sports_golf_outlined,
      ),
      _StatsRouteOption(
        kind: 'tracer',
        title: 'Tracer',
        subtitle: 'Visual paths',
        route: '/stats/tracer',
        icon: Icons.track_changes_outlined,
      ),
      _StatsRouteOption(
        kind: 'rounds',
        title: 'Rounds',
        subtitle: 'Scorecards',
        route: '/stats/rounds',
        icon: Icons.flag_outlined,
      ),
      _StatsRouteOption(
        kind: 'clubs',
        title: 'Clubs',
        subtitle: 'Bag presets',
        route: '/stats/clubs',
        icon: Icons.workspaces_outline,
      ),
      _StatsRouteOption(
        kind: 'faults',
        title: 'Faults',
        subtitle: 'Likely trends',
        route: '/stats/faults',
        icon: Icons.report_problem_outlined,
      ),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in routes)
          _StatsRouteTile(option: option, selected: activeKind == option.kind),
      ],
    );
  }
}

class _StatsRouteTile extends StatelessWidget {
  const _StatsRouteTile({required this.option, required this.selected});

  final _StatsRouteOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 154,
      child: InkWell(
        key: ValueKey('stats-route-${option.kind}'),
        onTap: selected ? null : () => context.go(option.route),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.panelStrong : AppColors.panel,
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(option.icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title.toUpperCase(),
                      style: AppTextStyles.micro,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      option.subtitle,
                      style: AppTextStyles.body.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSectionCard extends StatelessWidget {
  const _StatsSectionCard({required this.section});

  final DashboardSection section;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: section.title,
      actionLabel: section.route == null ? null : 'OPEN',
      onAction: () => _openDashboardRoute(context, section.route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.body ??
                (section.empty ? 'Not enough data yet.' : 'Current trend.'),
            style: AppTextStyles.body,
          ),
          if (section.metrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MetricGrid(metrics: section.metrics),
          ],
          if (section.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in section.items) _ActivityRow(item: item),
          ],
        ],
      ),
    );
  }
}

class _StatsEmptyPanel extends StatelessWidget {
  const _StatsEmptyPanel({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final cta = switch (kind) {
      'tracer' => ('RECORD TRACER', '/tracer/new'),
      'rounds' => ('START ROUND', '/rounds/start'),
      'clubs' => ('OPEN CLUB BAG', '/profile/club-bag'),
      'faults' => ('RECORD SWING', '/swing/record'),
      'swings' => ('RECORD SWING', '/swing/record'),
      _ => ('START CAPTURE', '/swing/record'),
    };
    return _SectionPanel(
      title: 'Not Enough Data Yet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statsEmptyBody(kind), style: AppTextStyles.body),
          const SizedBox(height: 14),
          GhostButton(
            label: cta.$1,
            onPressed: () => _openDashboardRoute(context, cta.$2),
          ),
        ],
      ),
    );
  }
}

class _StatsRouteOption {
  const _StatsRouteOption({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
  });

  final String kind;
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
}

class PerformanceSnapshotScreen extends ConsumerWidget {
  const PerformanceSnapshotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: token == null
              ? const EmptyState(
                  title: 'SIGN IN REQUIRED',
                  body: 'Sign in to view your performance snapshot.',
                )
              : FutureBuilder<DashboardSection>(
                  future: ref
                      .read(apiClientProvider)
                      .getPerformanceSnapshot(token),
                  builder: (context, snapshot) {
                    final section = snapshot.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PERFORMANCE SNAPSHOT',
                          style: AppTextStyles.title,
                        ),
                        const SizedBox(height: 18),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          Expanded(
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                _PerformanceSnapshot(
                                  section:
                                      section ??
                                      const DashboardSection(
                                        title: 'Performance Snapshot',
                                        body:
                                            'Not enough data yet. Record a swing or trace a shot.',
                                        empty: true,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String? _favoritesToken;
  String? _selectedFolderId;
  Future<_FavoritesPayload>? _future;

  Future<_FavoritesPayload> _load(String token) async {
    final api = ref.read(apiClientProvider);
    final folders = await api.getFavoriteFolders(token);
    final favorites = await api.getFavorites(
      token,
      folderId: _selectedFolderId,
    );
    return _FavoritesPayload(folders: folders, favorites: favorites);
  }

  void _refresh(String token) {
    setState(() {
      _future = _load(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    if (token != null && token != _favoritesToken) {
      _favoritesToken = token;
      _future = _load(token);
    }
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/home'),
                  ),
                  const Expanded(
                    child: Text('FAVORITES', style: AppTextStyles.title),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Saved swing sessions, reports, and visual tracer results.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              GhostButton(
                label: 'NEW FOLDER',
                onPressed: token == null ? null : () => _createFolder(token),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: token == null
                    ? const EmptyState(
                        title: 'SIGN IN REQUIRED',
                        body: 'Sign in to view favorites.',
                      )
                    : FutureBuilder<_FavoritesPayload>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return const ErrorText('Unable to load favorites.');
                          }
                          final payload =
                              snapshot.data ?? const _FavoritesPayload();
                          return RefreshIndicator(
                            color: AppColors.textPrimary,
                            backgroundColor: AppColors.elevated,
                            onRefresh: () async => _refresh(token),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                _FavoriteFolderFilters(
                                  folders: payload.folders,
                                  selectedFolderId: _selectedFolderId,
                                  onSelected: (folderId) {
                                    setState(() {
                                      _selectedFolderId = folderId;
                                      _future = _load(token);
                                    });
                                  },
                                ),
                                if (_selectedFolderId != null) ...[
                                  const SizedBox(height: 12),
                                  GhostButton(
                                    label: 'DELETE SELECTED FOLDER',
                                    onPressed: () =>
                                        _deleteSelectedFolder(token),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                if (payload.favorites.isEmpty)
                                  const _ScrollableEmptyState(
                                    title: 'NO FAVORITES SAVED',
                                    body:
                                        'Save a swing session, analysis report, or tracer result to pin it here.',
                                  )
                                else
                                  for (final favorite in payload.favorites) ...[
                                    _FavoriteTile(
                                      favorite: favorite,
                                      onOpen: () => _openDashboardRoute(
                                        context,
                                        favorite.route,
                                      ),
                                      onRemove: () =>
                                          _removeFavorite(token, favorite.id),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createFolder(String token) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New folder'),
          content: AppTextField(controller: controller, label: 'Folder name'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await ref.read(apiClientProvider).createFavoriteFolder(token, {
                  'name': name,
                });
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('CREATE'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (created == true && mounted) _refresh(token);
  }

  Future<void> _deleteSelectedFolder(String token) async {
    final folderId = _selectedFolderId;
    if (folderId == null) return;
    try {
      await ref.read(apiClientProvider).deleteFavoriteFolder(token, folderId);
      if (!mounted) return;
      setState(() {
        _selectedFolderId = null;
        _future = _load(token);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to delete folder.')));
    }
  }

  Future<void> _removeFavorite(String token, String favoriteId) async {
    try {
      await ref.read(apiClientProvider).deleteFavorite(token, favoriteId);
      if (mounted) _refresh(token);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove favorite.')),
      );
    }
  }
}

class _FavoritesPayload {
  const _FavoritesPayload({this.folders = const [], this.favorites = const []});

  final List<FavoriteFolder> folders;
  final List<FavoriteItem> favorites;
}

class _FavoriteFolderFilters extends StatelessWidget {
  const _FavoriteFolderFilters({
    required this.folders,
    required this.selectedFolderId,
    required this.onSelected,
  });

  final List<FavoriteFolder> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ChoiceChip(
          label: const Text('ALL'),
          selected: selectedFolderId == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final folder in folders)
          ChoiceChip(
            label: Text(folder.name.toUpperCase()),
            selected: selectedFolderId == folder.id,
            onSelected: (_) => onSelected(folder.id),
          ),
      ],
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.favorite,
    required this.onOpen,
    required this.onRemove,
  });

  final FavoriteItem favorite;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                favorite.title.toUpperCase(),
                style: AppTextStyles.label,
              ),
            ),
            IconButton(
              tooltip: 'Open favorite',
              icon: const Icon(Icons.chevron_right),
              onPressed: onOpen,
            ),
          ],
        ),
        if (favorite.body != null) Text(favorite.body!),
        Text(favorite.entityType.replaceAll('_', ' ').toUpperCase()),
        if (favorite.note != null && favorite.note!.isNotEmpty)
          Text('NOTE: ${favorite.note}'),
        GhostButton(label: 'REMOVE FAVORITE', onPressed: onRemove),
      ],
    );
  }
}

class _ScrollableEmptyState extends StatelessWidget {
  const _ScrollableEmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).height * 0.36,
      ),
      child: EmptyState(title: title, body: body),
    );
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _token;
  bool _unreadOnly = false;
  Future<_NotificationsPayload>? _future;

  Future<_NotificationsPayload> _load(String token) async {
    final api = ref.read(apiClientProvider);
    final notifications = await api.getNotifications(
      token,
      unreadOnly: _unreadOnly,
    );
    final preferences = await api.getNotificationPreferences(token);
    final unreadCount = await api.getNotificationUnreadCount(token);
    return _NotificationsPayload(
      notifications: notifications,
      preferences: preferences,
      unreadCount: unreadCount,
    );
  }

  Future<void> _refresh(String token) async {
    final future = _load(token);
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    if (token != null && token != _token) {
      _token = token;
      _future = _load(token);
    }
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/home'),
                  ),
                  const Expanded(
                    child: Text('NOTIFICATIONS', style: AppTextStyles.title),
                  ),
                  IconButton(
                    key: const ValueKey('notifications-preferences-button'),
                    tooltip: 'Preferences',
                    icon: const Icon(Icons.tune),
                    onPressed: token == null
                        ? null
                        : () => _openPreferences(token),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Analysis, tracer, round, billing, and system updates.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('ALL')),
                  ButtonSegment(value: true, label: Text('UNREAD')),
                ],
                selected: {_unreadOnly},
                onSelectionChanged: token == null
                    ? null
                    : (selection) {
                        setState(() {
                          _unreadOnly = selection.first;
                          _future = _load(token);
                        });
                      },
              ),
              const SizedBox(height: 14),
              Expanded(
                child: token == null
                    ? const EmptyState(
                        title: 'SIGN IN REQUIRED',
                        body: 'Sign in to view notifications.',
                      )
                    : FutureBuilder<_NotificationsPayload>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return const ErrorText(
                              'Unable to load notifications.',
                            );
                          }
                          final payload =
                              snapshot.data ?? const _NotificationsPayload();
                          return RefreshIndicator(
                            color: AppColors.textPrimary,
                            backgroundColor: AppColors.elevated,
                            onRefresh: () => _refresh(token),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                _NotificationSummary(
                                  unreadCount: payload.unreadCount,
                                  onMarkAllRead: payload.unreadCount == 0
                                      ? null
                                      : () => _markAllRead(token),
                                ),
                                const SizedBox(height: 14),
                                if (payload.notifications.isEmpty)
                                  _ScrollableEmptyState(
                                    title: _unreadOnly
                                        ? 'NO UNREAD NOTIFICATIONS'
                                        : 'NO NOTIFICATIONS',
                                    body:
                                        'SwingLens updates will appear here when real app events occur.',
                                  )
                                else
                                  for (final notification
                                      in payload.notifications) ...[
                                    _NotificationTile(
                                      notification: notification,
                                      onOpen: notification.route == null
                                          ? null
                                          : () => _openDashboardRoute(
                                              context,
                                              notification.route,
                                            ),
                                      onMarkRead: notification.isRead
                                          ? null
                                          : () => _markRead(
                                              token,
                                              notification.id,
                                            ),
                                      onDelete: () => _deleteNotification(
                                        token,
                                        notification.id,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markRead(String token, String notificationId) async {
    try {
      await ref
          .read(apiClientProvider)
          .markNotificationRead(token, notificationId);
      if (mounted) await _refresh(token);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to mark notification read.')),
      );
    }
  }

  Future<void> _markAllRead(String token) async {
    try {
      await ref.read(apiClientProvider).markAllNotificationsRead(token);
      if (mounted) await _refresh(token);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to mark all read.')));
    }
  }

  Future<void> _deleteNotification(String token, String notificationId) async {
    try {
      await ref
          .read(apiClientProvider)
          .deleteNotification(token, notificationId);
      if (mounted) await _refresh(token);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete notification.')),
      );
    }
  }

  Future<void> _openPreferences(String token) async {
    late final NotificationPreferences current;
    try {
      current = await ref
          .read(apiClientProvider)
          .getNotificationPreferences(token);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load preferences.')),
      );
      return;
    }
    if (!mounted) return;
    final updated = await showDialog<NotificationPreferences>(
      context: context,
      builder: (dialogContext) {
        return _NotificationPreferencesDialog(preferences: current);
      },
    );
    if (updated == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .updateNotificationPreferences(token, updated);
      if (mounted) await _refresh(token);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save preferences.')),
      );
    }
  }
}

class _NotificationsPayload {
  const _NotificationsPayload({
    this.notifications = const [],
    this.preferences = const NotificationPreferences(
      analysisComplete: true,
      tracerReview: true,
      renderReady: true,
      uploadFailure: true,
      billing: true,
      roundReminders: true,
      system: true,
    ),
    this.unreadCount = 0,
  });

  final List<NotificationItem> notifications;
  final NotificationPreferences preferences;
  final int unreadCount;
}

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('$unreadCount UNREAD', style: AppTextStyles.label),
            ),
            TextButton(
              key: const ValueKey('notifications-read-all-button'),
              onPressed: onMarkAllRead,
              child: const Text('MARK ALL READ'),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onOpen,
    required this.onMarkRead,
    required this.onDelete,
  });

  final NotificationItem notification;
  final VoidCallback? onOpen;
  final VoidCallback? onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('notification-tile-${notification.id}'),
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: InfoPanel(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  notification.title.toUpperCase(),
                  style: AppTextStyles.label,
                ),
              ),
              _StatusPill(label: notification.isRead ? 'READ' : 'UNREAD'),
            ],
          ),
          if (notification.body != null) Text(notification.body!),
          Row(
            children: [
              Expanded(
                child: Text(
                  notification.type.replaceAll('_', ' ').toUpperCase(),
                  style: AppTextStyles.body,
                ),
              ),
              IconButton(
                key: ValueKey('notification-open-${notification.id}'),
                tooltip: 'Open',
                icon: const Icon(Icons.chevron_right),
                onPressed: onOpen,
              ),
              IconButton(
                key: ValueKey('notification-mark-read-${notification.id}'),
                tooltip: 'Mark read',
                icon: const Icon(Icons.done),
                onPressed: onMarkRead,
              ),
              IconButton(
                key: ValueKey('notification-delete-${notification.id}'),
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationPreferencesDialog extends StatefulWidget {
  const _NotificationPreferencesDialog({required this.preferences});

  final NotificationPreferences preferences;

  @override
  State<_NotificationPreferencesDialog> createState() =>
      _NotificationPreferencesDialogState();
}

class _NotificationPreferencesDialogState
    extends State<_NotificationPreferencesDialog> {
  late NotificationPreferences _preferences = widget.preferences;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notification Preferences'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PreferenceSwitch(
              title: 'Analysis Complete',
              value: _preferences.analysisComplete,
              onChanged: (value) => setState(
                () => _preferences = _preferences.copyWith(
                  analysisComplete: value,
                ),
              ),
            ),
            _PreferenceSwitch(
              title: 'Tracer Review',
              value: _preferences.tracerReview,
              onChanged: (value) => setState(
                () => _preferences = _preferences.copyWith(tracerReview: value),
              ),
            ),
            _PreferenceSwitch(
              title: 'Render Ready',
              value: _preferences.renderReady,
              onChanged: (value) => setState(
                () => _preferences = _preferences.copyWith(renderReady: value),
              ),
            ),
            _PreferenceSwitch(
              title: 'Upload Failure',
              value: _preferences.uploadFailure,
              onChanged: (value) => setState(
                () =>
                    _preferences = _preferences.copyWith(uploadFailure: value),
              ),
            ),
            _PreferenceSwitch(
              title: 'Billing',
              value: _preferences.billing,
              onChanged: (value) => setState(
                () => _preferences = _preferences.copyWith(billing: value),
              ),
            ),
            _PreferenceSwitch(
              title: 'Round Reminders',
              value: _preferences.roundReminders,
              onChanged: (value) => setState(
                () =>
                    _preferences = _preferences.copyWith(roundReminders: value),
              ),
            ),
            _PreferenceSwitch(
              title: 'System',
              value: _preferences.system,
              onChanged: (value) => setState(
                () => _preferences = _preferences.copyWith(system: value),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_preferences),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title.toUpperCase(), style: AppTextStyles.label),
      value: value,
      onChanged: onChanged,
    );
  }
}

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String? _token;
  Future<List<DashboardItem>>? _future;

  Future<List<DashboardItem>> _load(String token) {
    return ref.read(apiClientProvider).getActivity(token);
  }

  Future<void> _refresh(String token) async {
    final future = _load(token);
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authControllerProvider).state.accessToken;
    if (token != null && token != _token) {
      _token = token;
      _future = _load(token);
    }
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/home'),
                  ),
                  const Expanded(
                    child: Text('ACTIVITY', style: AppTextStyles.title),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Recent swings, tracers, rounds, favorites, and notifications.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: token == null
                    ? const EmptyState(
                        title: 'SIGN IN REQUIRED',
                        body: 'Sign in to view activity.',
                      )
                    : FutureBuilder<List<DashboardItem>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return const ErrorText('Unable to load activity.');
                          }
                          final items = snapshot.data ?? const [];
                          return RefreshIndicator(
                            color: AppColors.textPrimary,
                            backgroundColor: AppColors.elevated,
                            onRefresh: () => _refresh(token),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                if (items.isEmpty)
                                  const _ScrollableEmptyState(
                                    title: 'NO ACTIVITY YET',
                                    body:
                                        'Captured swings, saved favorites, and notifications will appear here.',
                                  )
                                else
                                  for (final item in items)
                                    _ActivityRow(item: item),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardPlaceholderScreen extends StatelessWidget {
  const DashboardPlaceholderScreen({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryRoute,
    super.key,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final String primaryRoute;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: AppTextStyles.title),
              const SizedBox(height: 14),
              Text(body, style: AppTextStyles.body),
              const SizedBox(height: 22),
              InfoPanel(
                children: const [
                  Text('STATUS: PLANNED'),
                  Text(
                    'This section is intentionally empty until its real backend domain exists.',
                  ),
                ],
              ),
              const Spacer(),
              PrimaryButton(
                label: primaryLabel.toUpperCase(),
                onPressed: () => context.go(primaryRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SwingLibraryScreen extends ConsumerWidget {
  const SwingLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).state;
    final token = auth.accessToken;
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
                onPressed: () => context.go('/home'),
              ),
              const Text('SWING LIBRARY', style: AppTextStyles.title),
              const SizedBox(height: 18),
              Expanded(
                child: token == null
                    ? const Center(child: Text('Sign in required.'))
                    : FutureBuilder<List<SwingSession>>(
                        future: ref
                            .read(apiClientProvider)
                            .getSwingSessions(token),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return ErrorText(
                              'Unable to load swings. Start the backend and try again.',
                            );
                          }
                          final sessions = snapshot.data ?? const [];
                          if (sessions.isEmpty) {
                            return const EmptyState(
                              title: 'NO SWINGS YET',
                              body:
                                  'Upload your first face-on or down-the-line swing.',
                            );
                          }
                          return ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              return PanelButton(
                                title:
                                    session.club?.toUpperCase() ??
                                    'SWING SESSION',
                                subtitle:
                                    '${_sessionTypeLabel(session)} · ${session.status.toUpperCase()} · ${session.videos.length} VIDEO · ${_qualityLabel(session)}',
                                onPressed: () =>
                                    context.go('/swings/${session.id}'),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SwingDetailScreen extends ConsumerWidget {
  const SwingDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authControllerProvider).state.accessToken;
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
                onPressed: () => context.go('/swings'),
              ),
              const Text('SWING DETAIL', style: AppTextStyles.title),
              const SizedBox(height: 18),
              Expanded(
                child: token == null
                    ? const Center(child: Text('Sign in required.'))
                    : FutureBuilder<SwingSession>(
                        future: ref
                            .read(apiClientProvider)
                            .getSwingSession(token, sessionId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return const ErrorText(
                              'Unable to load swing detail.',
                            );
                          }
                          final session = snapshot.data!;
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InfoPanel(
                                  children: [
                                    Text(
                                      'CLUB: ${session.club?.toUpperCase() ?? 'UNKNOWN'}',
                                    ),
                                    Text(
                                      'STATUS: ${session.status.toUpperCase()}',
                                    ),
                                    Text(
                                      'LOCATION: ${session.locationType?.toUpperCase() ?? 'UNSET'}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                FavoriteToggleButton(
                                  accessToken: token,
                                  entityType: 'swing_session',
                                  entityId: session.id,
                                  saveLabel: 'SAVE SESSION',
                                  savedLabel: 'SESSION SAVED',
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'VIDEOS',
                                  style: AppTextStyles.label,
                                ),
                                const SizedBox(height: 10),
                                for (final video in session.videos) ...[
                                  InfoPanel(
                                    children: [
                                      Text(
                                        'ANGLE: ${video.angle.toUpperCase()}',
                                      ),
                                      Text(
                                        'QUALITY: ${video.qualityStatus?.toUpperCase() ?? 'PENDING'}',
                                      ),
                                      Text(
                                        'SCORE: ${video.qualityScore == null ? 'UNSET' : video.qualityScore!.toStringAsFixed(0)}',
                                      ),
                                      if (video.durationMs != null)
                                        Text(
                                          'DURATION: ${(video.durationMs! / 1000).toStringAsFixed(1)} SEC',
                                        ),
                                      for (final check
                                          in video.qualityChecks.take(5))
                                        Text(
                                          '${check.severity.toUpperCase()}: ${check.message}',
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  GhostButton(
                                    label: 'DELETE VIDEO',
                                    onPressed: () => _confirmDeleteSwingVideo(
                                      context: context,
                                      ref: ref,
                                      accessToken: token,
                                      sessionId: session.id,
                                      videoId: video.id,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (_isTracerSession(session))
                                  TracerExperiencePanel(
                                    session: session,
                                    accessToken: token,
                                  )
                                else
                                  AnalysisExperiencePanel(
                                    session: session,
                                    accessToken: token,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isTracerSession(SwingSession session) {
  return session.sessionType == 'tracer' ||
      session.videos.any((video) => video.angle == 'rear_tracer');
}

String _sessionTypeLabel(SwingSession session) {
  return _isTracerSession(session) ? 'TRACER' : 'ANALYSIS';
}

String _qualityLabel(SwingSession session) {
  if (session.videos.isEmpty) return 'NO QUALITY';
  final status = session.videos.first.qualityStatus;
  return status == null ? 'QUALITY PENDING' : 'QUALITY ${status.toUpperCase()}';
}

Future<void> _confirmDeleteSwingVideo({
  required BuildContext context,
  required WidgetRef ref,
  required String accessToken,
  required String sessionId,
  required String videoId,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete video?'),
        content: const Text(
          'This removes the private video and its analysis evidence.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref
        .read(apiClientProvider)
        .deleteSwingVideo(
          accessToken: accessToken,
          sessionId: sessionId,
          videoId: videoId,
        );
    if (context.mounted) context.go('/swings');
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to delete video right now.')),
    );
  }
}

class AnalysisExperiencePanel extends ConsumerStatefulWidget {
  const AnalysisExperiencePanel({
    required this.session,
    required this.accessToken,
    super.key,
  });

  final SwingSession session;
  final String accessToken;

  @override
  ConsumerState<AnalysisExperiencePanel> createState() =>
      _AnalysisExperiencePanelState();
}

class _AnalysisExperiencePanelState
    extends ConsumerState<AnalysisExperiencePanel> {
  AnalysisResult? _result;
  AnalysisJob? _job;
  bool _isLoading = true;
  bool _isStarting = false;
  bool _isPolling = false;
  bool _showCompletion = false;
  int _displayProgress = 0;
  String? _error;
  Timer? _pollTimer;
  Timer? _displayProgressTimer;
  Timer? _completionTimer;

  static const _displayProgressTick = Duration(milliseconds: 800);
  static const _completionHold = Duration(milliseconds: 650);

  @override
  void initState() {
    super.initState();
    unawaited(_loadExistingResult());
  }

  @override
  void didUpdateWidget(covariant AnalysisExperiencePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.accessToken != widget.accessToken) {
      _pollTimer?.cancel();
      _stopDisplayedProgress();
      _completionTimer?.cancel();
      _result = null;
      _job = null;
      _error = null;
      _isLoading = true;
      _showCompletion = false;
      _displayProgress = 0;
      unawaited(_loadExistingResult());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _stopDisplayedProgress();
    _completionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExistingResult({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
        _showCompletion = false;
      });
    } else {
      setState(() => _error = null);
    }
    try {
      final result = await ref
          .read(apiClientProvider)
          .getAnalysisResult(widget.accessToken, widget.session.id);
      if (!mounted) return;
      _stopDisplayedProgress();
      _completionTimer?.cancel();
      setState(() {
        _result = result;
        _job = null;
        _isLoading = false;
        _showCompletion = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load analysis result.';
        _isLoading = false;
        _showCompletion = false;
      });
    }
  }

  Future<void> _startAnalysis() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      final job = await ref
          .read(apiClientProvider)
          .startAnalysisJob(widget.accessToken, widget.session.id);
      if (!mounted) return;
      _setDisplayedJob(job, isStarting: false);
      if (job.isSucceeded) {
        _showCompletedThenLoad(job);
      } else if (job.isActive) {
        _schedulePolling();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to start analysis. Check the backend worker.';
        _isStarting = false;
      });
    }
  }

  void _schedulePolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollJob());
    });
    unawaited(_pollJob());
  }

  Future<void> _pollJob() async {
    final jobId = _job?.id;
    if (jobId == null || _isPolling) return;
    _isPolling = true;
    try {
      final job = await ref
          .read(apiClientProvider)
          .getAnalysisJob(widget.accessToken, jobId);
      if (!mounted) return;
      _setDisplayedJob(job);
      if (job.isSucceeded) {
        _showCompletedThenLoad(job);
      } else if (job.isFailed) {
        _pollTimer?.cancel();
        _stopDisplayedProgress();
      }
    } catch (_) {
      if (!mounted) return;
      _pollTimer?.cancel();
      _stopDisplayedProgress();
      setState(() => _error = 'Unable to poll analysis status.');
    } finally {
      _isPolling = false;
    }
  }

  void _setDisplayedJob(AnalysisJob job, {bool? isStarting}) {
    final backendProgress = job.progress.clamp(0, 100).toInt();
    final targetProgress = job.isSucceeded
        ? 100
        : backendProgress.clamp(0, 99).toInt();
    setState(() {
      _job = job;
      _isStarting = isStarting ?? _isStarting;
      _error = null;
      _showCompletion = job.isSucceeded;
      if (_displayProgress < targetProgress || job.isSucceeded) {
        _displayProgress = targetProgress;
      }
    });
    if (job.isActive) {
      _startDisplayedProgress();
    } else {
      _stopDisplayedProgress();
    }
  }

  void _startDisplayedProgress() {
    if (_displayProgressTimer?.isActive ?? false) return;
    _displayProgressTimer = Timer.periodic(_displayProgressTick, (_) {
      if (!mounted) return;
      final job = _job;
      if (job == null || !job.isActive || _result != null || _showCompletion) {
        _stopDisplayedProgress();
        return;
      }
      setState(() {
        final backendProgress = job.progress.clamp(0, 99).toInt();
        if (_displayProgress < backendProgress) {
          _displayProgress = backendProgress;
        }
        if (_displayProgress >= 99) return;
        final step = _displayProgress < 45
            ? 3
            : _displayProgress < 75
            ? 2
            : 1;
        final nextProgress = _displayProgress + step;
        _displayProgress = nextProgress > 99 ? 99 : nextProgress;
      });
    });
  }

  void _stopDisplayedProgress() {
    _displayProgressTimer?.cancel();
    _displayProgressTimer = null;
  }

  void _showCompletedThenLoad(AnalysisJob job) {
    _pollTimer?.cancel();
    _stopDisplayedProgress();
    _completionTimer?.cancel();
    setState(() {
      _job = job;
      _isStarting = false;
      _isLoading = false;
      _error = null;
      _showCompletion = true;
      _displayProgress = 100;
    });
    _completionTimer = Timer(_completionHold, () {
      if (!mounted) return;
      _completionTimer = null;
      unawaited(_loadExistingResult(showLoading: false));
    });
  }

  int _visibleProgressFor(AnalysisJob job) {
    if (_showCompletion || job.isSucceeded) return 100;
    final backendProgress = job.progress.clamp(0, 99).toInt();
    return _displayProgress < backendProgress
        ? backendProgress
        : _displayProgress;
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.session.videos.isEmpty
        ? null
        : widget.session.videos.first;
    if (_isLoading) {
      return const InfoPanel(
        children: [
          Text('ANALYSIS SYSTEM', style: AppTextStyles.label),
          LinearProgressIndicator(minHeight: 2),
        ],
      );
    }

    final result = _result;
    if (result != null) {
      return _AnalysisResultOverview(
        result: result,
        accessToken: widget.accessToken,
        video: video,
      );
    }

    final job = _job;
    if (job != null && (_showCompletion || job.isSucceeded)) {
      return _AnalysisProcessingHero(
        job: job,
        video: video,
        accessToken: widget.accessToken,
        displayProgress: 100,
        isCompleting: true,
      );
    }

    if (_error != null && job != null && job.isActive) {
      return _AnalysisProcessingHero(
        job: job,
        video: video,
        accessToken: widget.accessToken,
        displayProgress: _visibleProgressFor(job),
        isCompleting: _showCompletion,
        error: _error,
        onCheckStatus: _pollJob,
      );
    }

    if (job != null && job.isActive) {
      return _AnalysisProcessingHero(
        job: job,
        video: video,
        accessToken: widget.accessToken,
        displayProgress: _visibleProgressFor(job),
        isCompleting: _showCompletion,
      );
    }

    if (job != null && job.isFailed) {
      return _AnalysisFailureHero(
        message: _friendlyAnalysisFailure(job.errorMessage),
        detail: job.errorMessage,
        isStarting: _isStarting,
        onRetry: _startAnalysis,
      );
    }

    return _AnalysisStartPanel(
      error: _error,
      isStarting: _isStarting,
      hasVideo: video != null,
      onStart: _startAnalysis,
    );
  }
}

class _AnalysisStartPanel extends StatelessWidget {
  const _AnalysisStartPanel({
    required this.isStarting,
    required this.hasVideo,
    required this.onStart,
    this.error,
  });

  final bool isStarting;
  final bool hasVideo;
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        const Text('ANALYSIS READY', style: AppTextStyles.label),
        const Text('Start a pose, event, and movement review for this swing.'),
        if (error != null) Text(error!),
        PrimaryButton(
          label: isStarting ? 'STARTING...' : 'START ANALYSIS',
          onPressed: isStarting || !hasVideo ? null : onStart,
        ),
      ],
    );
  }
}

class _AnalysisFailureHero extends StatelessWidget {
  const _AnalysisFailureHero({
    required this.message,
    required this.isStarting,
    required this.onRetry,
    this.detail,
  });

  final String message;
  final String? detail;
  final bool isStarting;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InfoPanel(
      children: [
        const Text('ANALYSIS INTERRUPTED', style: AppTextStyles.label),
        Text(message),
        if (detail != null) Text('DETAIL: $detail'),
        PrimaryButton(
          label: isStarting ? 'STARTING...' : 'RETRY ANALYSIS',
          onPressed: isStarting ? null : onRetry,
        ),
      ],
    );
  }
}

class _AnalysisProcessingHero extends StatelessWidget {
  const _AnalysisProcessingHero({
    required this.job,
    required this.video,
    required this.accessToken,
    required this.displayProgress,
    this.isCompleting = false,
    this.error,
    this.onCheckStatus,
  });

  final AnalysisJob job;
  final SwingVideo? video;
  final String accessToken;
  final int displayProgress;
  final bool isCompleting;
  final String? error;
  final VoidCallback? onCheckStatus;

  @override
  Widget build(BuildContext context) {
    final boundedProgress = displayProgress.clamp(0, 100).toInt();
    final progress = boundedProgress / 100;
    final statusLabel =
        '${isCompleting ? 'COMPLETE' : job.status.toUpperCase()} · $boundedProgress%';
    final attemptLabel = job.maxAttempts > 1
        ? 'ATTEMPT ${job.attemptCount.clamp(1, job.maxAttempts)} OF ${job.maxAttempts}'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI ANALYSIS', style: AppTextStyles.label),
          const SizedBox(height: 12),
          if (video != null)
            SwingVideoPreviewSurface(
              video: video!,
              accessToken: accessToken,
              aspectRatio: 9 / 16,
              overlay: _ProcessingScanOverlay(progress: progress),
            )
          else
            AspectRatio(
              aspectRatio: 9 / 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _ProcessingScanOverlay(progress: progress),
              ),
            ),
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(statusLabel, style: AppTextStyles.label),
          ),
          if (attemptLabel != null) ...[
            const SizedBox(height: 6),
            Text(attemptLabel, style: AppTextStyles.micro),
          ],
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            semanticsLabel: 'Analysis progress',
            semanticsValue: boundedProgress.toString(),
          ),
          const SizedBox(height: 14),
          _ProcessingChecklist(progress: boundedProgress),
          if (error != null) ...[
            const Divider(color: AppColors.border, height: 24),
            Text(error!),
            const SizedBox(height: 12),
            GhostButton(label: 'CHECK STATUS', onPressed: onCheckStatus),
          ],
        ],
      ),
    );
  }
}

class _ProcessingScanOverlay extends StatelessWidget {
  const _ProcessingScanOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scanProgress = progress.clamp(0, 1).toDouble();
    final scanAlignment = Alignment(0, -1 + (scanProgress * 2));
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.46),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.58),
              ],
            ),
          ),
        ),
        Align(
          alignment: scanAlignment,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.86),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.42),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Text(
            'ANALYZING WITH SWINGLENS AI',
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.86),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProcessingChecklist extends StatelessWidget {
  const _ProcessingChecklist({required this.progress});

  final int progress;

  static const _steps = [
    _ProcessingStep('VIDEO PREPARED', 5),
    _ProcessingStep('POSE TRACKED', 25),
    _ProcessingStep('SWING EVENTS MAPPED', 50),
    _ProcessingStep('EVIDENCE FRAMES SELECTED', 75),
    _ProcessingStep('REPORT BUILT', 95),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final step in _steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: progress >= step.threshold
                        ? AppColors.textPrimary
                        : Colors.transparent,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    progress >= step.threshold ? Icons.check : Icons.more_horiz,
                    size: 16,
                    color: progress >= step.threshold
                        ? Colors.black
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.label,
                    style: AppTextStyles.body.copyWith(
                      color: progress >= step.threshold
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProcessingStep {
  const _ProcessingStep(this.label, this.threshold);

  final String label;
  final int threshold;
}

class _AnalysisResultOverview extends ConsumerStatefulWidget {
  const _AnalysisResultOverview({
    required this.result,
    required this.accessToken,
    required this.video,
  });

  final AnalysisResult result;
  final String accessToken;
  final SwingVideo? video;

  @override
  ConsumerState<_AnalysisResultOverview> createState() =>
      _AnalysisResultOverviewState();
}

class _AnalysisResultOverviewState
    extends ConsumerState<_AnalysisResultOverview> {
  SwingReport? _report;
  bool _isReportLoading = true;
  String? _reportError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReport());
  }

  @override
  void didUpdateWidget(covariant _AnalysisResultOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.id != widget.result.id ||
        oldWidget.accessToken != widget.accessToken) {
      unawaited(_loadReport());
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isReportLoading = true;
      _reportError = null;
    });
    try {
      final report = await ref
          .read(apiClientProvider)
          .getSwingReport(
            accessToken: widget.accessToken,
            resultId: widget.result.id,
          );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isReportLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _report = null;
        _reportError = 'Detailed report is unavailable.';
        _isReportLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final report = _report;
    final score = _scoreValue(report, result);
    final insight = _primaryInsight(report, result);
    final metrics = _overviewMetricItems(report, result, widget.video);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ANALYSIS REVIEW', style: AppTextStyles.label),
        const SizedBox(height: 10),
        if (widget.video != null) ...[
          SwingFilmRoom(
            result: result,
            video: widget.video!,
            accessToken: widget.accessToken,
            mode: SwingFilmRoomMode.overview,
          ),
          const SizedBox(height: 18),
        ],
        _AnalysisScorePanel(
          score: score,
          scoreLabel: report?.score == null ? 'POSE SCORE' : 'MOVEMENT SCORE',
          insight: insight,
          summary: result.summary,
          isReportLoading: _isReportLoading,
          reportError: _reportError,
        ),
        const SizedBox(height: 12),
        _MetricStrip(metrics: metrics),
        const SizedBox(height: 12),
        _QuickFindingPanel(insight: insight),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'VIEW FULL BREAKDOWN',
          onPressed: () => context.go('/swings/${result.sessionId}/report'),
        ),
      ],
    );
  }
}

class _AnalysisScorePanel extends StatelessWidget {
  const _AnalysisScorePanel({
    required this.score,
    required this.scoreLabel,
    required this.insight,
    required this.summary,
    required this.isReportLoading,
    required this.reportError,
  });

  final int? score;
  final String scoreLabel;
  final _AnalysisInsight insight;
  final String summary;
  final bool isReportLoading;
  final String? reportError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ScoreLockup(score: score, label: scoreLabel),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(insight.label.toUpperCase()),
                    if (insight.confidence != null)
                      Text(
                        'CONFIDENCE ${_percent(insight.confidence)}',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 24),
          Text(summary),
          if (isReportLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (reportError != null) ...[
            const SizedBox(height: 12),
            Text(
              reportError!,
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreLockup extends StatelessWidget {
  const _ScoreLockup({required this.score, required this.label});

  final int? score;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LIMITED', style: AppTextStyles.title.copyWith(fontSize: 28)),
            const SizedBox(height: 6),
            const Text('REVIEW LIMITED', style: AppTextStyles.micro),
          ],
        ),
      );
    }
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            score.toString(),
            style: AppTextStyles.title.copyWith(fontSize: 56, height: 0.9),
          ),
          Text(
            '/100',
            style: AppTextStyles.micro.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.micro),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metrics});

  final List<_MetricSummary> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final metric in metrics)
          Container(
            width: 148,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  style: AppTextStyles.title.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 6),
                Text(metric.label.toUpperCase(), style: AppTextStyles.micro),
                if (metric.status != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    metric.status!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _QuickFindingPanel extends StatelessWidget {
  const _QuickFindingPanel({required this.insight});

  final _AnalysisInsight insight;

  @override
  Widget build(BuildContext context) {
    final hasPractice = insight.drill != null || insight.nextGoal != null;
    return InfoPanel(
      children: [
        Text(
          hasPractice ? 'FIX THIS FIRST' : 'EVIDENCE SUMMARY',
          style: AppTextStyles.label,
        ),
        if (insight.evidence != null) Text(insight.evidence!),
        if (insight.drill != null) Text('DRILL: ${insight.drill}'),
        if (insight.nextGoal != null) Text('NEXT GOAL: ${insight.nextGoal}'),
        if (insight.evidence == null &&
            insight.drill == null &&
            insight.nextGoal == null)
          const Text(
            'The detailed report will show available evidence and capture limits.',
          ),
      ],
    );
  }
}

class SwingReportScreen extends ConsumerStatefulWidget {
  const SwingReportScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SwingReportScreen> createState() => _SwingReportScreenState();
}

class _SwingReportScreenState extends ConsumerState<SwingReportScreen> {
  SwingSession? _session;
  AnalysisResult? _result;
  SwingReport? _report;
  bool _isLoading = true;
  String? _error;
  String? _reportError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant SwingReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _reportError = null;
    });
    final token = ref.read(authControllerProvider).state.accessToken;
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Sign in required.';
        _isLoading = false;
      });
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final session = await api.getSwingSession(token, widget.sessionId);
      final result = await api.getAnalysisResult(token, widget.sessionId);
      SwingReport? report;
      String? reportError;
      if (result != null) {
        try {
          report = await api.getSwingReport(
            accessToken: token,
            resultId: result.id,
          );
        } catch (_) {
          reportError = 'Detailed report is unavailable.';
        }
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _result = result;
        _report = report;
        _reportError = reportError;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load analysis breakdown.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authControllerProvider).state.accessToken;
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
                onPressed: () => context.go('/swings/${widget.sessionId}'),
              ),
              const Text('ANALYSIS BREAKDOWN', style: AppTextStyles.title),
              const SizedBox(height: 18),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(token),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(String? token) {
    if (_error != null) {
      return ErrorText(_error!);
    }
    final result = _result;
    if (token == null) {
      return const Center(child: Text('Sign in required.'));
    }
    if (result == null) {
      return const EmptyState(
        title: 'NO ANALYSIS YET',
        body: 'Start analysis from the swing detail screen first.',
      );
    }

    final video = _videoForResult(_session, result);
    final diagnosis = _mapValue(result.report['diagnosis']);
    final visualEvidence = _mapValue(diagnosis?['visual_evidence']);
    final overlaySegments = _mapList(visualEvidence?['segments']);
    final frameAspectRatio = _frameAspectRatio(result.metrics);
    final score = _scoreValue(_report, result);
    final insight = _primaryInsight(_report, result);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (video != null) ...[
            SwingFilmRoom(
              result: result,
              video: video,
              accessToken: token,
              mode: SwingFilmRoomMode.detailed,
              onReviewChanged: _load,
            ),
            const SizedBox(height: 18),
          ],
          FavoriteToggleButton(
            accessToken: token,
            entityType: 'swing_report',
            entityId: widget.sessionId,
            saveLabel: 'SAVE REPORT',
            savedLabel: 'REPORT SAVED',
          ),
          const SizedBox(height: 12),
          _AnalysisScorePanel(
            score: score,
            scoreLabel: _report?.score == null
                ? 'POSE SCORE'
                : 'MOVEMENT SCORE',
            insight: insight,
            summary: result.summary,
            isReportLoading: false,
            reportError: _reportError,
          ),
          const SizedBox(height: 12),
          _DetailedReportPanel(
            report: _report,
            result: result,
            reportError: _reportError,
          ),
          const SizedBox(height: 18),
          const Text('KEY MOMENTS', style: AppTextStyles.label),
          const SizedBox(height: 10),
          if (result.keyframes.isEmpty)
            const InfoPanel(children: [Text('No keyframes were produced.')])
          else
            for (final keyframe in result.keyframes) ...[
              _AnalysisKeyframeTile(
                keyframe: keyframe,
                accessToken: token,
                imageUrl: ref
                    .read(apiClientProvider)
                    .analysisKeyframeImageUrl(keyframe.id),
                overlay: _overlayForPhase(visualEvidence, keyframe.phaseCode),
                overlaySegments: overlaySegments,
                frameAspectRatio: frameAspectRatio,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _DetailedReportPanel extends StatelessWidget {
  const _DetailedReportPanel({
    required this.report,
    required this.result,
    required this.reportError,
  });

  final SwingReport? report;
  final AnalysisResult result;
  final String? reportError;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    if (report == null) {
      final limitations = _stringList(result.report['limitations']);
      return InfoPanel(
        children: [
          const Text('FULL REPORT', style: AppTextStyles.label),
          Text(reportError ?? 'Full report details are unavailable.'),
          Text(
            'POSE COVERAGE: ${_percent(result.poseSummary['pose_coverage'])}',
          ),
          for (final limitation in limitations.take(3)) Text(limitation),
        ],
      );
    }

    final primaryFinding = report.findings.isEmpty
        ? null
        : report.findings.first;
    return InfoPanel(
      children: [
        const Text('FULL REPORT', style: AppTextStyles.label),
        Text(
          'STATUS: ${report.status.toUpperCase()} · ${report.source.toUpperCase()}',
        ),
        if (report.score != null) Text('MOVEMENT SCORE: ${report.score}'),
        if (primaryFinding != null) ...[
          Text('PRIMARY: ${primaryFinding.label.toUpperCase()}'),
          if (primaryFinding.confidence != null)
            Text('CONFIDENCE: ${_percent(primaryFinding.confidence)}'),
          if (primaryFinding.whatHappened.isNotEmpty)
            Text('WHAT HAPPENED: ${primaryFinding.whatHappened}'),
          if (primaryFinding.whyItMatters.isNotEmpty)
            Text('WHY IT MATTERS: ${primaryFinding.whyItMatters}'),
          if (primaryFinding.drill.isNotEmpty)
            Text('FIX DRILL: ${primaryFinding.drill}'),
          if (primaryFinding.nextGoal.isNotEmpty)
            Text('NEXT GOAL: ${primaryFinding.nextGoal}'),
        ],
        const Text('METRICS', style: AppTextStyles.label),
        if (report.metricCards.isEmpty)
          const Text('Advanced metrics are limited for this capture.')
        else
          for (final card in report.metricCards.take(8))
            Text(
              '${card.label.toUpperCase()}: ${_metricValue(card)} · ${card.status.toUpperCase()}',
            ),
        for (final limitation in report.limitations.take(3)) Text(limitation),
      ],
    );
  }
}

class _AnalysisInsight {
  const _AnalysisInsight({
    required this.label,
    this.confidence,
    this.evidence,
    this.drill,
    this.nextGoal,
  });

  final String label;
  final double? confidence;
  final String? evidence;
  final String? drill;
  final String? nextGoal;
}

class _MetricSummary {
  const _MetricSummary({required this.label, required this.value, this.status});

  final String label;
  final String value;
  final String? status;
}

int? _scoreValue(SwingReport? report, AnalysisResult result) {
  final movementScore = report?.score;
  if (movementScore != null) return movementScore;
  final poseScore = result.prototypeScore;
  if (poseScore != null) return poseScore.round().clamp(0, 100).toInt();
  return null;
}

_AnalysisInsight _primaryInsight(SwingReport? report, AnalysisResult result) {
  final reportFinding = report == null || report.findings.isEmpty
      ? null
      : report.findings.first;
  if (reportFinding != null) {
    return _AnalysisInsight(
      label: reportFinding.label,
      confidence: reportFinding.confidence,
      evidence: _emptyToNull(reportFinding.whatHappened),
      drill: _emptyToNull(reportFinding.drill),
      nextGoal: _emptyToNull(reportFinding.nextGoal),
    );
  }

  final diagnosis = _mapValue(result.report['diagnosis']);
  final primaryFault = _mapValue(diagnosis?['primary_fault']);
  if (primaryFault != null) {
    return _AnalysisInsight(
      label: primaryFault['label'] as String? ?? 'Swing pattern',
      confidence: (primaryFault['confidence'] as num?)?.toDouble(),
      evidence: primaryFault['evidence'] as String?,
      drill: primaryFault['drill'] as String?,
      nextGoal: primaryFault['next_practice_goal'] as String?,
    );
  }

  final reportLimited = report?.status == 'limited';
  final diagnosisLimited = diagnosis?['status'] == 'limited';
  final limitations = <String>[
    ...?report?.limitations,
    ..._stringList(diagnosis?['limitations']),
    ..._stringList(result.report['limitations']),
  ];
  return _AnalysisInsight(
    label: reportLimited || diagnosisLimited
        ? 'Pose review limited'
        : 'No primary fault detected',
    evidence: limitations.isEmpty ? null : limitations.first,
  );
}

List<_MetricSummary> _overviewMetricItems(
  SwingReport? report,
  AnalysisResult result,
  SwingVideo? video,
) {
  final cards = report?.metricCards
      .where((card) => card.label.trim().isNotEmpty)
      .take(3)
      .map(
        (card) => _MetricSummary(
          label: card.label,
          value: _metricValue(card),
          status: card.status,
        ),
      )
      .toList();
  if (cards != null && cards.isNotEmpty) return cards;

  final poseCoverage = _percent(result.poseSummary['pose_coverage']);
  final qualityScore = video?.qualityScore;
  final videoQuality = qualityScore == null
      ? video?.qualityStatus?.toUpperCase() ?? 'UNSET'
      : qualityScore.round().toString();
  final detectedEvents = result.phases.length;
  return [
    _MetricSummary(label: 'Pose coverage', value: poseCoverage),
    _MetricSummary(label: 'Video quality', value: videoQuality),
    _MetricSummary(label: 'Events mapped', value: detectedEvents.toString()),
  ];
}

SwingVideo? _videoForResult(SwingSession? session, AnalysisResult result) {
  final videos = session?.videos ?? const [];
  for (final video in videos) {
    if (video.id == result.swingVideoId) return video;
  }
  return videos.isEmpty ? null : videos.first;
}

String? _emptyToNull(String value) {
  return value.trim().isEmpty ? null : value;
}

class _AnalysisKeyframeTile extends StatelessWidget {
  const _AnalysisKeyframeTile({
    required this.keyframe,
    required this.accessToken,
    required this.imageUrl,
    required this.overlay,
    required this.overlaySegments,
    required this.frameAspectRatio,
  });

  final AnalysisKeyframe keyframe;
  final String accessToken;
  final String imageUrl;
  final Map<String, dynamic>? overlay;
  final List<Map<String, dynamic>> overlaySegments;
  final double frameAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: AspectRatio(
              aspectRatio: frameAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    headers: {'Authorization': 'Bearer $accessToken'},
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.panelStrong,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
                      );
                    },
                  ),
                  if (overlay != null)
                    CustomPaint(
                      painter: SwingOverlayPainter(
                        overlay: overlay!,
                        segments: overlaySegments,
                      ),
                    ),
                  if (overlay != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: Text(
                            'SKELETON',
                            style: AppTextStyles.micro.copyWith(fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _phaseLabel(keyframe.phaseCode),
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 6),
                Text(
                  '${(keyframe.timestampMs / 1000).toStringAsFixed(2)} SEC · FRAME ${keyframe.frameIndex}',
                  style: AppTextStyles.body,
                ),
                if (keyframe.confidence != null)
                  Text(
                    'CONFIDENCE ${(keyframe.confidence! * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.body,
                  ),
                if (overlay != null)
                  const Text(
                    'LINES: SPINE · SHOULDERS · HIPS',
                    style: AppTextStyles.body,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _phaseLabel(String phaseCode) {
  return switch (phaseCode) {
    'P1' => 'P1 SETUP',
    'P4' => 'P4 TOP',
    'P7' => 'P7 IMPACT',
    'P10' => 'P10 FINISH',
    _ => phaseCode.toUpperCase(),
  };
}

String _percent(Object? value) {
  if (value is num) return '${(value * 100).toStringAsFixed(0)}%';
  return 'UNKNOWN';
}

String _metricValue(SwingMetricCard card) {
  final value = card.value;
  if (value == null) return 'UNKNOWN';
  final formatted = value is num
      ? value.toStringAsFixed(value % 1 == 0 ? 0 : 2)
      : value.toString();
  return card.unit.isEmpty ? formatted : '$formatted ${card.unit}';
}

Map<String, dynamic>? _mapValue(Object? value) {
  if (value == null) return null;
  return Map<String, dynamic>.from(value as Map);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value == null) return const [];
  return (value as List<dynamic>)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  return (value as List<dynamic>).whereType<String>().toList();
}

Map<String, dynamic>? _overlayForPhase(
  Map<String, dynamic>? visualEvidence,
  String phaseCode,
) {
  final overlays = _mapList(visualEvidence?['phase_overlays']);
  for (final overlay in overlays) {
    if (overlay['phase_code'] == phaseCode) return overlay;
  }
  return null;
}

double _frameAspectRatio(Map<String, dynamic> metrics) {
  final width = metrics['resolution_width'];
  final height = metrics['resolution_height'];
  if (width is num && height is num && width > 0 && height > 0) {
    return (width / height).clamp(0.42, 1.9).toDouble();
  }
  return 16 / 9;
}

String _friendlyAnalysisFailure(String? message) {
  final lower = (message ?? '').toLowerCase();
  if (lower.contains('no frames') || lower.contains('sampled')) {
    return 'The video could not be read frame by frame. Try a shorter MOV or MP4 recorded at normal speed.';
  }
  if (lower.contains('open uploaded video') || lower.contains('opencv')) {
    return 'The uploaded file could not be opened as a supported video. Choose a fresh camera recording and upload again.';
  }
  if (lower.contains('storage') || lower.contains('private storage')) {
    return 'Private video storage was temporarily unavailable. Retry analysis when the backend is healthy.';
  }
  if (lower.contains('timeout')) {
    return 'Analysis took too long for this prototype. Try a shorter 2 to 15 second swing clip.';
  }
  return 'Analysis failed. Try again with a clear 2 to 15 second swing video.';
}
