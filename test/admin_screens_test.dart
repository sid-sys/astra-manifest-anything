import 'package:astra/admin/admin_models.dart';
import 'package:astra/admin/admin_repository.dart';
import 'package:astra/admin/admin_stats.dart';
import 'package:astra/admin/dashboard_screen.dart';
import 'package:astra/admin/user_detail_screen.dart';
import 'package:astra/admin/users_screen.dart';
import 'package:astra/providers.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A handful of people written out by hand, so the screens can be checked
/// without any generated or made-up data in the app itself.
List<AdminUser> _users(DateTime now) {
  AdminUser user(
    String name, {
    required int joinedDaysAgo,
    bool onboarded = true,
    bool typed = false,
    int paywall = 0,
    int attempts = 0,
    AdminPlan plan = AdminPlan.none,
    bool ever = false,
    List<AdminPayment> payments = const [],
    List<AdminEvent> events = const [],
  }) {
    final joined = now.subtract(Duration(days: joinedDaysAgo));
    final all = [
      AdminEvent(time: joined, type: EventType.opened, detail: 'Joined'),
      ...events,
    ]..sort((a, b) => b.time.compareTo(a.time));
    return AdminUser(
      id: name,
      name: name,
      email: '${name.toLowerCase().replaceAll(' ', '.')}@example.com',
      country: 'Kolkata',
      joinedAt: joined,
      lastSeen: all.first.time,
      onboardingComplete: onboarded,
      typedWish: typed,
      paywallViews: paywall,
      paymentAttempts: attempts,
      plan: plan,
      subscribedAt: ever ? joined : null,
      payments: payments,
      events: all,
      streak: 2,
      everSubscribed: ever,
    );
  }

  return [
    user('Sana Mehta', joinedDaysAgo: 40, typed: true, paywall: 2, attempts: 1,
        plan: AdminPlan.monthly, ever: true,
        payments: [
          AdminPayment(time: now.subtract(const Duration(days: 40)), amount: 7.99),
          AdminPayment(time: now.subtract(const Duration(days: 10)), amount: 7.99),
        ],
        events: [
          AdminEvent(time: now.subtract(const Duration(hours: 2)), type: EventType.manifestationMade, detail: 'A home of my own'),
          AdminEvent(time: now.subtract(const Duration(days: 3)), type: EventType.opened),
        ]),
    user('Dev Khan', joinedDaysAgo: 20, typed: true, paywall: 1, attempts: 2,
        plan: AdminPlan.yearly, ever: true,
        payments: [AdminPayment(time: now.subtract(const Duration(days: 20)), amount: 79.99)]),
    user('Priya Nair', joinedDaysAgo: 5, typed: true, paywall: 1),
    user('Omar Ali', joinedDaysAgo: 2, onboarded: false),
    user('Ava Brown', joinedDaysAgo: 60, typed: true, paywall: 1, attempts: 1, ever: true,
        payments: [AdminPayment(time: now.subtract(const Duration(days: 60)), amount: 7.99)]),
  ];
}

class _Repo implements AdminRepository {
  @override
  Future<List<AdminUser>> loadUsers() async => _users(DateTime.now());
}

Future<void> _pump(WidgetTester tester, Widget screen, {double width = 320}) async {
  tester.view.physicalSize = Size(width, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(_Repo()),
        authStateProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: MaterialApp(theme: buildAstraTheme(), home: screen),
    ),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

void main() {
  final now = DateTime(2026, 10, 12, 15, 30);

  test('the stats add up from the users', () {
    final stats = computeAdminStats(_users(now), now);
    expect(stats.totalUsers, 5);
    expect(stats.subscribed, 2);
    expect(stats.paying, 2);
    expect(stats.revenueTotal, closeTo(7.99 * 3 + 79.99, 0.001));
    expect(stats.funnel.first.count, 5);
    expect(stats.funnel.last.count, 3); // ever subscribed, ended plan included
    expect(stats.dailyActive.length, 14);
    expect(stats.costs30, greaterThanOrEqualTo(0));
  });

  // The smallest phone the panel has to fit: no overflow stripe, nothing cut.
  for (final width in [320.0, 360.0]) {
    testWidgets('the dashboard fits a ${width.toInt()}px phone', (tester) async {
      await _pump(tester, const AdminDashboardScreen(), width: width);
      expect(find.text('Total users'), findsOneWidget);
      expect(find.text('MOCK DATA'), findsNothing);
      // The list is lazy: scroll down so the chart and the funnel are built
      // and measured too.
      await tester.scrollUntilVisible(
        find.text('From joining to subscribing'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.textContaining('See all'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the users list fits a ${width.toInt()}px phone', (tester) async {
      await _pump(tester, const AdminUsersScreen(), width: width);
      expect(find.text('Search name or email'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a user fits a ${width.toInt()}px phone', (tester) async {
      final user = _users(DateTime.now()).firstWhere((u) => u.subscribed);
      await _pump(tester, AdminUserDetailScreen(user: user), width: width);
      expect(find.text('Journey'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
