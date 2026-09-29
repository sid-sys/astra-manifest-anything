import 'package:astra/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What Maya calls the person.
///
/// Worth pinning, because getting it wrong is not cosmetic: the manifestation
/// opens by saying this name out loud, and with nothing set the server writes
/// "friend" — so the first thing a new user ever hears is a stranger calling
/// them friend. Nothing asked for a name once onboarding was deleted, and the
/// name on a Google account was sitting one field away, unread.
Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a typed name is kept, first word only', () async {
    final container = await _container();
    final profile = container.read(profileProvider.notifier);

    await profile.setName('  Sidharth Babu  ');
    expect(container.read(profileProvider).name, 'Sidharth');
  });

  test('an empty name changes nothing', () async {
    final container = await _container();
    final profile = container.read(profileProvider.notifier);

    await profile.setName('Sana');
    await profile.setName('   ');
    expect(container.read(profileProvider).name, 'Sana');
  });

  test("Google's name is adopted when there is none", () async {
    final container = await _container();
    final profile = container.read(profileProvider.notifier);

    await profile.adoptProviderName('Amaya Krishnan');
    expect(container.read(profileProvider).name, 'Amaya');
  });

  test('a name the user chose survives a Google sign-in', () async {
    final container = await _container();
    final profile = container.read(profileProvider.notifier);

    // The whole reason this is not a plain assignment. Someone who set "Sid"
    // must not be renamed to the legal name on their Google account the next
    // time they sign in with it.
    await profile.setName('Sid');
    await profile.adoptProviderName('Sidharth Babu');
    expect(container.read(profileProvider).name, 'Sid');
  });

  test('no display name at all leaves the profile alone', () async {
    final container = await _container();
    final profile = container.read(profileProvider.notifier);

    await profile.adoptProviderName(null);
    expect(container.read(profileProvider).name, '');
  });
}
