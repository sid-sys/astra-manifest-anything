import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_filter.dart';
import 'admin_models.dart';
import 'admin_stats.dart';
import 'real_admin_repository.dart';

/// Where the admin panel's data comes from.
///
/// The screens read only from this, so the source can change in
/// [adminRepositoryProvider] and nowhere else.
abstract class AdminRepository {
  Future<AdminData> load();
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => RealAdminRepository(),
);

/// Everybody and every phone, unfiltered. Refresh with `ref.invalidate`.
final adminDataProvider = FutureProvider.autoDispose<AdminData>(
  (ref) => ref.watch(adminRepositoryProvider).load(),
);

/// The "Real users only" switch. On by default.
final realUsersOnlyProvider = StateProvider<bool>((ref) => true);

/// What the screens show: the people to count, the accounts left out and why,
/// and the numbers worked out from the people to count.
class AdminView {
  const AdminView({
    required this.all,
    required this.shown,
    required this.hidden,
    required this.stats,
    required this.realOnly,
  });

  /// Every account, whatever the switch says.
  final List<AdminUser> all;

  /// The accounts the numbers and lists use now.
  final List<AdminUser> shown;
  final List<HiddenAccount> hidden;
  final AdminStats stats;
  final bool realOnly;
}

final adminViewProvider = Provider.autoDispose<AsyncValue<AdminView>>((ref) {
  final realOnly = ref.watch(realUsersOnlyProvider);
  return ref.watch(adminDataProvider).whenData((data) {
    final split = splitUsers(data.users);
    final shown = realOnly ? split.visible : data.users;
    return AdminView(
      all: data.users,
      shown: shown,
      hidden: split.hidden,
      stats: computeAdminStats(shown, data.devices, DateTime.now()),
      realOnly: realOnly,
    );
  });
});
