import 'package:astra/admin/admin_config.dart';
import 'package:astra/admin/admin_feedback_screen.dart';
import 'package:astra/admin/admin_models.dart';
import 'package:astra/admin/admin_repository.dart';
import 'package:astra/admin/admin_stats.dart';
import 'package:astra/admin/dashboard_screen.dart';
import 'package:astra/admin/user_detail_screen.dart';
import 'package:astra/admin/users_screen.dart';
import 'package:astra/admin/widgets/admin_widgets.dart';
import 'package:astra/providers.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_data.dart';

/// Real-looking people written out by hand, including the accounts the panel
/// must hide, and phones that were installed and uninstalled today and
/// yesterday.
AdminData _data() {
  final now = DateTime.now().toUtc();
  final today = utcDayKey(now);
  final yesterday = utcDayKey(now.subtract(const Duration(days: 1)));

  final sana = makeUser(
    id: 'sana1',
    name: 'Sana Mehta',
    email: 'sana@gmail.com',
    plan: AdminPlan.monthly,
    ever: true,
    typed: true,
    paywall: 2,
    attempts: 1,
    heardFrom: 'instagram',
    openDays: {today, yesterday},
    onboardingSeconds: 80,
    steps: {'onboarding_done': now.subtract(const Duration(days: 9))},
    payments: [AdminPayment(time: now.subtract(const Duration(days: 3)), amount: 7.99)],
    events: [
      AdminEvent(time: now.subtract(const Duration(hours: 1)), type: 'wish_typed', detail: 'A home of my own'),
      AdminEvent(time: now.subtract(const Duration(days: 1)), type: 'app_open'),
    ],
    installedAt: now.subtract(const Duration(days: 9)),
  );
  final dev = makeUser(
    id: 'dev1',
    name: 'Dev Khan',
    email: 'dev@gmail.com',
    typed: true,
    paywall: 1,
    heardFrom: 'tiktok',
    openDays: {yesterday},
    failures: [PayFailure(time: now, kind: 'cancelled', detail: '')],
    installedAt: now.subtract(const Duration(days: 5)),
  );
  final guest = makeUser(id: 'ab12cd34ef', isGuest: true, onboarded: false);
  final robot = makeUser(id: 'rb1', email: 'x@cloudtestlabaccounts.com', name: 'Nuage Laboratoire');
  final me = makeUser(id: 'me1', email: AdminConfig.adminEmail);

  return AdminData(
    users: [sana, dev, guest, robot, me],
    devices: [
      AdminDevice(id: 'p1', ownerUid: 'sana1', installedAt: now, uninstalledAt: null, lastSeenAt: now),
      AdminDevice(
        id: 'p2',
        ownerUid: 'dev1',
        installedAt: now.subtract(const Duration(days: 1)),
        uninstalledAt: now,
        lastSeenAt: now,
      ),
      AdminDevice(id: 'p3', ownerUid: 'me1', installedAt: now, uninstalledAt: null, lastSeenAt: now),
    ],
  );
}

Future<void> _pump(WidgetTester tester, Widget screen, {double width = 320, double height = 640}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminDataProvider.overrideWith((ref) async => _data()),
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

/// A chart bar by what it says to a screen reader: "3 active on 14 Oct".
Finder _bar(String what, {required bool nonZero}) => find.byWidgetPredicate((w) {
  if (w is! Semantics) return false;
  final label = w.properties.label ?? '';
  // Anchored: "uninstalled on" also contains "installed on".
  if (!RegExp('^\\d+ $what').hasMatch(label)) return false;
  final zero = label.startsWith('0 ');
  return nonZero ? !zero : zero;
});

Future<void> _scrollTo(WidgetTester tester, Finder target) =>
    tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  // The sizes the panel has to fit: a small phone, a normal one, and wide.
  for (final width in [320.0, 360.0, 900.0]) {
    testWidgets('the dashboard fits a ${width.toInt()}px screen', (tester) async {
      await _pump(tester, const AdminDashboardScreen(), width: width);
      expect(find.text('Admin panel'), findsOneWidget);
      expect(find.text('Real users only'), findsOneWidget);
      expect(find.text('Total users'), findsOneWidget);
      expect(find.textContaining('MOCK'), findsNothing);
      for (final heading in [
        'Activity',
        'From installing to subscribing',
        'When paying did not happen',
        'Where people heard about us',
        'Feedback and bug reports',
      ]) {
        await _scrollTo(tester, find.text(heading));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the switch hides test, review and my own accounts everywhere', (tester) async {
    await _pump(tester, const AdminDashboardScreen(), width: 360, height: 900);

    // Five accounts, three of them hidden (robot, me, and the guest is real).
    expect(find.text('Hiding 2 test, review and my own accounts'), findsOneWidget);
    // Real users: Sana, Dev and the guest.
    final totals = tester.widget<Text>(
      find.descendant(
        of: find.widgetWithText(MetricCard, 'Total users'),
        matching: find.byWidgetPredicate((w) => w is Text && w.data == '3'),
      ),
    );
    expect(totals.data, '3');

    // Turn it off: everything shows, and the line says so.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Showing everything, including 2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(MetricCard, 'Total users'),
        matching: find.byWidgetPredicate((w) => w is Text && w.data == '5'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping the hidden line lists them with the reason', (tester) async {
    await _pump(tester, const AdminDashboardScreen(), width: 360, height: 900);
    await tester.tap(find.textContaining('Hiding 2'));
    await tester.pumpAndSettle();

    expect(find.text('Hidden accounts'), findsOneWidget);
    expect(find.text('Hidden: Your own account'), findsOneWidget);
    expect(find.text('Hidden: Google test robot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a bar opens the real people behind it', (tester) async {
    await _pump(tester, const AdminDashboardScreen(), width: 360, height: 2400);

    // Today's bar in the active-users view: Sana opened the app today.
    final bars = _bar('active on', nonZero: true);
    await tester.tap(bars.last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Active on'), findsOneWidget);
    expect(find.text('Sana Mehta'), findsOneWidget);
    expect(find.text('sana@gmail.com'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    // Switch the same card to installs and uninstalls.
    await tester.tap(find.text('Installs and uninstalls'));
    await tester.pumpAndSettle();
    expect(find.text('Net gain'), findsWidgets);

    final installed = _bar('installed on', nonZero: true);
    await tester.tap(installed.last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Installed on'), findsOneWidget);
    expect(find.text('Sana Mehta'), findsOneWidget);
    // The hidden account's phone is not in the real-users list.
    expect(find.text('Your own account'), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    final uninstalled = _bar('uninstalled on', nonZero: true);
    await tester.tap(uninstalled.last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Uninstalled on'), findsOneWidget);
    expect(find.text('Dev Khan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty bar says nobody, in words', (tester) async {
    await _pump(tester, const AdminDashboardScreen(), width: 360, height: 2400);
    final bars = _bar('active on', nonZero: false);
    await tester.tap(bars.last);
    await tester.pumpAndSettle();
    expect(find.text('Nobody was active that day'), findsOneWidget);
  });

  testWidgets('a number card opens its people', (tester) async {
    await _pump(tester, const AdminDashboardScreen(), width: 360, height: 900);
    await tester.tap(find.widgetWithText(MetricCard, 'Subscribed'));
    await tester.pumpAndSettle();
    expect(find.text('Subscribed'), findsWidgets);
    expect(find.text('Sana Mehta'), findsOneWidget);
    expect(find.text('Dev Khan'), findsNothing);
  });

  for (final width in [320.0, 360.0, 900.0]) {
    testWidgets('all users fits a ${width.toInt()}px screen', (tester) async {
      final people = [for (final u in _data().users) PersonEntry(u)];
      await _pump(
        tester,
        AdminUsersScreen(title: 'All users', entries: people, full: true),
        width: width,
        height: 1600,
      );
      expect(find.text('Sana Mehta'), findsOneWidget);
      // A guest is named from the account id, never invented.
      expect(find.text('Guest ab12cd'), findsOneWidget);
      expect(find.text('Guest'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one user fits a ${width.toInt()}px screen', (tester) async {
      await _pump(tester, AdminUserDetailScreen(user: _data().users.first), width: width);
      expect(find.text('Journey'), findsOneWidget);
      await _scrollTo(tester, find.text('What they told us'));
      await _scrollTo(tester, find.text('Activity'));
      expect(find.text('Sana Mehta'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('search finds people by real name or email, and sort chips exist', (tester) async {
    final people = [for (final u in _data().users) PersonEntry(u)];
    await _pump(
      tester,
      AdminUsersScreen(title: 'All users', entries: people, full: true),
      width: 360,
      height: 900,
    );
    for (final chip in ['All', 'Subscribed', 'Free', 'Active today', 'Signed up', 'Last seen', 'Installed', 'Uninstalled']) {
      expect(find.widgetWithText(AdminChip, chip), findsOneWidget, reason: chip);
    }
    await tester.enterText(find.byType(TextField), 'dev@');
    await tester.pumpAndSettle();
    expect(find.text('Dev Khan'), findsOneWidget);
    expect(find.text('Sana Mehta'), findsNothing);

    await tester.tap(find.widgetWithText(AdminChip, 'Subscribed'));
    await tester.pumpAndSettle();
    expect(find.text('Nobody matches.'), findsOneWidget);
  });

  test('feedback items read from the server list', () {
    final item = AdminFeedbackItem.fromMap({
      'id': 'f1',
      'source': 'feedback',
      'uid': 'sana1',
      'kind': 'bug',
      'text': 'The player stops',
      'createdAt': '2026-10-19T10:00:00.000Z',
      'handled': false,
    });
    expect(item.kind, 'bug');
    expect(item.handled, isFalse);
    expect(item.createdAt, DateTime.utc(2026, 10, 19, 10));
  });
}
