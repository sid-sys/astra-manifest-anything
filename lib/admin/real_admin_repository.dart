import '../services/admin_service.dart' as svc;
import 'admin_config.dart';
import 'admin_models.dart';
import 'admin_repository.dart';

/// The real people and phones, from the `adminOverview` Cloud Function.
///
/// That function checks, on the server, that the caller is
/// [AdminConfig.adminEmail] signed in with Google, and refuses anybody else.
/// Nothing here is a security check: the data simply does not arrive for anyone
/// else.
///
/// One thing is estimated, and the dashboard says so: **payments**. Google Play
/// does not hand over receipts, so each subscriber's payments are worked out
/// from their plan, when it started and when it ended, at the store prices in
/// [AdminConfig], with the first charge after the free trial.
class RealAdminRepository implements AdminRepository {
  RealAdminRepository({svc.AdminService? service})
    : _service = service ?? svc.AdminService();

  final svc.AdminService _service;

  @override
  Future<AdminData> load() async =>
      parseAdminData(await _service.rawOverview(), DateTime.now());
}

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? [for (final item in value) if (item is Map) Map<String, dynamic>.from(item)]
    : const [];

/// Turns the function's answer into the panel's models. Public for tests.
AdminData parseAdminData(Map<String, dynamic> raw, DateTime now) {
  final devices = [
    for (final d in _maps(raw['devices']))
      AdminDevice(
        id: d['id'] as String? ?? '',
        ownerUid: d['ownerUid'] as String?,
        installedAt: _time(d['installedAt']),
        uninstalledAt: _time(d['uninstalledAt']),
        lastSeenAt: _time(d['lastSeenAt']),
      ),
  ];

  final users = [
    for (final u in _maps(raw['users']))
      _user(u, devices.where((d) => d.ownerUid == u['uid']).toList(), now),
  ];
  return AdminData(users: users, devices: devices);
}

AdminUser _user(Map<String, dynamic> u, List<AdminDevice> phones, DateTime now) {
  final id = u['uid'] as String? ?? '';
  final joined = _time(u['signedUpAt']) ?? now;
  final steps = <String, DateTime>{
    for (final e in ((u['steps'] as Map?) ?? const {}).entries)
      if (_time(e.value) != null) e.key.toString(): _time(e.value)!,
  };

  final active = u['subscribed'] == true;
  final planName = u['planId'] as String? ?? u['plan'] as String?;
  final planOfRecord = switch (planName) {
    'yearly' => AdminPlan.yearly,
    'monthly' => AdminPlan.monthly,
    _ => AdminPlan.none,
  };
  final plan = active
      ? (planOfRecord == AdminPlan.none ? AdminPlan.monthly : planOfRecord)
      : AdminPlan.none;
  final subscribedAt = _time(u['subscribedAt']);
  final expiry = _time(u['expiryTime']);
  final everSubscribed = active || (subscribedAt != null && planOfRecord != AdminPlan.none);

  final wishes = _maps(u['wishes']);
  final typed = _maps(u['typed']);
  final typedCount = (u['typedCount'] as num?)?.toInt() ?? 0;

  final installs = [for (final p in phones) if (p.installedAt != null) p.installedAt!]
    ..sort();
  final gone = [for (final p in phones) if (p.uninstalledAt != null) p.uninstalledAt!]
    ..sort();

  final events = <AdminEvent>[
    for (final e in _maps(u['recent']))
      if (_time(e['at']) != null)
        AdminEvent(
          time: _time(e['at'])!,
          type: e['e'] as String? ?? '',
          detail: e['d'] as String? ?? '',
        ),
  ]..sort((a, b) => b.time.compareTo(a.time));

  final timezone = u['timezone'] as String?;
  final billing = u['billing'] is Map ? Map<String, dynamic>.from(u['billing'] as Map) : null;

  return AdminUser(
    id: id,
    name: (u['name'] as String?)?.trim() ?? '',
    email: (u['email'] as String?)?.trim() ?? '',
    country: timezone == null || timezone.isEmpty
        ? 'Unknown'
        : timezone.split('/').last.replaceAll('_', ' '),
    joinedAt: joined,
    lastSeen: _time(u['lastSeenAt']) ?? joined,
    isGuest: u['isGuest'] == true,
    plan: plan,
    everSubscribed: everSubscribed,
    subscribedAt: subscribedAt,
    expiryTime: expiry,
    testPurchase: u['testPurchase'] == true,
    onboardingSeconds: (u['onboardingSeconds'] as num?)?.toInt(),
    onboardingComplete: u['onboardingDone'] == true ||
        steps.containsKey('onboarding_done') ||
        typedCount > 0 ||
        active,
    heardFrom: u['heardFrom'] as String? ?? '',
    answers: Map<String, Object?>.from((u['answers'] as Map?) ?? const {}),
    steps: steps,
    openDays: {
      for (final d in (u['openDays'] as List?) ?? const []) d.toString(),
    },
    events: events,
    paymentsReal: billing != null,
    payFailures: [
      for (final f in _maps(billing?['failures']))
        if (_time(f['at']) != null)
          PayFailure(
            time: _time(f['at'])!,
            kind: 'failed',
            detail: f['kind'] == 'on_hold'
                ? 'Google could not charge the card (on hold)'
                : 'Google could not charge the card (grace period)',
          ),
      for (final f in _maps(u['payFailures']))
        if (_time(f['at']) != null)
          PayFailure(
            time: _time(f['at'])!,
            kind: f['kind'] as String? ?? 'failed',
            detail: f['detail'] as String? ?? '',
          ),
    ],
    paywallViews: (u['paywallViews'] as num?)?.toInt() ?? 0,
    paymentAttempts: (u['subscribeTaps'] as num?)?.toInt() ?? 0,
    typedWish: typedCount > 0 || wishes.isNotEmpty || steps.containsKey('wish_typed'),
    // Google's own record when it has reported on this account; the guess
    // only for people it has not.
    payments: billing != null
        ? [
            for (final p in _maps(billing['payments']))
              if (_time(p['at']) != null)
                AdminPayment(
                  time: _time(p['at'])!,
                  amount: (p['amount'] as num?)?.toDouble() ?? 0,
                ),
          ]
        : estimatePayments(
            plan: planOfRecord,
            start: subscribedAt,
            expiry: expiry,
            active: active,
            now: now,
          ),
    manifestations: [
      for (final w in wishes)
        if (_time(w['createdAt']) != null) _time(w['createdAt'])!,
    ],
    affirmationSets: [
      for (final t in typed)
        if (t['made'] == 'affirmations' && _time(t['at']) != null) _time(t['at'])!,
    ],
    installedAt: installs.isEmpty ? null : installs.first,
    uninstalledAt: gone.isEmpty ? null : gone.last,
  );
}

/// The payments a plan would have made, at the store prices, the first one
/// after the free trial. A subscription that ended is charged only up to its
/// end date. Estimates: the store's own receipts are not stored.
List<AdminPayment> estimatePayments({
  required AdminPlan plan,
  required DateTime? start,
  required DateTime? expiry,
  required bool active,
  required DateTime now,
}) {
  if (start == null || plan == AdminPlan.none) return const [];

  final firstCharge = start.add(Duration(days: AdminConfig.trialDays));
  final until = active ? now : (expiry ?? start);
  if (firstCharge.isAfter(until)) return const [];

  if (plan == AdminPlan.yearly) {
    return [AdminPayment(time: firstCharge, amount: AdminConfig.yearlyPrice)];
  }
  return [
    for (var k = 0; !firstCharge.add(Duration(days: 30 * k)).isAfter(until); k++)
      AdminPayment(
        time: firstCharge.add(Duration(days: 30 * k)),
        amount: AdminConfig.monthlyPrice,
      ),
  ];
}
