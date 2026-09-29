import 'package:astra/providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// The entitlement document decides whether somebody is paying, and the only
/// field in it with any nuance is the expiry.
///
/// This exists because reading it used to be `data['expiryTime'] as String?`,
/// which is right for every document the server writes and wrong for every
/// document a person writes. Firestore returns a date typed in the Console as
/// a [Timestamp], the cast threw *inside* the entitlement stream's `map`, and
/// the stream's own error handler swallowed it — so a document that plainly
/// read `isSubscribed: true` produced a user who was not subscribed, with
/// nothing anywhere naming the cause. That is the worst shape a bug can have:
/// the data looks right, the screen disagrees, and the log is empty.
void main() {
  final when = DateTime.utc(2026, 9, 30, 12);

  test('the shape the server writes', () {
    // `verifyPurchase` stores Play's own ISO 8601 text verbatim. Everything
    // else here is a fallback; this is the path that runs in production.
    expect(entitlementExpiry(when.toIso8601String()), when);
  });

  test('a date typed by hand, which arrives as a Timestamp', () {
    // Granting an entitlement by hand is how the trial gets tested before a
    // real purchase exists, so this is not an exotic case — it is the case
    // that happens every time somebody checks the paywall works.
    //
    // Compared as an instant rather than as a value: `Timestamp.toDate` hands
    // back local time, and the only thing the caller does with this is
    // `isAfter(DateTime.now())`, which is zone-agnostic.
    expect(entitlementExpiry(Timestamp.fromDate(when))!.toUtc(), when);
  });

  test('epoch milliseconds', () {
    expect(
      entitlementExpiry(when.millisecondsSinceEpoch)!.toUtc(),
      when,
    );
  });

  test('nothing readable is treated as no expiry, not as expired', () {
    // Lenient on purpose, and it matters that it is lenient in the *same*
    // direction as the server: `new Date("nonsense")` there is NaN, and a NaN
    // comparison is false, so that end reads an unparseable date as
    // not-expired too. Two ends disagreeing about a junk date would mean the
    // app showing Plus while the server refused to write, or the reverse.
    expect(entitlementExpiry('nonsense'), isNull);
    expect(entitlementExpiry(null), isNull);
    expect(entitlementExpiry(const {}), isNull);
  });
}
