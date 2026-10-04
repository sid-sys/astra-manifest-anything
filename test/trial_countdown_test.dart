import 'package:astra/providers.dart';
import 'package:astra/widgets/trial_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

Entitlement _trial(DateTime start) => Entitlement(
  isSubscribed: true,
  expiryTime: null,
  state: null,
  isTestGrant: false,
  everSubscribed: true,
  startedAt: start,
);

void main() {
  test('the countdown runs to the end of the 7 days, not for a fixed time', () {
    // Ten used on day 2: 5 days left.
    final start = DateTime.now().subtract(const Duration(days: 2));
    final left = _trial(start).trialEndsAt!.difference(DateTime.now());
    expect(left.inHours, inInclusiveRange(119, 120));

    // Ten used on day 6: 1 day left.
    final late = DateTime.now().subtract(const Duration(days: 6));
    expect(
      _trial(late).trialEndsAt!.difference(DateTime.now()).inHours,
      inInclusiveRange(23, 24),
    );
  });

  test('there is no countdown once the 7 days are over', () {
    final start = DateTime.now().subtract(const Duration(days: 8));
    expect(_trial(start).trialEndsAt, isNull);
  });

  test('formats as days, hours, minutes and seconds', () {
    expect(
      formatCountdown(const Duration(days: 4, hours: 21, minutes: 22, seconds: 20)),
      '4D:21H:22M:20S',
    );
    expect(formatCountdown(const Duration(days: 5)), '5D:00H:00M:00S');
    expect(formatCountdown(const Duration(seconds: -3)), '0D:00H:00M:00S');
  });
}
