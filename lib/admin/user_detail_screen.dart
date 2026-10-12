import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'admin_config.dart';
import 'admin_models.dart';
import 'widgets/admin_widgets.dart';

/// One person: who they are, how far they got, and what they did.
class AdminUserDetailScreen extends StatelessWidget {
  const AdminUserDetailScreen({super.key, required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todays = user.events
        .where((e) => !e.time.isBefore(today))
        .toList();
    final earlier = user.events
        .where((e) => e.time.isBefore(today))
        .take(25)
        .toList();

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              AdminBar(title: user.name),
              Expanded(
                child: ListView(
                  padding: adminPadding.copyWith(bottom: 40),
                  children: [
                    _Header(user: user, now: now),
                    const AdminHeading('Journey'),
                    _Journey(user: user),
                    const AdminHeading('Today'),
                    if (todays.isEmpty)
                      Text('Nothing yet today.', style: AstraTextStyles.bodyDim)
                    else
                      _EventList(events: todays, showDate: false),
                    const AdminHeading('Earlier activity'),
                    if (earlier.isEmpty)
                      Text('No earlier activity.', style: AstraTextStyles.bodyDim)
                    else
                      _EventList(events: earlier, showDate: true),
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

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.now});

  final AdminUser user;
  final DateTime now;

  @override
  Widget build(BuildContext context) => TintCard(
    tint: AdminTints.lilac,
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
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AstraTextStyles.display(20),
                  ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AstraTextStyles.small,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PlanPill(user: user),
                      Text('📍 ${user.country}', style: AstraTextStyles.small),
                      Text('🔥 ${user.streak} day streak', style: AstraTextStyles.small),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Fact('Joined', shortDate(user.joinedAt)),
            _Fact('Last seen', ago(user.lastSeen, now)),
            _Fact('Actions', '${user.events.length}'),
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

class _Journey extends StatelessWidget {
  const _Journey({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final subscribedLine = user.subscribed
        ? 'Subscribed · ${user.plan.name} plan'
              '${user.subscribedAt == null ? '' : ', ${shortDate(user.subscribedAt!)}'}'
        : user.churned
        ? 'Subscribed once, now ended'
        : 'Subscribed';

    return TintCard(
      tint: AdminTints.mint,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        children: [
          _Step('Onboarding complete', user.onboardingComplete),
          _Step(AdminConfig.keyStepLabel, user.typedWish),
          _Step(
            user.reachedPaywall
                ? 'Reached paywall · ${user.paywallViews}×'
                : 'Reached paywall',
            user.reachedPaywall,
          ),
          _Step(
            user.triedToPay
                ? 'Tried to pay · ${user.paymentAttempts} '
                      '${user.paymentAttempts == 1 ? 'attempt' : 'attempts'}'
                : 'Tried to pay',
            user.triedToPay,
          ),
          _Step(subscribedLine, user.everSubscribed),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Paid so far: ${money(user.paidTotal)} in '
                '${user.payments.length} ${user.payments.length == 1 ? 'payment' : 'payments'}',
                style: AstraTextStyles.body.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.label, this.done);

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 22,
          color: done ? AdminTints.mint : AstraColors.line,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AstraTextStyles.body.copyWith(
              color: done ? AstraColors.text : AstraColors.dim.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events, required this.showDate});

  final List<AdminEvent> events;
  final bool showDate;

  @override
  Widget build(BuildContext context) => AstraCard(
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
                  showDate
                      ? '${shortDate(event.time)}, ${timeOfDay(event.time)}'
                      : timeOfDay(event.time),
                  style: AstraTextStyles.small,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
