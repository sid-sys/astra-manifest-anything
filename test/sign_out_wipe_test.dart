import 'package:astra/models/story_preferences.dart';
import 'package:astra/models/user_profile.dart';
import 'package:astra/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signing out has to leave nothing behind, and this is the test that says so.
///
/// The bug it exists for was quiet and bad. Log out ended the session and then
/// wiped the device — in that order, through the `WidgetRef` of the screen the
/// user had pressed Log out on. Ending the session rebuilds the app and
/// destroys that screen, so the wipe was reaching for a ref that no longer
/// existed and never ran. It threw into nothing and reported success.
///
/// What it produced: sign out of one account, sign in as another, and the new
/// person landed past onboarding wearing the previous user's name and answers,
/// straight on the paywall, having been asked nothing. The accounts themselves
/// were clean — the server had no profile for the new one at all — every trace
/// was local.
///
/// So the wipe now takes a [ProviderContainer], which `ProviderScope` owns and
/// which outlives every screen beneath it.
void main() {
  test('it empties the profile, and the stored copy with it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(profileProvider.notifier).update(
      UserProfile.empty().copyWith(
        name: 'Mia',
        aspiration: 'I want to buy an iPhone',
        preferences: StoryPreferences.empty.copyWith(
          desire: 'I want to buy an iPhone',
        ),
      ),
    );

    expect(container.read(profileProvider).isOnboarded, isTrue);
    expect(container.read(repositoryProvider).loadProfile(), isNotNull);

    await forgetEverythingLocal(container);

    // In memory.
    expect(container.read(profileProvider).name, isEmpty);

    // And on disk — the half that actually mattered. `isOnboarded` is read from
    // the stored profile on the next launch, and it is the single fact that
    // decides whether a new account is asked the twelve questions or sent
    // straight to the paywall as somebody else.
    expect(container.read(repositoryProvider).loadProfile(), isNull);
    expect(container.read(profileProvider).isOnboarded, isFalse);
  });
}
