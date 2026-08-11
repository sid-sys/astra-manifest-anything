import 'package:astra/models/intention.dart';
import 'package:astra/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// The affirmation is written and sent by a server, and the only thing the app
/// contributes is an address and a clock. Both travel in the profile document,
/// so these are the fields that decide whether anyone's notification arrives —
/// and one of them has to be erasable, which `copyWith` normally makes hard.
void main() {
  UserProfile signedUp() => UserProfile(
    name: 'Meera',
    intentions: const {Intention.love},
    aspiration: '',
    voice: 'marin',
    joinedAt: DateTime(2026),
  );

  test('a push registration survives a round trip through storage', () {
    final profile = signedUp().copyWith(
      remindersOn: true,
      reminderHour: 7,
      reminderMinute: 30,
      fcmToken: 'token-from-the-device',
      timezone: 'Asia/Kolkata',
    );

    final restored = UserProfile.fromMap(profile.toMap());

    expect(restored.remindersOn, isTrue);
    expect(restored.reminderHour, 7);
    expect(restored.reminderMinute, 30);
    expect(restored.fcmToken, 'token-from-the-device');
    // An IANA name, not an offset. Stored as an offset it would be wrong twice
    // a year for everyone who observes daylight saving.
    expect(restored.timezone, 'Asia/Kolkata');
  });

  test('turning reminders off erases the push address', () {
    final subscribed = signedUp().copyWith(
      remindersOn: true,
      fcmToken: 'token-from-the-device',
      timezone: 'Asia/Kolkata',
    );

    final off = subscribed.copyWith(remindersOn: false, clearPush: true);

    // Not merely absent from the app's memory: absent from what gets mirrored,
    // so the sender stops finding an address it is still entitled to use.
    expect(off.fcmToken, isNull);
    expect(off.timezone, isNull);
    expect(off.toMap()['fcmToken'], isNull);
  });

  test('an ordinary edit keeps the push address it was not asked about', () {
    final subscribed = signedUp().copyWith(
      remindersOn: true,
      fcmToken: 'token-from-the-device',
      timezone: 'Asia/Kolkata',
    );

    final renamed = subscribed.copyWith(name: 'Meera R');

    expect(renamed.fcmToken, 'token-from-the-device');
    expect(renamed.timezone, 'Asia/Kolkata');
  });
}
