import 'dart:math';

import 'admin_config.dart';
import 'admin_models.dart';
import 'admin_repository.dart';

/// About fifty believable users, made from a fixed seed so the counts are the
/// same on every run. Used while [kAdminMock] is on.
///
/// The shape follows the rules the dashboard is built to be checked against:
/// about 92% finish onboarding, a smaller share reach the paywall, about half
/// of those try to pay, about 65% of those subscribe, subscribers use the app
/// more, and some of them leave. Payments use the real store prices.
class MockAdminRepository implements AdminRepository {
  MockAdminRepository({this.now});

  /// Fixed for tests; the real clock otherwise.
  final DateTime? now;

  @override
  Future<List<AdminUser>> loadUsers() async {
    // A beat of "loading", so the screens' spinner is exercised too.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return generateMockUsers(now: now ?? DateTime.now());
  }
}

const _first = [
  'Sana', 'Priya', 'Maya', 'Aarav', 'Emma', 'Liam', 'Noor', 'Zara', 'Olivia',
  'Rohan', 'Isha', 'Ava', 'Kabir', 'Mia', 'Ethan', 'Anaya', 'Sofia', 'Dev',
  'Lena', 'Omar', 'Chloe', 'Arjun', 'Hana', 'Jack', 'Tara', 'Leo', 'Nia',
  'Samir', 'Ella', 'Vikram', 'Ruby', 'Yash', 'Grace', 'Neil', 'Amara', 'Jay',
  'Kira', 'Reema', 'Theo', 'Dia', 'Finn', 'Meera', 'Sam', 'Lila', 'Raj',
  'Nora', 'Ivan', 'Pooja', 'Max', 'Alia',
];

const _last = [
  'Sharma', 'Patel', 'Khan', 'Smith', 'Nair', 'Brown', 'Iyer', 'Garcia',
  'Singh', 'Miller', 'Reddy', 'Wilson', 'Das', 'Taylor', 'Gupta', 'Clark',
  'Mehta', 'Lewis', 'Joshi', 'Walker',
];

const _countries = [
  'India', 'India', 'India', 'India', 'United States', 'United States',
  'United Kingdom', 'Canada', 'Australia', 'UAE', 'Germany', 'Singapore',
];

const _wishes = [
  'I want to wake up in a home that is actually mine',
  'I want to earn ten thousand a month from my own work',
  'I want to find my person',
  'I want to feel calm before my exams',
  'I want to run a marathon',
  'I want a promotion this year',
  'I want to stop being afraid of my own body',
  'I want to start my own studio',
];

/// Builds the mock users. Public so a test can check the numbers.
List<AdminUser> generateMockUsers({
  required DateTime now,
  int count = 50,
  int seed = 13,
}) {
  final rng = Random(seed);
  final today = DateTime(now.year, now.month, now.day);

  // A time on a given day, never in the future. The random draws are always
  // taken, so the same seed gives the same people whatever the time of day.
  DateTime at(int daysAgo) {
    final hour = rng.nextInt(24);
    final minute = rng.nextInt(60);
    final pullBack = rng.nextInt(50) + 1;
    final time = DateTime(today.year, today.month, today.day - daysAgo, hour, minute);
    return time.isAfter(now) ? now.subtract(Duration(minutes: pullBack)) : time;
  }

  final users = <AdminUser>[];

  for (var i = 0; i < count; i++) {
    final name = '${_first[i % _first.length]} ${_last[rng.nextInt(_last.length)]}';
    final email =
        '${name.toLowerCase().replaceAll(' ', '.')}${10 + rng.nextInt(89)}@example.com';
    final country = _countries[rng.nextInt(_countries.length)];

    // The funnel, decided up front.
    final onboarded = rng.nextDouble() < 0.92;
    final typed = onboarded && rng.nextDouble() < 0.78;
    final sawPaywall = typed && rng.nextDouble() < 0.55;
    final tried = sawPaywall && rng.nextDouble() < 0.5;
    final subscribes = tried && rng.nextDouble() < 0.65;

    // Subscribers joined earlier: they had time to decide.
    final joinedDaysAgo = subscribes
        ? 8 + rng.nextInt(52)
        : (rng.nextDouble() * rng.nextDouble() * 60).floor();
    final joinedAt = at(joinedDaysAgo);

    final events = <AdminEvent>[
      AdminEvent(time: joinedAt, type: EventType.opened, detail: 'First open'),
    ];

    DateTime after(DateTime t, int maxMinutes) {
      final next = t.add(Duration(minutes: 3 + rng.nextInt(maxMinutes)));
      final fraction = rng.nextDouble();
      if (!next.isAfter(now)) return next;
      // Not in the future: somewhere between then and now, so people who joined
      // today do not all show "seen just now".
      final span = now.difference(t).inSeconds;
      return t.add(Duration(seconds: (span * fraction).floor()));
    }

    var cursor = joinedAt;
    if (onboarded) {
      cursor = after(cursor, 8);
      events.add(AdminEvent(time: cursor, type: EventType.onboardingDone));
    }

    var wishCount = 0;
    if (typed) {
      wishCount = 1 + rng.nextInt(4);
      for (var w = 0; w < wishCount; w++) {
        cursor = after(cursor, 60 * 24 * (w == 0 ? 1 : 6));
        events.add(AdminEvent(
          time: cursor,
          type: EventType.wishTyped,
          detail: _wishes[rng.nextInt(_wishes.length)],
        ));
      }
    }

    final paywallViews = sawPaywall ? 1 + rng.nextInt(3) : 0;
    for (var p = 0; p < paywallViews; p++) {
      cursor = after(cursor, 60 * 6);
      events.add(AdminEvent(
        time: cursor,
        type: EventType.paywallView,
        detail: 'Saw the 7-day trial and both plans',
      ));
    }

    final attempts = tried ? 1 + rng.nextInt(2) : 0;
    for (var a = 0; a < attempts; a++) {
      cursor = after(cursor, 60 * 3);
      events.add(AdminEvent(
        time: cursor,
        type: EventType.paymentAttempt,
        detail: 'Opened Google Play checkout',
      ));
    }

    // The plan, the payments, and whether they stayed.
    var plan = AdminPlan.none;
    DateTime? subscribedAt;
    final payments = <AdminPayment>[];
    if (subscribes) {
      subscribedAt = after(cursor, 30);
      cursor = subscribedAt;
      final yearly = rng.nextDouble() < 0.3;
      final price = yearly ? AdminConfig.yearlyPrice : AdminConfig.monthlyPrice;
      final label = yearly ? 'Yearly' : 'Monthly';
      events.add(AdminEvent(
        time: subscribedAt,
        type: EventType.subscribed,
        detail: '$label plan · \$${price.toStringAsFixed(2)}',
      ));

      DateTime? endedAt;
      if (!yearly) {
        final months = now.difference(subscribedAt).inDays ~/ 30;
        if (months >= 1 && rng.nextDouble() < 0.55) {
          endedAt = subscribedAt.add(Duration(days: 30 * (1 + rng.nextInt(months))));
        }
      }

      for (var k = 0;; k++) {
        final due = subscribedAt.add(Duration(days: 30 * k));
        if (due.isAfter(now) || (endedAt != null && !due.isBefore(endedAt))) break;
        payments.add(AdminPayment(time: due, amount: price));
        if (k > 0) {
          events.add(AdminEvent(
            time: due,
            type: EventType.payment,
            detail: 'Monthly renewal · \$${price.toStringAsFixed(2)}',
          ));
        }
        if (yearly) break;
      }
      plan = endedAt != null
          ? AdminPlan.none
          : (yearly ? AdminPlan.yearly : AdminPlan.monthly);
    }

    // Day-to-day use: subscribers come back far more often than free users.
    final lastDay = joinedDaysAgo;
    final comeBack = subscribes ? 0.5 : (onboarded ? 0.07 : 0.03);
    for (var back = lastDay - 1; back >= 0; back--) {
      if (rng.nextDouble() < comeBack) {
        events.add(AdminEvent(time: at(back), type: EventType.opened, detail: 'Session'));
      }
      // Manifestations need a plan; affirmations are free.
      if (subscribedAt != null &&
          at(back).isAfter(subscribedAt) &&
          rng.nextDouble() < 0.28 &&
          (plan != AdminPlan.none || back > 3)) {
        events.add(AdminEvent(
          time: at(back),
          type: EventType.manifestationMade,
          detail: _wishes[rng.nextInt(_wishes.length)],
        ));
      }
      if (onboarded && rng.nextDouble() < 0.05) {
        events.add(AdminEvent(
          time: at(back),
          type: EventType.affirmationsMade,
          detail: 'Five new lines',
        ));
      }
    }

    events.sort((a, b) => b.time.compareTo(a.time));

    users.add(AdminUser(
      id: 'mock_$i',
      name: name,
      email: email,
      country: country,
      joinedAt: joinedAt,
      lastSeen: events.first.time,
      onboardingComplete: onboarded,
      typedWish: typed,
      paywallViews: paywallViews,
      paymentAttempts: attempts,
      plan: plan,
      subscribedAt: subscribedAt,
      payments: payments,
      events: events,
      streak: _streak(events, today),
      everSubscribed: subscribes,
    ));
  }
  return users;
}

/// Days in a row, ending today or yesterday, with at least one open.
int _streak(List<AdminEvent> events, DateTime today) {
  final days = {
    for (final e in events)
      if (e.type == EventType.opened) DateTime(e.time.year, e.time.month, e.time.day),
  };
  var day = days.contains(today) ? today : today.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
