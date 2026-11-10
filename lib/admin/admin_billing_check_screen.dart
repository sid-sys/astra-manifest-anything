import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/admin_service.dart' show AdminService;
import '../theme/astra_theme.dart';
import '../widgets/aura_background.dart';
import 'admin_config.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'widgets/admin_widgets.dart';

/// What Google Play says, right now, about each subscriber's money.
final adminBillingCheckProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => AdminService().billingCheck(),
);

/// Plain words for each verdict the server gives, and whether it is good news.
({String title, String why, bool good}) describeVerdict(Map<String, dynamic> row) {
  final days = row['daysSinceTrialEnded'];
  return switch (row['verdict']) {
    'paid' => (title: 'Paid', why: 'Google collected the money.', good: true),
    'paid_then_cancelled' => (
      title: 'Paid, then cancelled',
      why: 'Google collected the money. They will not renew.',
      good: true,
    ),
    'trial' => (title: 'In the free trial', why: 'No charge is due yet.', good: true),
    'test' => (
      title: 'Test purchase',
      why: 'A licence tester. No real money, on purpose.',
      good: true,
    ),
    'cancelled' => (
      title: 'Cancelled before paying',
      why: 'They cancelled during the trial. No money, as expected.',
      good: true,
    ),
    'ended' => (title: 'Ended', why: 'The subscription is over.', good: true),
    'card_failed' => (
      title: 'The card failed',
      why: 'Google could not collect. They are in grace or on hold.',
      good: false,
    ),
    'no_charge_yet' => (
      title: 'No charge yet',
      why:
          'The trial ended ${days ?? '?'} days ago and Google has no successful '
          'payment. The charge is waiting or being retried at Google. Check '
          'this order in Play Console, Order management.',
      good: false,
    ),
    _ => (
      title: 'Could not ask Google',
      why: '${row['error'] ?? 'Unknown error.'}',
      good: false,
    ),
  };
}

/// Live check of every subscriber with Google Play. The only place the panel
/// states money as fact instead of estimating it.
class AdminBillingCheckScreen extends ConsumerWidget {
  const AdminBillingCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(adminBillingCheckProvider);
    final users = ref.watch(adminDataProvider).valueOrNull?.users ?? const <AdminUser>[];
    String who(String? uid) {
      for (final u in users) {
        if (u.id == uid) return u.displayName;
      }
      return 'Unknown account';
    }

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              AdminBar(
                title: 'Payment check',
                actions: [
                  AdminIconButton(
                    icon: Icons.refresh_rounded,
                    label: 'Check again',
                    onTap: () => ref.invalidate(adminBillingCheckProvider),
                  ),
                ],
              ),
              Expanded(
                child: check.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (error, _) => EmptyNote('Could not ask Google.\n$error'),
                  data: (data) {
                    final rows = [
                      for (final r in (data['rows'] as List? ?? const []))
                        Map<String, dynamic>.from(r as Map),
                    ];
                    final access = data['googleAccess'] == 'ok';
                    final notified = rows.where((r) => r['notified'] == true).length;
                    final bad = rows.where((r) => !describeVerdict(r).good).length;
                    return ListView(
                      padding: adminPadding.copyWith(bottom: 32, top: 4),
                      children: [
                        AdminCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Line(
                                ok: access,
                                text: access
                                    ? 'Our server can read Google Play.'
                                    : 'Our server can NOT read Google Play. '
                                          'Money cannot be checked or trusted.',
                              ),
                              _Line(
                                ok: rows.isEmpty || notified > 0,
                                text:
                                    'Google has sent live notifications for '
                                    '$notified of ${rows.length} subscribers.',
                              ),
                              _Line(
                                ok: bad == 0,
                                text: bad == 0
                                    ? 'No problem found.'
                                    : '$bad subscriber${bad == 1 ? '' : 's'} need a look.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (rows.isEmpty)
                          const EmptyNote('Nobody has a purchase on record yet.'),
                        for (final row in rows) ...[
                          _Row(name: who(row['uid'] as String?), row: row),
                          const SizedBox(height: 8),
                        ],
                      ],
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

class _Line extends StatelessWidget {
  const _Line({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.error_rounded,
          size: 20,
          color: ok ? AdminColors.good : AdminColors.bad,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AstraTextStyles.body)),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.name, required this.row});

  final String name;
  final Map<String, dynamic> row;

  String _day(Object? iso) {
    final t = DateTime.tryParse('$iso');
    return t == null ? 'unknown' : '${shortDate(t)}, ${timeOfDay(t)}';
  }

  @override
  Widget build(BuildContext context) {
    final verdict = describeVerdict(row);
    final plan = '${row['productId']}'.contains('yearly') ? 'Yearly' : 'Monthly';
    final amount = row['orderAmount'];
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(name, style: AstraTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
              TagPill(plan, color: AdminColors.link),
              TagPill(
                verdict.title,
                color: verdict.good ? AdminColors.good : AdminColors.bad,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(verdict.why, style: AstraTextStyles.body),
          const SizedBox(height: 6),
          Text(
            [
              'Started ${_day(row['startTime'])}',
              if (row['expiryTime'] != null) 'Runs to ${_day(row['expiryTime'])}',
              if (row['autoRenew'] != null)
                row['autoRenew'] == true ? 'Will renew' : 'Will not renew',
              if (row['orderId'] != null)
                'Latest order ${row['orderId']}: ${row['orderState'] ?? '?'}'
                    '${amount is num ? ', $amount ${row['orderCurrency'] ?? ''}' : ''}',
              row['notified'] == true
                  ? 'Live notifications: yes (last ${row['lastEvent']?['type'] ?? '?'})'
                  : 'Live notifications: none yet',
            ].join('\n'),
            style: AstraTextStyles.small,
          ),
        ],
      ),
    );
  }
}
