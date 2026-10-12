import 'package:astra/admin/admin_config.dart';
import 'package:astra/admin/admin_models.dart';
import 'package:astra/admin/admin_stats.dart';
import 'package:astra/admin/mock_admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 12, 15, 30);

  test('the mock data is the same on every run', () {
    final a = generateMockUsers(now: now);
    final b = generateMockUsers(now: now);
    expect(a.length, 50);
    expect(
      a.map((u) => '${u.name}${u.events.length}${u.paidTotal}').toList(),
      b.map((u) => '${u.name}${u.events.length}${u.paidTotal}').toList(),
    );
    // The time of day must not change who the people are.
    final earlier = generateMockUsers(now: DateTime(2026, 10, 12, 4, 10));
    expect(earlier.map((u) => u.name), a.map((u) => u.name));
    expect(earlier.where((u) => u.subscribed).length, a.where((u) => u.subscribed).length);
  });

  test('the funnel follows the rules the dashboard is checked against', () {
    final stats = computeAdminStats(generateMockUsers(now: now), now);
    final f = {for (final s in stats.funnel) s.label: s.count};

    expect(f['Joined'], 50);
    expect(f['Finished onboarding'], inInclusiveRange(42, 50)); // about 92%
    // Each step is a smaller share of the one before.
    final counts = stats.funnel.map((s) => s.count).toList();
    for (var i = 1; i < counts.length; i++) {
      expect(counts[i], lessThanOrEqualTo(counts[i - 1]));
    }
    expect(f['Subscribed'], greaterThan(0));
    expect(f['Subscribed']!, lessThanOrEqualTo(f['Tried to pay']!));
  });

  test('payments use the real store prices', () {
    final users = generateMockUsers(now: now);
    final prices = {AdminConfig.monthlyPrice, AdminConfig.yearlyPrice};
    for (final user in users) {
      for (final payment in user.payments) {
        expect(prices, contains(payment.amount));
      }
    }
    expect(AdminConfig.monthlyPrice, 7.99);
    expect(AdminConfig.yearlyPrice, 79.99);
  });

  test('subscribers use the app more, and some of them leave', () {
    final users = generateMockUsers(now: now);
    double opens(Iterable<AdminUser> group) => group.isEmpty
        ? 0
        : group
                  .map((u) => u.events.where((e) => e.type == EventType.opened).length)
                  .reduce((a, b) => a + b) /
            group.length;
    expect(
      opens(users.where((u) => u.subscribed)),
      greaterThan(opens(users.where((u) => !u.everSubscribed))),
    );
    expect(users.where((u) => u.churned), isNotEmpty);
  });

  test('stats add up', () {
    final users = generateMockUsers(now: now);
    final stats = computeAdminStats(users, now);
    expect(stats.totalUsers, 50);
    expect(stats.dailyActive.length, 14);
    expect(stats.subscribed, users.where((u) => u.subscribed).length);
    expect(stats.revenueTotal, closeTo(users.fold(0.0, (s, u) => s + u.paidTotal), 0.001));
    expect(stats.revenue30, lessThanOrEqualTo(stats.revenueTotal));
    expect(stats.costs30, greaterThanOrEqualTo(AdminConfig.fixedMonthlyTotal));
    // Newest first inside every user.
    for (final user in users) {
      for (var i = 1; i < user.events.length; i++) {
        expect(user.events[i - 1].time.isBefore(user.events[i].time), isFalse);
      }
    }
  });
}
