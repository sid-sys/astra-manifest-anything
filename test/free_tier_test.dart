import 'package:astra/models/intention.dart';
import 'package:astra/models/plan.dart';
import 'package:astra/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Who may write a story without paying.
///
/// One rule now: three free stories, ever, then a plan. There is no trial and
/// no clock. The version this replaced had a `trialActive` that returned true
/// whenever the clock had never started, which handed anyone who never opened
/// the paywall an unlimited free tier — the kind of mistake that only shows up
/// on the bill, which is why the rule is pinned here.
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
    test('allows exactly ${PricingCatalog.freeStories} stories', () {
      final free = _profile();
      for (var written = 0; written < PricingCatalog.freeStories; written++) {
        expect(
          free.canGenerate(storiesWritten: written),
          isTrue,
          reason: 'story ${written + 1} should be free',
        );
      }
    });

    test('stops at the next one', () {
      expect(
        _profile().canGenerate(
          storiesWritten: PricingCatalog.freeStories,
        ),
        isFalse,
      );
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
