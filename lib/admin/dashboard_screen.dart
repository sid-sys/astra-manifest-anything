import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../screens/admin_screen.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'admin_config.dart';
import 'admin_feedback_screen.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'users_screen.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/day_chart.dart';

/// Opens a list of the real people behind a number or a bar.
void _openPeople(
  BuildContext context,
  String title,
  List<PersonEntry> people, {
  String empty = 'Nobody here yet.',
  bool full = false,
  Map<String, String> reasons = const {},
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminUsersScreen(
        title: title,
        entries: people,
        emptyText: empty,
        full: full,
        reasons: reasons,
      ),
    ),
  );
}

List<PersonEntry> _everyone(List<AdminUser> users, [String? note]) => [
  for (final user in users) PersonEntry(user, note: note),
];

/// The admin dashboard: the numbers that say whether Mayow is working.
///
/// Reads only from [adminViewProvider], and shows real people only: the same
/// switch filters every number, chart, list and funnel.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(adminViewProvider);

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              AdminBar(
                title: 'Admin panel',
                logo: true,
                actions: [
                  AdminIconButton(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh',
                    onTap: () => ref.invalidate(adminDataProvider),
                  ),
                ],
              ),
              Expanded(
                child: view.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (error, _) => _Failed(
                    error: error,
                    onRetry: () => ref.invalidate(adminDataProvider),
                  ),
                  data: (data) => _Body(view: data),
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
  const _Body({required this.view});

  final AdminView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email =
        ref.watch(authStateProvider).valueOrNull?.email ?? AdminConfig.adminEmail;

    final left = <Widget>[
      _RealOnlyCard(view: view),
      const SizedBox(height: 14),
      _Metrics(view: view),
      const SizedBox(height: 8),
      Text(
        'Costs, last 30 days: ${view.stats.costLines.entries.map((e) => '${e.key.split(' (').first} ${money(e.value)}').join(' · ')}',
        style: AstraTextStyles.small,
      ),
      const AdminHeading('Activity'),
      _ChartCard(stats: view.stats),
    ];

    final right = <Widget>[
      const AdminHeading('From installing to subscribing'),
      _FunnelCard(stats: view.stats),
      const AdminHeading('When paying did not happen'),
      _FailuresCard(stats: view.stats),
      const AdminHeading('Where people heard about us'),
      _SourcesCard(stats: view.stats),
      const SizedBox(height: 22),
      _Buttons(view: view),
    ];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminDataProvider),
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 760;
          final header = [
            Text('Signed in as $email', style: AstraTextStyles.small),
            Text(
              'Payments are estimated from plan prices; Google Play does not '
              'send receipts.',
              style: AstraTextStyles.small,
            ),
            const SizedBox(height: 14),
          ];

          return ListView(
            padding: adminPadding.copyWith(bottom: 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: wide
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...header,
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: left,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: right,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [...header, ...left, ...right],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RealOnlyCard extends ConsumerWidget {
  const _RealOnlyCard({required this.view});

  final AdminView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = view.hidden;
    final on = view.realOnly;

    final line = hidden.isEmpty
        ? 'No test, review or robot accounts found'
        : on
        ? 'Hiding ${hidden.length} test, review and my own '
              '${hidden.length == 1 ? 'account' : 'accounts'}'
        : 'Showing everything, including ${hidden.length} '
              'test, review and my own ${hidden.length == 1 ? 'account' : 'accounts'}';

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Real users only', style: AstraTextStyles.display(18)),
              ),
              Switch(
                value: on,
                activeThumbColor: AdminColors.text,
                activeTrackColor: AdminColors.primary,
                onChanged: (v) => ref.read(realUsersOnlyProvider.notifier).state = v,
              ),
            ],
          ),
          InkWell(
            onTap: hidden.isEmpty
                ? null
                : () => _openPeople(
                    context,
                    'Hidden accounts',
                    [for (final h in hidden) PersonEntry(h.user)],
                    reasons: {for (final h in hidden) h.user.id: h.reason},
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line,
                      style: AstraTextStyles.small.copyWith(
                        color: hidden.isEmpty ? null : AdminColors.link,
                      ),
                    ),
                  ),
                  if (hidden.isNotEmpty)
                    const Icon(Icons.chevron_right_rounded, size: 20, color: AdminColors.link),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.view});

  final AdminView view;

  @override
  Widget build(BuildContext context) {
    final s = view.stats;
    final share = s.totalUsers == 0 ? 0 : (s.paying / s.totalUsers * 100).round();
    final after = s.revenue30 * (1 - AdminConfig.storeCut) - s.costs30;
    final paid = _everyone(s.paidLast30, 'Paid in the last 30 days');

    return MetricGrid(
      children: [
        MetricCard(
          emoji: '👥',
          title: 'Total users',
          value: '${s.totalUsers}',
          sub: '+${s.newThisWeek} this week',
          onTap: () => _openPeople(
            context,
            'All users',
            _everyone(s.users),
            full: true,
            empty: 'No users yet.',
          ),
        ),
        MetricCard(
          emoji: '💎',
          title: 'Subscribed',
          value: '${s.paying}',
          sub: '$share% of users',
          onTap: () => _openPeople(
            context,
            'Subscribed',
            _everyone(s.subscribedUsers),
            empty: 'Nobody has subscribed yet.',
          ),
        ),
        MetricCard(
          emoji: '⚡',
          title: 'Active today',
          value: '${s.activeToday.length}',
          sub: '${s.activeThisWeek} active this week',
          onTap: () => _openPeople(
            context,
            'Active today',
            _everyone(s.activeToday, 'Opened the app'),
            empty: 'Nobody has opened the app today.',
          ),
        ),
        MetricCard(
          emoji: '💰',
          title: 'Revenue (last 30 days)',
          value: money(s.revenue30),
          sub: '${money(s.revenueTotal)} since the start',
          onTap: () => _openPeople(
            context,
            'Paid in the last 30 days',
            paid,
            empty: 'Nobody has paid in the last 30 days.',
          ),
        ),
        MetricCard(
          emoji: '📈',
          title: 'Profit before store cut',
          value: money(s.profitBeforeCut),
          sub: '30 days. Costs ${money(s.costs30)}',
          onTap: () => _openPeople(
            context,
            'Paid in the last 30 days',
            paid,
            empty: 'Nobody has paid in the last 30 days.',
          ),
        ),
        MetricCard(
          emoji: '🏦',
          title: 'Profit after store cut',
          value: money(after),
          sub: 'After Google\'s ${(AdminConfig.storeCut * 100).round()}%',
          onTap: () => _openPeople(
            context,
            'Paid in the last 30 days',
            paid,
            empty: 'Nobody has paid in the last 30 days.',
          ),
        ),
      ],
    );
  }
}

/// One card, one chart, one toggle. Tapping a bar opens the people behind it.
class _ChartCard extends StatefulWidget {
  const _ChartCard({required this.stats});

  final AdminStats stats;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  ChartMode _mode = ChartMode.active;
  bool _note = false;

  static const _activeNote =
      'Each bar is the number of people who opened the app that day. '
      'Tap a bar to see who. Days are UTC days.';

  static const _installNote =
      'Each phone with the app tells our server once a day, and we keep one '
      'record per phone, so a phone counts once even if several accounts use '
      'it.\n\n'
      'Installed: the day Android says the app was installed on that phone. A '
      'phone that only updated the app still counts on its real install day. '
      'We show the person who last logged in on it.\n\n'
      'Uninstalled: once a day our server asks Google whether each phone can '
      'still receive messages. Nothing is sent and nobody is told. If Google '
      'says the app is gone, we mark that day. We never guess.\n\n'
      'Limits: an uninstall can show a day or two late, and a phone that was '
      'off for a long time is only noticed when Google answers. If a phone '
      'reports in again, the uninstall mark is removed, and a reinstall counts '
      'as a new install.\n\n'
      'Net is installed minus uninstalled. Only Android phones that signed in '
      'are counted, so people who installed and never opened the app are not '
      'visible here; Play Console shows those. Days are UTC days.';

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminToggle(
            options: const ['Active users', 'Installs and uninstalls'],
            selected: _mode.index,
            onChanged: (i) => setState(() => _mode = ChartMode.values[i]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_mode == ChartMode.installs) ...[
                const _Key(AdminColors.good, 'Installed'),
                const SizedBox(width: 12),
                const _Key(AdminColors.bad, 'Uninstalled'),
              ] else
                Text('Last ${AdminConfig.chartDays} days', style: AstraTextStyles.small),
            ],
          ),
          const SizedBox(height: 8),
          DayChart(
            days: s.days,
            mode: _mode,
            onActive: (d) => _openPeople(
              context,
              'Active on ${dayTitle(d.day)}',
              d.active,
              empty: 'Nobody was active that day',
            ),
            onInstalled: (d) => _openPeople(
              context,
              'Installed on ${dayTitle(d.day)}',
              d.installed,
              empty: 'Nobody installed that day',
            ),
            onUninstalled: (d) => _openPeople(
              context,
              'Uninstalled on ${dayTitle(d.day)}',
              d.uninstalled,
              empty: 'Nobody uninstalled that day',
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _note = !_note),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _note ? 'Hide the note' : 'How is this counted?',
                style: AstraTextStyles.small.copyWith(color: AdminColors.link),
              ),
            ),
          ),
          if (_note)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _mode == ChartMode.active ? _activeNote : _installNote,
                style: AstraTextStyles.small,
              ),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(label, style: AstraTextStyles.small),
    ],
  );
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final steps = stats.funnel;
    final top = steps.fold<int>(0, (m, s) => s.count > m ? s.count : m);

    // The step after which the most people are lost.
    var stopsAfter = -1;
    var biggest = 0;
    for (var i = 1; i < steps.length; i++) {
      final lost = steps[i - 1].count - steps[i].count;
      if (lost > biggest) {
        biggest = lost;
        stopsAfter = i - 1;
      }
    }

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: stats.totalUsers == 0 && stats.installedPhones == 0
          ? const EmptyNote('No installs yet')
          : Column(
              children: [
                for (final (i, step) in steps.indexed)
                  FunnelRow(step: step, top: top, stopsHere: i == stopsAfter),
              ],
            ),
    );
  }
}

class _FailuresCard extends StatelessWidget {
  const _FailuresCard({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) => AdminCard(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: stats.failures.isEmpty
        ? const EmptyNote('No cancelled or failed payments yet')
        : Column(
            children: [
              for (final reason in stats.failures)
                InkWell(
                  onTap: () => _openPeople(context, reason.label, reason.people),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(reason.label, style: AstraTextStyles.label)),
                        const SizedBox(width: 8),
                        Text('${reason.count}', style: AstraTextStyles.display(18)),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
  );
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final top = stats.sources.fold<int>(0, (m, s) => s.count > m ? s.count : m);
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: stats.sources.isEmpty
          ? const EmptyNote('Nobody has answered yet')
          : Column(
              children: [
                for (final source in stats.sources)
                  InkWell(
                    onTap: () => _openPeople(context, source.label, source.people),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(source.label, style: AstraTextStyles.label),
                              ),
                              Text('${source.count}', style: AstraTextStyles.label),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                Container(
                                  height: 10,
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                FractionallySizedBox(
                                  widthFactor: top == 0 ? 0 : source.count / top,
                                  child: Container(height: 10, color: AdminColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.view});

  final AdminView view;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AstraButton(
        label: 'See all ${view.stats.totalUsers} users',
        onPressed: () => _openPeople(
          context,
          'All users',
          _everyone(view.stats.users),
          full: true,
          empty: 'No users yet.',
        ),
      ),
      const SizedBox(height: 10),
      AstraGhostButton(
        label: 'Feedback and bug reports',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminFeedbackScreen()),
        ),
      ),
      const SizedBox(height: 10),
      AstraGhostButton(
        label: 'Tools: announcements, trials, delete',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
        ),
      ),
    ],
  );
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
