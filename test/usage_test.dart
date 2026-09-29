import 'package:astra/providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The numbers inside the ring.
///
/// Worth pinning because they are the first thing a user reads about the plan
/// and the easiest thing to get subtly wrong: counting the month against a
/// trial cap, or letting an over-quota month render a ring past full.
void main() {
  test('a fresh free account has its one story ahead of it', () {
    const usage = Usage(used: 0, limit: 1, plan: 'Free', detail: '');
    expect(usage.left, 1);
    expect(usage.fraction, 0);
  });

  test('a spent allowance reads empty rather than negative', () {
    // Server-side refusals and local counts can disagree for a moment — a
    // device that generated while offline, a story restored from the cloud.
    // "-1 left" is never the right thing to print.
    const usage = Usage(used: 4, limit: 2, plan: 'Free day', detail: '');
    expect(usage.left, 0);
    expect(usage.fraction, 1);
  });

  test('a half-used month is half a ring', () {
    const usage = Usage(used: 10, limit: 20, plan: 'Maya Plus', detail: '');
    expect(usage.left, 10);
    expect(usage.fraction, 0.5);
  });

  test('the month starts when the subscription does', () {
    // Subscribing on the 20th after using the free story and the free day
    // used to hand over an allowance that was already three deep. The stories
    // that sold the plan are not stories the plan paid for.
    const usage = Usage(used: 0, limit: 20, plan: 'Maya Plus', detail: '');
    expect(usage.left, 20);
  });

  test('no limit means nothing left to meter', () {
    // The free day is over and no plan has been bought. The ring draws empty
    // rather than full: there is no allowance, not an untouched one.
    const usage = Usage(used: 3, limit: null, plan: 'Free', detail: '');
    expect(usage.left, 0);
    expect(usage.fraction, 1);
  });
}
