import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';
import '../widgets/aura_background.dart';
import 'admin_config.dart';
import 'admin_models.dart';
import 'widgets/admin_widgets.dart';

/// One person: who they are, how far they got, what they told us, and what they
/// did.
class AdminUserDetailScreen extends StatelessWidget {
  const AdminUserDetailScreen({super.key, required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuraBackground(
      child: SafeArea(
        child: Column(
          children: [
            AdminBar(title: user.displayName),
            Expanded(
              child: ListView(
                padding: adminPadding.copyWith(bottom: 40),
                children: [
                  _Header(user: user),
                  const AdminHeading('Journey'),
                  _Journey(user: user),
                  const AdminHeading('What they told us'),
                  _Answers(user: user),
                  const AdminHeading('Activity'),
                  if (user.events.isEmpty)
                    const EmptyNote('No activity recorded yet.')
                  else
                    _EventList(events: user.events),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) => AdminCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AdminAvatar(initials: user.initials, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AstraTextStyles.display(20),
                  ),
                  Text(
                    user.email.isEmpty ? 'No email' : user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AstraTextStyles.small,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PlanPill(user: user),
            TagPill(user.isGuest ? 'Guest' : 'Signed up'),
            if (user.testPurchase)
              const TagPill('Test purchase', color: AdminColors.highlight),
            Text('📍 ${user.country}', style: AstraTextStyles.small),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Fact('Joined', shortDate(user.joinedAt)),
            _Fact('Last seen', ago(user.lastSeen)),
            _Fact('Days active', '${user.openDays.length}'),
          ],
        ),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AstraTextStyles.eyebrow.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: AstraTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

/// The funnel steps down a line, each with a tick and the time it happened.
class _Journey extends StatelessWidget {
  const _Journey({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final s = user.steps;

    String when(DateTime? t) => t == null ? '' : '${shortDate(t)}, ${timeOfDay(t)}';

    final took = user.onboardingSeconds;
    final subscribedLine = user.subscribed
        ? 'Subscribed · ${user.plan.name} plan'
        : user.churned
        ? 'Subscribed once, now ended'
        : 'Subscribed';

    final steps = <(String, bool, DateTime?, String?)>[
      ('Installed the app', user.installedAt != null, user.installedAt, null),
      ('Opened the app', true, s['app_open'] ?? user.joinedAt, null),
      (
        'Finished onboarding',
        user.onboardingComplete,
        s['onboarding_done'],
        took == null ? null : 'took ${took}s',
      ),
      (AdminConfig.keyStepLabel, user.typedWish, s['wish_typed'], null),
      (
        'Saw the paywall',
        user.reachedPaywall,
        s['paywall_view'],
        user.paywallViews > 1 ? '${user.paywallViews} times' : null,
      ),
      (
        'Tried to pay',
        user.triedToPay,
        s['subscribe_tap'],
        user.paymentAttempts > 1 ? '${user.paymentAttempts} attempts' : null,
      ),
      (subscribedLine, user.everSubscribed, s['purchase_ok'] ?? user.subscribedAt, null),
    ];

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          for (final (i, step) in steps.indexed)
            _Dot(
              label: step.$1,
              done: step.$2,
              time: when(step.$3),
              note: step.$4,
              last: i == steps.length - 1,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Estimated paid: ~${money(user.testPurchase ? 0 : user.paidTotal)} in '
                '${user.testPurchase ? 0 : user.payments.length} '
                '${user.payments.length == 1 ? 'payment' : 'payments'}. '
                'Play Console has the real number.',
                style: AstraTextStyles.body.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.label,
    required this.done,
    required this.time,
    required this.note,
    required this.last,
  });

  final String label;
  final bool done;
  final String time;
  final String? note;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 26,
          child: Column(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: done ? AdminColors.good : AstraColors.line,
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: AdminColors.cardEdge),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AstraTextStyles.body.copyWith(
                    color: done ? AdminColors.text : AdminColors.dim.withValues(alpha: 0.6),
                  ),
                ),
                if (done && (time.isNotEmpty || note != null))
                  Text(
                    [if (time.isNotEmpty) time, ?note].join(' · '),
                    style: AstraTextStyles.small,
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Answers extends StatelessWidget {
  const _Answers({required this.user});

  final AdminUser user;

  static const _belief = {
    'absolutely': 'Absolutely',
    'i-think-so': 'I think so',
    'not-sure': 'Not sure yet',
    'not-really': 'Not really',
  };
  static const _importance = {
    'not-sure': 'Not sure yet',
    'would-like-it': 'Would really like it',
    'very-important': 'Very important',
    'ready-to-change': 'Ready to change',
  };
  static const _reminder = {
    'morning': 'Morning',
    'evening': 'Evening',
    'both': 'Morning and evening',
    'later': 'Will decide later',
  };
  static const _source = {
    'instagram': 'Instagram',
    'tiktok': 'TikTok',
    'youtube': 'YouTube',
    'friend': 'A friend or family',
    'play-store': 'Searching Google Play',
    'other': 'Somewhere else',
  };

  @override
  Widget build(BuildContext context) {
    final a = user.answers;
    final areas = (a['areas'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    final rows = <(String, String?)>[
      ('Thoughts can shape reality', _belief['${a['belief']}']),
      ('Life areas', areas.isEmpty ? null : areas.join(', ')),
      ('How important the change is', _importance['${a['importance']}']),
      ('Where they heard about Mayow', _source[user.heardFrom] ?? _source['${a['heardFrom']}']),
      ('Reminders', _reminder['${a['reminderPref']}']),
    ];

    if (rows.every((r) => r.$2 == null)) {
      return const EmptyNote('They have not answered anything yet.');
    }

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: Text(label, style: AstraTextStyles.small)),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: Text(
                      value ?? 'Not answered',
                      textAlign: TextAlign.right,
                      style: AstraTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: value == null ? AdminColors.dim.withValues(alpha: 0.6) : null,
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

class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<AdminEvent> events;

  @override
  Widget build(BuildContext context) => AdminCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child: Column(
      children: [
        for (final event in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(describeEvent(event.type).emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        describeEvent(event.type).title,
                        style: AstraTextStyles.body.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (event.detail.isNotEmpty)
                        Text(
                          event.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AstraTextStyles.small,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${shortDate(event.time)}\n${timeOfDay(event.time)}',
                  textAlign: TextAlign.right,
                  style: AstraTextStyles.small,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
