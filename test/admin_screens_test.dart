import 'package:astra/admin/admin_models.dart';
import 'package:astra/admin/admin_repository.dart';
import 'package:astra/admin/dashboard_screen.dart';
import 'package:astra/admin/mock_admin_repository.dart';
import 'package:astra/admin/user_detail_screen.dart';
import 'package:astra/admin/users_screen.dart';
import 'package:astra/providers.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements AdminRepository {
  @override
  Future<List<AdminUser>> loadUsers() async =>
      generateMockUsers(now: DateTime.now());
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
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
}

void main() {
  // The smallest phone the panel has to fit: no overflow stripe, nothing cut.
  for (final width in [320.0, 360.0]) {
    testWidgets('the dashboard fits a ${width.toInt()}px phone', (tester) async {
      await _pump(tester, const AdminDashboardScreen(), width: width);
      expect(find.text('Total users'), findsOneWidget);
      expect(find.text('MOCK DATA'), findsOneWidget);
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
      final user = generateMockUsers(now: DateTime.now()).firstWhere((u) => u.subscribed);
      await _pump(tester, AdminUserDetailScreen(user: user), width: width);
      expect(find.text('Journey'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
