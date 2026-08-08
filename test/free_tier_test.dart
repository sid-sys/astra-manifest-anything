import 'package:astra/models/intention.dart';
import 'package:astra/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Who may write a story without paying.
///
/// Three tiers stacked on each other — one free story, then a free day, then a
/// subscription — and every one of them is a decision about money. The rule
/// used to be `isSubscribed || trialActive` with `trialActive` returning true
/// whenever the clock had never started, which meant a user who never opened
/// the paywall had an unlimited free tier forever. That is the class of bug
/// this file exists to catch.
UserProfile _profile({
  bool subscribed = false,
  Duration? trialStartedAgo,
}) => UserProfile(
  name: 'Sana',
  intentions: const {Intention.love},
  aspiration: '',
  voice: 'marin',
  joinedAt: DateTime.now(),
  isSubscribed: subscribed,
  trialStartedAt: trialStartedAgo == null
      ? null
      : DateTime.now().subtract(trialStartedAgo),
);

void main() {
  group('the first story is free for everyone', () {
    test('a brand new user may write one', () {
      expect(_profile().canGenerate(storiesWritten: 0), isTrue);
    });

    test('and is stopped at the second', () {
      expect(_profile().canGenerate(storiesWritten: 1), isFalse);
    });

    test('without the free day having started', () {
      // The point of the free story is that it costs the user nothing — not
      // even the clock. If writing it started the trial, the day would be
      // half gone before anyone knew they had one.
      expect(_profile().trialStarted, isFalse);
    });
  });

  group('the free day', () {
    test('unlocks writing once started', () {
      final started = _profile(trialStartedAgo: const Duration(hours: 1));
      expect(started.canGenerate(storiesWritten: 1), isTrue);
      expect(started.trialActive, isTrue);
    });

    test('runs out after twenty-four hours', () {
      final spent = _profile(trialStartedAgo: const Duration(hours: 25));
      expect(spent.trialActive, isFalse);
      expect(spent.canGenerate(storiesWritten: 1), isFalse);
    });

    test('is over at exactly twenty-four hours, not a minute after', () {
      expect(
        _profile(trialStartedAgo: const Duration(hours: 24)).trialActive,
        isFalse,
      );
    });

    test('reports what is left of it', () {
      final left = _profile(
        trialStartedAgo: const Duration(hours: 6),
      ).trialRemaining;
      // 18 hours, give or take however many microseconds passed between
      // building the profile and reading it back.
      expect(left, lessThanOrEqualTo(const Duration(hours: 18)));
      expect(left, greaterThan(const Duration(hours: 17, minutes: 59)));
    });

    test('is never started twice', () {
      // trialRemaining on an unstarted profile reports the full day rather
      // than zero, so the paywall can advertise it.
      expect(_profile().trialRemaining, const Duration(hours: 24));
    });
  });

  group('a subscriber', () {
    test('is never stopped by the free tiers', () {
      final plus = _profile(subscribed: true);
      expect(plus.canGenerate(storiesWritten: 0), isTrue);
      expect(plus.canGenerate(storiesWritten: 500), isTrue);
    });

    test('does not need a trial to have been started', () {
      expect(_profile(subscribed: true).trialStarted, isFalse);
      expect(_profile(subscribed: true).canGenerate(storiesWritten: 3), isTrue);
    });
  });
}
