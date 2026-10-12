import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_models.dart';
import 'admin_stats.dart';
import 'real_admin_repository.dart';

/// Where the admin panel's users come from.
///
/// The screens read only from this, so the source of the users can change in
/// [adminRepositoryProvider] and nowhere else.
abstract class AdminRepository {
  Future<List<AdminUser>> loadUsers();
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => RealAdminRepository(),
);

/// The user list, newest activity first. Refresh with `ref.invalidate`.
final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>((
  ref,
) async {
  final users = await ref.watch(adminRepositoryProvider).loadUsers();
  return [...users]..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
});

final adminStatsProvider = Provider.autoDispose<AsyncValue<AdminStats>>((ref) {
  return ref
      .watch(adminUsersProvider)
      .whenData((users) => computeAdminStats(users, DateTime.now()));
});
