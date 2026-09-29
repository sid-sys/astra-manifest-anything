import 'package:astra/models/intention.dart';
import 'package:astra/models/plan.dart';
import 'package:astra/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Who may write a story without paying.
///
/// One rule now: nobody. The paywall is hard, the trial belongs to Play, and
/// nothing generates without an entitlement the server verified.
///
/// An earlier version had a `trialActive` that returned true whenever the
/// clock had never started, which handed anyone who never opened the paywall
/// an unlimited free tier — the kind of mistake that only shows up on the
/// bill. That is why this file exists: the trial is now Play's to track, and
/// this app must never grow a second opinion about who is entitled.
UserProfile _profile({bool subscribed = false, DateTime? subscribedAt}) =>
    UserProfile(
      name: 'Sana',
      intentions: const {Intention.love},
      aspiration: '',
      voice: 'marin',
      joinedAt: DateTime.now(),
      isSubscribed: subscribed,
      subscribedAt: subscribedAt,
    );

void main() {
  group('the free tier', () {
    test('does not exist — the paywall is hard', () {
      expect(PricingCatalog.freeStories, 0);
    });

    test('refuses the very first story to anyone unsubscribed', () {
      // The whole point of the hard paywall, pinned. If this ever passes at
      // zero stories written, someone has reintroduced a free tier by
      // accident and the trial is being given away twice.
      expect(_profile().canGenerate(storiesWritten: 0), isFalse);
    });

    test('stays stopped however many are written', () {
      expect(_profile().canGenerate(storiesWritten: 99), isFalse);
    });
  });

  group('a subscriber', () {
    test('is never stopped by the free count', () {
      final plus = _profile(subscribed: true, subscribedAt: DateTime.now());
      expect(plus.canGenerate(storiesWritten: 0), isTrue);
      expect(plus.canGenerate(storiesWritten: 500), isTrue);
    });

    test('records when the plan started', () {
      // The monthly allowance counts from this date rather than from the first
      // of the month, so the free stories that sold the plan are not billed to
      // it.
      final at = DateTime(2026, 8, 20);
      expect(_profile(subscribed: true, subscribedAt: at).subscribedAt, at);
    });
  });
}
