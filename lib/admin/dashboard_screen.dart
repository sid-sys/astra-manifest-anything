import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../screens/admin_screen.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'admin_config.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'users_screen.dart';
import 'widgets/admin_widgets.dart';

/// The admin dashboard: the numbers that say whether Mayow is working.
///
/// Reads only from [adminStatsProvider], so it does not know whether the users
/// are real or made up.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final email =
        ref.watch(authStateProvider).valueOrNull?.email ?? AdminConfig.adminEmail;

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              AdminBar(
                title: 'Admin',
                actions: [
                  if (kAdminMock) const MockTag(),
                  const SizedBox(width: 8),
                  AdminIconButton(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh',
                    onTap: () => ref.invalidate(adminUsersProvider),
                  ),
                ],
              ),
              Expanded(
                child: stats.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (error, _) => _Failed(
                    error: error,
                    onRetry: () => ref.invalidate(adminUsersProvider),
                  ),
                  data: (data) => _Body(stats: data, email: email),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.stats, required this.email});

  final AdminStats stats;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profitAfter = stats.revenue30 * (1 - AdminConfig.storeCut) - stats.costs30;
    final costsLine = stats.costLines.entries
        .map((e) => '${e.key.split(' (').first} ${money(e.value)}')
        .join(' · ');

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminUsersProvider),
      child: ListView(
        padding: adminPadding.copyWith(bottom: 40),
        children: [
          Text('Signed in as $email', style: AstraTextStyles.small),
          if (!kAdminMock)
            Text(
              'Payments are estimated from plan prices.',
              style: AstraTextStyles.small,
            ),
          const SizedBox(height: 14),
          MetricGrid(
            children: [
              MetricCard(
                emoji: '👥',
                title: 'Total users',
                value: '${stats.totalUsers}',
                sub: '+${stats.newThisWeek} this week',
                tint: AdminTints.sky,
              ),
              MetricCard(
                emoji: '💎',
                title: 'Subscribed',
                value: '${stats.subscribed}',
                sub:
                    '${(stats.subscribedShare * 100).round()}% of users · '
                    '${stats.paying} paying · ${stats.lifetime} lifetime',
                tint: AdminTints.mint,
              ),
              MetricCard(
                emoji: '⚡',
                title: 'Active today',
                value: '${stats.activeToday}',
                sub: '${stats.activeThisWeek} active this week',
                tint: AdminTints.yellow,
              ),
              MetricCard(
                emoji: '💰',
                title: 'Revenue',
                value: money(stats.revenueTotal),
                sub: '${money(stats.revenue30)} in the last 30 days',
                tint: AdminTints.pink,
              ),
              MetricCard(
                emoji: '📈',
                title: 'Profit before store cut',
                value: money(stats.profitBeforeCut),
                sub: '30 days. Costs ${money(stats.costs30)}',
                tint: AdminTints.lilac,
              ),
              MetricCard(
                emoji: '🏦',
                title: 'Profit after store cut',
                value: money(profitAfter),
                sub: 'After Google\'s ${(AdminConfig.storeCut * 100).round()}%',
                tint: AdminTints.peach,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Costs, last 30 days: $costsLine', style: AstraTextStyles.small),

          const AdminHeading('Daily active users'),
          TintCard(
            tint: AdminTints.lilac,
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: SizedBox(height: 150, child: DauChart(days: stats.dailyActive)),
          ),

          const AdminHeading('From joining to subscribing'),
          TintCard(
            tint: AdminTints.mint,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              children: [
                for (final (i, step) in stats.funnel.indexed)
                  FunnelRow(
                    step: step,
                    joined: stats.funnel.first.count,
                    tint: i == stats.funnel.length - 1
                        ? AdminTints.mint
                        : AdminTints.sky,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          AstraButton(
            label: 'See all ${stats.totalUsers} users',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminUsersScreen()),
            ),
          ),
          if (!kAdminMock) ...[
            const SizedBox(height: 10),
            AstraGhostButton(
              label: 'Tools: announcements, trials, delete',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load the numbers', style: AstraTextStyles.display(20)),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center, style: AstraTextStyles.small),
          const SizedBox(height: 16),
          AstraButton(label: 'Try again', onPressed: onRetry),
        ],
      ),
    ),
  );
}
