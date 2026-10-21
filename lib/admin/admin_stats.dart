import 'admin_config.dart';
import 'admin_models.dart';

/// `2026-10-14`, the UTC day a time falls on. Every day in the panel is a UTC
/// day, because the server stores open days that way.
String utcDayKey(DateTime time) => time.toUtc().toIso8601String().substring(0, 10);

/// Works out every dashboard number from the people to count. Pure: the same
/// users, phones and [now] always give the same answer.
///
/// [devices] is every phone the server knows; only those whose owner is in
/// [users] are counted, so hiding an account hides its phones too.
AdminStats computeAdminStats(
  List<AdminUser> users,
  List<AdminDevice> devices,
  DateTime now,
) {
  final byId = {for (final user in users) user.id: user};
  final nowUtc = now.toUtc();
  final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
  final weekAgo = today.subtract(const Duration(days: 6));
  final monthAgo = now.subtract(const Duration(days: 30));

  final mine = devices.where((d) => byId.containsKey(d.ownerUid)).toList();

  // ---- money
  var revenueTotal = 0.0;
  var revenue30 = 0.0;
  final paidLast30 = <AdminUser>[];
  var manifestations30 = 0;
  var affirmations30 = 0;
  for (final user in users) {
    // A licence tester's "payment" is not money, whatever the switch says.
    if (!user.testPurchase) {
      var paidRecently = false;
      for (final payment in user.payments) {
        revenueTotal += payment.amount;
        if (payment.time.isAfter(monthAgo)) {
          revenue30 += payment.amount;
          paidRecently = true;
        }
      }
      if (paidRecently) paidLast30.add(user);
    }
    manifestations30 += user.manifestations.where((t) => t.isAfter(monthAgo)).length;
    affirmations30 += user.affirmationSets.where((t) => t.isAfter(monthAgo)).length;
  }

  final costLines = <String, double>{
    'AI manifestations ($manifestations30)':
        manifestations30 * AdminConfig.manifestationCost,
    'AI affirmations ($affirmations30)':
        affirmations30 * AdminConfig.affirmationsCost,
    'Fixed monthly bills': AdminConfig.fixedMonthlyTotal,
  };

  // ---- the two charts, one entry per UTC day
  final days = <DayStats>[
    for (var back = AdminConfig.chartDays - 1; back >= 0; back--)
      () {
        final day = today.subtract(Duration(days: back));
        final key = utcDayKey(day);
        return DayStats(
          day: day,
          active: [
            for (final user in users)
              if (user.wasActiveOn(key)) PersonEntry(user, note: 'Opened the app'),
          ],
          installed: [
            for (final device in mine)
              if (device.installedAt != null && utcDayKey(device.installedAt!) == key)
                PersonEntry(byId[device.ownerUid]!, time: device.installedAt),
          ],
          uninstalled: [
            for (final device in mine)
              if (device.uninstalledAt != null &&
                  utcDayKey(device.uninstalledAt!) == key)
                PersonEntry(byId[device.ownerUid]!, time: device.uninstalledAt),
          ],
        );
      }(),
  ];

  // ---- the funnel, from this app's own steps
  bool reached(AdminUser u, String step) =>
      u.onboardingComplete || u.steps.containsKey(step);

  final funnel = [
    FunnelStep('Installed', mine.length),
    FunnelStep('Opened the app', users.length),
    FunnelStep(
      'Started onboarding',
      users.where((u) => reached(u, 'onboarding_start')).length,
    ),
    FunnelStep(
      'Answered the belief question',
      users.where((u) => reached(u, 'onboarding_page_2')).length,
    ),
    FunnelStep(
      'Chose life areas',
      users.where((u) => reached(u, 'onboarding_page_3')).length,
    ),
    FunnelStep(
      'Said how important it is',
      users.where((u) => reached(u, 'onboarding_page_4')).length,
    ),
    FunnelStep(
      'Said where they heard about us',
      users.where((u) => reached(u, 'onboarding_page_5')).length,
    ),
    FunnelStep(
      'Finished onboarding',
      users.where((u) => u.onboardingComplete).length,
    ),
    FunnelStep(AdminConfig.keyStepLabel, users.where((u) => u.typedWish).length),
    FunnelStep('Saw the paywall', users.where((u) => u.reachedPaywall).length),
    FunnelStep('Tried to pay', users.where((u) => u.triedToPay).length),
    FunnelStep('Subscribed', users.where((u) => u.everSubscribed).length),
  ];

  // ---- why paying did not happen
  final failureGroups = <String, List<PersonEntry>>{};
  for (final user in users) {
    for (final failure in user.payFailures) {
      final label = switch (failure.kind) {
        'cancelled' => 'Closed the Google Play sheet without paying',
        'unavailable' => 'Google Play was not available on the phone',
        _ => failure.detail.isEmpty
            ? 'The payment failed'
            : 'The payment failed (${failure.detail})',
      };
      failureGroups
          .putIfAbsent(label, () => [])
          .add(PersonEntry(user, time: failure.time));
    }
  }

  // ---- where people heard about us
  const sourceNames = {
    'instagram': 'Instagram',
    'tiktok': 'TikTok',
    'youtube': 'YouTube',
    'friend': 'A friend or family',
    'play-store': 'Searching Google Play',
    'other': 'Somewhere else',
  };
  final sourceGroups = <String, List<PersonEntry>>{};
  for (final user in users) {
    final label = sourceNames[user.heardFrom] ?? 'Not asked yet';
    sourceGroups.putIfAbsent(label, () => []).add(PersonEntry(user));
  }

  List<ReasonCount> ranked(Map<String, List<PersonEntry>> groups) {
    final list = [for (final e in groups.entries) ReasonCount(e.key, e.value)]
      ..sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  return AdminStats(
    users: users,
    subscribedUsers: users.where((u) => u.subscribed && !u.testPurchase).toList(),
    activeToday: users.where((u) => u.wasActiveOn(utcDayKey(today))).toList(),
    paidLast30: paidLast30,
    newThisWeek: users.where((u) => !u.joinedAt.isBefore(weekAgo)).length,
    activeThisWeek: users
        .where(
          (u) => List.generate(7, (i) => utcDayKey(today.subtract(Duration(days: i))))
              .any(u.wasActiveOn),
        )
        .length,
    revenueTotal: revenueTotal,
    revenue30: revenue30,
    costs30: costLines.values.fold(0.0, (sum, cost) => sum + cost),
    costLines: costLines,
    days: days,
    funnel: funnel,
    installedPhones: mine.length,
    failures: ranked(failureGroups),
    sources: ranked(sourceGroups),
  );
}
