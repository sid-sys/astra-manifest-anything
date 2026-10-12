import 'admin_config.dart';
import 'admin_models.dart';

/// Works out every dashboard number from the user list. Pure: the same users and
/// the same [now] always give the same stats.
AdminStats computeAdminStats(List<AdminUser> users, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final weekAgo = today.subtract(const Duration(days: 6));
  final monthAgo = now.subtract(const Duration(days: 30));

  var revenueTotal = 0.0;
  var revenue30 = 0.0;
  var manifestations30 = 0;
  var affirmations30 = 0;

  for (final user in users) {
    for (final payment in user.payments) {
      revenueTotal += payment.amount;
      if (payment.time.isAfter(monthAgo)) revenue30 += payment.amount;
    }
    for (final event in user.events) {
      if (!event.time.isAfter(monthAgo)) continue;
      if (event.type == EventType.manifestationMade) manifestations30++;
      if (event.type == EventType.affirmationsMade) affirmations30++;
    }
  }

  final costLines = <String, double>{
    'AI manifestations ($manifestations30)':
        manifestations30 * AdminConfig.manifestationCost,
    'AI affirmations ($affirmations30)':
        affirmations30 * AdminConfig.affirmationsCost,
    'Fixed monthly bills': AdminConfig.fixedMonthlyTotal,
  };
  final costs30 = costLines.values.fold(0.0, (sum, cost) => sum + cost);

  final dailyActive = [
    for (var back = 13; back >= 0; back--)
      (
        day: today.subtract(Duration(days: back)),
        count: users
            .where((user) => user.wasActiveOn(today.subtract(Duration(days: back))))
            .length,
      ),
  ];

  return AdminStats(
    totalUsers: users.length,
    newThisWeek: users.where((u) => !u.joinedAt.isBefore(weekAgo)).length,
    subscribed: users.where((u) => u.subscribed).length,
    paying: users
        .where((u) => u.plan != AdminPlan.none)
        .length,
    activeToday: dailyActive.last.count,
    activeThisWeek: users
        .where((u) => u.events.any((e) => !e.time.isBefore(weekAgo)))
        .length,
    revenueTotal: revenueTotal,
    revenue30: revenue30,
    costs30: costs30,
    costLines: costLines,
    dailyActive: dailyActive,
    funnel: [
      FunnelStep('Joined', users.length),
      FunnelStep(
        'Finished onboarding',
        users.where((u) => u.onboardingComplete).length,
      ),
      FunnelStep(AdminConfig.keyStepLabel, users.where((u) => u.typedWish).length),
      FunnelStep('Reached paywall', users.where((u) => u.reachedPaywall).length),
      FunnelStep('Tried to pay', users.where((u) => u.triedToPay).length),
      FunnelStep('Subscribed', users.where((u) => u.everSubscribed).length),
    ],
  );
}
