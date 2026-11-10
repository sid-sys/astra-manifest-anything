import 'package:astra/admin/admin_config.dart';
import 'package:astra/admin/admin_filter.dart';
import 'package:astra/admin/admin_models.dart';
import 'package:astra/admin/admin_stats.dart';
import 'package:astra/admin/real_admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_data.dart';

void main() {
  group('who is hidden from the numbers', () {
    test('my own account', () {
      expect(hiddenReason(makeUser(email: AdminConfig.adminEmail)), 'Your own account');
      expect(
        hiddenReason(makeUser(email: AdminConfig.adminEmail.toUpperCase())),
        'Your own account',
      );
    });

    test('the Play review login', () {
      expect(
        hiddenReason(makeUser(email: AdminConfig.reviewEmails.first)),
        'Play review login',
      );
    });

    test('Google test robots, by domain', () {
      expect(
        hiddenReason(makeUser(email: 'mlaz5tk5-lvl-01@cloudtestlabaccounts.com')),
        'Google test robot',
      );
    });

    test('a robot sign-up named after the review login', () {
      expect(
        hiddenReason(
          makeUser(name: AdminConfig.reviewEmails.first, email: 'someone@gmail.com'),
        ),
        'Play review robot',
      );
    });

    test('an automated-looking address', () {
      expect(hiddenReason(makeUser(email: 'testuser12345@gmail.com')), 'Automated test');
    });

    test('a Google robot address: name.12345@gmail.com', () {
      expect(hiddenReason(makeUser(email: 'maria.48213@gmail.com')), 'Automated test');
    });

    test('real gmail addresses are not caught by the robot shape', () {
      for (final email in ['maria.4821@gmail.com', 'maria.482133@gmail.com', 'maria.smith@gmail.com', 'maria1.48213@gmail.com', 'maria.48213@gmail.co']) {
        expect(hiddenReason(makeUser(email: email)), isNull, reason: email);
      }
    });

    test('a licence tester purchase', () {
      expect(
        hiddenReason(makeUser(email: 'sana@gmail.com', testPurchase: true)),
        'Test purchase',
      );
    });

    test('onboarding finished faster than anyone can read', () {
      expect(
        hiddenReason(makeUser(email: 'sana@gmail.com', onboardingSeconds: 9)),
        'Looks like a robot',
      );
    });

    test('real people are never hidden', () {
      expect(hiddenReason(makeUser(email: 'sana@gmail.com', onboardingSeconds: 60)), isNull);
      // Exactly the limit is fine; and no timing at all (an older account) too.
      expect(
        hiddenReason(
          makeUser(
            email: 'sana@gmail.com',
            onboardingSeconds: AdminConfig.minOnboardingSeconds,
          ),
        ),
        isNull,
      );
      expect(hiddenReason(makeUser(email: 'sana@gmail.com')), isNull);
      expect(hiddenReason(makeUser(isGuest: true)), isNull);
    });

    test('splitUsers keeps the reason with the account', () {
      final split = splitUsers([
        makeUser(id: 'a', email: 'sana@gmail.com'),
        makeUser(id: 'b', email: AdminConfig.adminEmail),
      ]);
      expect(split.visible.map((u) => u.id), ['a']);
      expect(split.hidden.single.reason, 'Your own account');
    });
  });

  group('how a person is named', () {
    test('real name first, then email, then Guest plus six characters', () {
      expect(makeUser(name: 'Sana Mehta', email: 'sana@gmail.com').displayName, 'Sana Mehta');
      expect(makeUser(email: 'sana@gmail.com').displayName, 'sana@gmail.com');
      expect(makeUser(id: '3f9a2cdeadbeef', isGuest: true).displayName, 'Guest 3f9a2c');
      expect(makeUser().displayName, 'No name');
    });

    test('never an invented or numbered name', () {
      for (final user in [makeUser(), makeUser(isGuest: true), makeUser(name: '  ')]) {
        expect(user.displayName, isNot(matches(RegExp(r'^(User|Person) ?\d+$'))));
      }
    });

    test('initials come from the real name or email', () {
      expect(makeUser(name: 'Sana Mehta').initials, 'SM');
      expect(makeUser(email: 'dev.khan@gmail.com').initials, 'DK');
    });
  });

  group('installs and uninstalls', () {
    final now = DateTime.utc(2026, 10, 20, 12);
    final sana = makeUser(id: 'sana1', name: 'Sana Mehta', email: 'sana@gmail.com');
    final dev = makeUser(id: 'dev1', name: 'Dev Khan', email: 'dev@gmail.com');
    final me = makeUser(id: 'me1', email: AdminConfig.adminEmail);

    final devices = [
      AdminDevice(
        id: 'p1',
        ownerUid: 'sana1',
        installedAt: DateTime.utc(2026, 10, 18, 9, 30),
        uninstalledAt: null,
        lastSeenAt: now,
      ),
      AdminDevice(
        id: 'p2',
        ownerUid: 'dev1',
        installedAt: DateTime.utc(2026, 10, 18, 22, 10),
        uninstalledAt: DateTime.utc(2026, 10, 19, 4, 0),
        lastSeenAt: now,
      ),
      AdminDevice(
        id: 'p3',
        ownerUid: 'me1',
        installedAt: DateTime.utc(2026, 10, 18, 10),
        uninstalledAt: null,
        lastSeenAt: now,
      ),
    ];

    DayStats day(AdminStats s, int d) =>
        s.days.firstWhere((x) => x.day == DateTime.utc(2026, 10, d));

    test('a phone counts on its install day, and its owner is shown', () {
      final stats = computeAdminStats([sana, dev], devices, now);
      final d18 = day(stats, 18);
      expect(d18.installed.map((e) => e.user.displayName), ['Sana Mehta', 'Dev Khan']);
      expect(d18.installed.first.time, DateTime.utc(2026, 10, 18, 9, 30));
      expect(d18.uninstalled, isEmpty);
    });

    test('an uninstall counts on the day Google said so', () {
      final stats = computeAdminStats([sana, dev], devices, now);
      final d19 = day(stats, 19);
      expect(d19.uninstalled.map((e) => e.user.displayName), ['Dev Khan']);
      expect(d19.installed, isEmpty);
      expect(d19.net, -1);
      expect(day(stats, 18).net, 2);
      expect(day(stats, 20).net, 0);
    });

    test('hiding an account hides its phones too', () {
      final all = computeAdminStats([sana, dev, me], devices, now);
      final real = computeAdminStats([sana, dev], devices, now);
      expect(day(all, 18).installed.length, 3);
      expect(day(real, 18).installed.length, 2);
      expect(real.installedPhones, 2);
    });

    test('a day nobody installed on is empty, not invented', () {
      final stats = computeAdminStats([sana, dev], devices, now);
      expect(day(stats, 15).installed, isEmpty);
      expect(day(stats, 15).uninstalled, isEmpty);
    });
  });

  group('the numbers', () {
    final now = DateTime.utc(2026, 10, 20, 12);

    test('active users come from the days the app was opened', () {
      final a = makeUser(id: 'a', email: 'a@gmail.com', openDays: {'2026-10-20', '2026-10-19'});
      final b = makeUser(id: 'b', email: 'b@gmail.com', openDays: {'2026-10-19'});
      final stats = computeAdminStats([a, b], const [], now);
      expect(stats.activeToday.map((u) => u.id), ['a']);
      expect(stats.days.last.active.length, 1);
      expect(stats.days[stats.days.length - 2].active.length, 2);
      expect(stats.activeThisWeek, 2);
    });

    test('a test purchase is never money', () {
      final real = makeUser(
        id: 'r',
        email: 'r@gmail.com',
        plan: AdminPlan.monthly,
        payments: [AdminPayment(time: now.subtract(const Duration(days: 2)), amount: 7.99)],
      );
      final tester = makeUser(
        id: 't',
        email: 't@gmail.com',
        plan: AdminPlan.monthly,
        testPurchase: true,
        payments: [AdminPayment(time: now.subtract(const Duration(days: 2)), amount: 7.99)],
      );
      final stats = computeAdminStats([real, tester], const [], now);
      expect(stats.revenue30, closeTo(7.99, 0.001));
      expect(stats.paidLast30.map((u) => u.id), ['r']);
      expect(stats.subscribedUsers.map((u) => u.id), ['r']);
    });

    test('profit is revenue minus costs, and the costs are written out', () {
      final stats = computeAdminStats(const [], const [], now);
      expect(stats.costs30, closeTo(AdminConfig.fixedMonthlyTotal, 0.001));
      expect(stats.profitBeforeCut, closeTo(-AdminConfig.fixedMonthlyTotal, 0.001));
    });

    test('the funnel counts this app\'s own steps, in order', () {
      final users = [
        makeUser(id: 'a', email: 'a@gmail.com', onboarded: false),
        makeUser(
          id: 'b',
          email: 'b@gmail.com',
          typed: true,
          paywall: 1,
          attempts: 1,
          ever: true,
        ),
        makeUser(id: 'c', email: 'c@gmail.com', typed: true, paywall: 2),
      ];
      final stats = computeAdminStats(users, const [], now);
      final f = {for (final s in stats.funnel) s.label: s.count};
      expect(f['Opened the app'], 3);
      expect(f['Finished onboarding'], 2);
      expect(f[AdminConfig.keyStepLabel], 2);
      expect(f['Saw the paywall'], 2);
      expect(f['Tried to pay'], 1);
      expect(f['Subscribed'], 1);
      final counts = stats.funnel.skip(1).map((s) => s.count).toList();
      expect(counts.first, greaterThanOrEqualTo(counts.last));
    });

    test('why paying did not happen, and where people heard about us', () {
      final a = makeUser(
        id: 'a',
        email: 'a@gmail.com',
        heardFrom: 'instagram',
        failures: [PayFailure(time: now, kind: 'cancelled', detail: '')],
      );
      final b = makeUser(
        id: 'b',
        email: 'b@gmail.com',
        heardFrom: 'instagram',
        failures: [PayFailure(time: now, kind: 'unavailable', detail: '_BillingUnavailable')],
      );
      final c = makeUser(id: 'c', email: 'c@gmail.com');
      final stats = computeAdminStats([a, b, c], const [], now);

      expect(stats.failures.length, 2);
      expect(stats.failures.every((f) => f.people.length == 1), isTrue);
      expect(stats.sources.first.label, 'Instagram');
      expect(stats.sources.first.count, 2);
      expect(stats.sources.map((s) => s.label), contains('Not asked yet'));
    });
  });

  group('payments are estimated after the free trial', () {
    final now = DateTime.utc(2026, 10, 20);

    test('nothing is charged during the trial', () {
      final payments = estimatePayments(
        plan: AdminPlan.monthly,
        start: now.subtract(const Duration(days: 3)),
        expiry: null,
        active: true,
        now: now,
      );
      expect(payments, isEmpty);
    });

    test('monthly charges every 30 days from the end of the trial', () {
      final payments = estimatePayments(
        plan: AdminPlan.monthly,
        start: now.subtract(const Duration(days: 45)),
        expiry: null,
        active: true,
        now: now,
      );
      // First charge at day 7, next at day 37.
      expect(payments.length, 2);
      expect(payments.first.amount, AdminConfig.monthlyPrice);
    });

    test('yearly charges once, and an ended plan stops at its end date', () {
      final yearly = estimatePayments(
        plan: AdminPlan.yearly,
        start: now.subtract(const Duration(days: 100)),
        expiry: null,
        active: true,
        now: now,
      );
      expect(yearly.single.amount, AdminConfig.yearlyPrice);

      final ended = estimatePayments(
        plan: AdminPlan.monthly,
        start: now.subtract(const Duration(days: 100)),
        expiry: now.subtract(const Duration(days: 50)),
        active: false,
        now: now,
      );
      // Charges at days 7 and 37 of the 50 before the end; none after.
      expect(ended.length, 2);
      expect(ended.every((p) => p.time.isBefore(now.subtract(const Duration(days: 50)))), isTrue);
    });
  });

  group('reading the server answer', () {
    test('money from Google replaces the guess, and a pending charge is not money', () {
      Map<String, dynamic> person(String id, Map<String, dynamic>? billing) => {
        'uid': id,
        'signedUpAt': '2026-10-26T07:00:00.000Z',
        'subscribed': true,
        'planId': 'monthly',
        'subscribedAt': '2026-10-26T07:34:00.000Z',
        'billing': billing,
      };
      final data = parseAdminData({
        'users': [
          // Google has reported, and no charge went through yet.
          person('pending1', {'payments': [], 'failures': []}),
          // Google has reported one real charge, and one failed collection.
          person('paid0001', {
            'payments': [
              {'at': '2026-11-02T07:34:00.000Z', 'amount': 7.99, 'orderId': 'GPA.1..0'},
            ],
            'failures': [
              {'at': '2026-11-03T07:34:00.000Z', 'kind': 'on_hold'},
            ],
          }),
          // Google has not reported: the guess is used.
          person('unknown1', null),
        ],
        'devices': [],
      }, DateTime.utc(2026, 11, 10));

      final byId = {for (final u in data.users) u.id: u};
      expect(byId['pending1']!.paymentsReal, isTrue);
      expect(byId['pending1']!.payments, isEmpty);
      expect(byId['paid0001']!.paidTotal, 7.99);
      expect(byId['paid0001']!.payFailures.single.detail, contains('on hold'));
      expect(byId['unknown1']!.paymentsReal, isFalse);
      expect(byId['unknown1']!.payments, isNotEmpty);
    });

    test('a cancel shows in the events and the journey flag', () {
      Map<String, dynamic> person(String id, {Map<String, dynamic>? billing, String? state}) => {
        'uid': id,
        'signedUpAt': '2026-10-26T07:00:00.000Z',
        'subscribed': true,
        'planId': 'monthly',
        'subscribedAt': '2026-10-26T07:34:00.000Z',
        'entitlementState': state,
        'billing': billing,
      };
      final data = parseAdminData({
        'users': [
          person('said0001', billing: {
            'payments': [],
            'events': [
              {'at': '2026-10-27T10:00:00.000Z', 'type': 'CANCELED'},
            ],
          }),
          person('came0001', billing: {
            'payments': [],
            'events': [
              {'at': '2026-10-27T10:00:00.000Z', 'type': 'CANCELED'},
              {'at': '2026-10-28T10:00:00.000Z', 'type': 'RESTARTED'},
            ],
          }),
          // Cancelled before the notifications existed: only Play's state tells.
          person('old00001', state: 'SUBSCRIPTION_STATE_CANCELED'),
          person('fine0001', state: 'SUBSCRIPTION_STATE_ACTIVE'),
        ],
        'devices': [],
      }, DateTime.utc(2026, 11, 10));
      final byId = {for (final u in data.users) u.id: u};

      expect(byId['said0001']!.cancelled, isTrue);
      expect(byId['said0001']!.cancelledAt, DateTime.utc(2026, 10, 27, 10));
      expect(byId['said0001']!.events.any((e) => e.type == 'sub_canceled'), isTrue);
      expect(byId['came0001']!.cancelled, isFalse);
      expect(byId['old00001']!.cancelled, isTrue);
      expect(byId['old00001']!.cancelledAt, isNull);
      expect(byId['fine0001']!.cancelled, isFalse);
    });

    test('turns the overview JSON into people and phones', () {
      final data = parseAdminData({
        'users': [
          {
            'uid': 'u1abcdef',
            'email': 'sana@gmail.com',
            'name': 'Sana Mehta',
            'signedUpAt': '2026-10-01T10:00:00.000Z',
            'lastSeenAt': '2026-10-19T10:00:00.000Z',
            'subscribed': true,
            'planId': 'yearly',
            'subscribedAt': '2026-10-02T10:00:00.000Z',
            'testPurchase': false,
            'onboardingDone': true,
            'onboardingSeconds': 71,
            'heardFrom': 'tiktok',
            'isGuest': false,
            'timezone': 'Asia/Kolkata',
            'steps': {'app_open': '2026-10-01T10:00:00.000Z', 'wish_typed': '2026-10-01T10:05:00.000Z'},
            'openDays': ['2026-10-18', '2026-10-19'],
            'recent': [
              {'at': '2026-10-19T10:00:00.000Z', 'e': 'app_open', 'd': ''},
              {'at': '2026-10-19T10:03:00.000Z', 'e': 'wish_typed', 'd': 'a home of my own'},
            ],
            'payFailures': [
              {'at': '2026-10-02T09:00:00.000Z', 'kind': 'cancelled', 'detail': ''},
            ],
            'wishes': [
              {'dream': 'a home', 'createdAt': '2026-10-19T10:04:00.000Z'},
            ],
            'typed': [
              {'wish': 'calm', 'at': '2026-10-18T10:00:00.000Z', 'made': 'affirmations'},
            ],
          },
        ],
        'devices': [
          {
            'id': 'phone1',
            'ownerUid': 'u1abcdef',
            'installedAt': '2026-10-01T09:59:00.000Z',
            'uninstalledAt': null,
            'lastSeenAt': '2026-10-19T10:00:00.000Z',
          },
        ],
      }, DateTime.utc(2026, 10, 20));

      final user = data.users.single;
      expect(user.displayName, 'Sana Mehta');
      expect(user.plan, AdminPlan.yearly);
      expect(user.country, 'Kolkata');
      expect(user.openDays, {'2026-10-18', '2026-10-19'});
      expect(user.events.first.type, 'wish_typed'); // newest first
      expect(user.steps['wish_typed'], DateTime.utc(2026, 10, 1, 10, 5));
      expect(user.payFailures.single.kind, 'cancelled');
      expect(user.manifestations.length, 1);
      expect(user.affirmationSets.length, 1);
      expect(user.installedAt, DateTime.utc(2026, 10, 1, 9, 59));
      expect(user.payments.single.amount, AdminConfig.yearlyPrice);
      expect(data.devices.single.ownerUid, 'u1abcdef');
    });

    test('an account with nothing recorded still reads, with no invented name', () {
      final data = parseAdminData({
        'users': [
          {'uid': '3f9a2cdeadbeef', 'isGuest': true},
        ],
      }, DateTime.utc(2026, 10, 20));
      final user = data.users.single;
      expect(user.displayName, 'Guest 3f9a2c');
      expect(user.plan, AdminPlan.none);
      expect(user.events, isEmpty);
      expect(user.payments, isEmpty);
    });
  });
}
