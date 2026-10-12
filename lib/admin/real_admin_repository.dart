import '../services/admin_service.dart' as svc;
import 'admin_config.dart';
import 'admin_models.dart';
import 'admin_repository.dart';

/// The real users, from the `adminOverview` Cloud Function.
///
/// That function checks, on the server, that the caller is [AdminConfig.adminEmail]
/// signed in with Google, and refuses anybody else. Nothing here is a security
/// check: the panel's data simply does not arrive for anyone else.
///
/// Some things the server does not record yet, and are filled in honestly:
/// - **Payments** are *estimated* from the plan and its start date, at the
///   store prices in [AdminConfig]. Real receipts live in Google Play.
/// - **Events** are rebuilt from what is stored (wishes typed, things made,
///   subscription start). The server keeps counts, not a timeline; a per-user
///   `events` collection is the next step.
class RealAdminRepository implements AdminRepository {
  RealAdminRepository({svc.AdminService? service})
    : _service = service ?? svc.AdminService();

  final svc.AdminService _service;

  @override
  Future<List<AdminUser>> loadUsers() async {
    final overview = await _service.overview();
    final now = DateTime.now();
    return overview.users.map((user) => _map(user, now)).toList();
  }

  AdminUser _map(svc.AdminUser user, DateTime now) {
    final joined = user.signedUpAt ?? now;
    final lastSeen = user.lastSeenAt ?? joined;

    final plan = switch (user.plan) {
      'yearly' => AdminPlan.yearly,
      'monthly' => AdminPlan.monthly,
      // A subscriber the server did not label: assume monthly, the common one.
      _ when user.subscribed => AdminPlan.monthly,
      _ => AdminPlan.none,
    };
    final subscribedAt = user.subscribedAt ?? (user.subscribed ? lastSeen : null);

    final events = <AdminEvent>[
      AdminEvent(time: joined, type: EventType.opened, detail: 'Joined'),
      for (final wish in user.typed)
        if (wish.at != null) ...[
          AdminEvent(time: wish.at!, type: EventType.wishTyped, detail: wish.wish),
          if (wish.made != null)
            AdminEvent(
              time: wish.at!,
              type: wish.made == 'affirmations'
                  ? EventType.affirmationsMade
                  : EventType.manifestationMade,
              detail: wish.wish,
            ),
        ],
      if (subscribedAt != null && plan != AdminPlan.none)
        AdminEvent(
          time: subscribedAt,
          type: EventType.subscribed,
          detail: '${plan.name} plan (from the store entitlement)',
        ),
      if (lastSeen != joined)
        AdminEvent(time: lastSeen, type: EventType.opened, detail: 'Last seen'),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return AdminUser(
      id: user.uid,
      name: user.name ?? (user.email ?? 'Unknown').split('@').first,
      email: user.email ?? '—',
      country: _place(user.timezone),
      joinedAt: joined,
      lastSeen: lastSeen,
      onboardingComplete:
          user.onboardingDone || user.typedCount > 0 || user.subscribed,
      typedWish: user.typedCount > 0 || user.wishes.isNotEmpty,
      paywallViews: user.paywallViews,
      paymentAttempts: user.subscribeTaps,
      plan: plan,
      subscribedAt: subscribedAt,
      payments: _estimatePayments(plan, subscribedAt, now),
      events: events,
      streak: 0,
      everSubscribed: user.subscribed,
    );
  }

  /// The payments a plan would have made by now, at the store prices.
  List<AdminPayment> _estimatePayments(
    AdminPlan plan,
    DateTime? start,
    DateTime now,
  ) {
    if (start == null || plan == AdminPlan.none) return const [];
    if (plan == AdminPlan.yearly) {
      return [AdminPayment(time: start, amount: AdminConfig.yearlyPrice)];
    }
    return [
      for (var k = 0; !start.add(Duration(days: 30 * k)).isAfter(now); k++)
        AdminPayment(
          time: start.add(Duration(days: 30 * k)),
          amount: AdminConfig.monthlyPrice,
        ),
    ];
  }

  /// "Asia/Kolkata" becomes "Kolkata": the nearest thing to a place the app
  /// records.
  String _place(String? timezone) {
    if (timezone == null || timezone.isEmpty) return 'Unknown';
    return timezone.split('/').last.replaceAll('_', ' ');
  }
}
