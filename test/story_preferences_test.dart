import 'package:astra/models/intention.dart';
import 'package:astra/models/story_preferences.dart';
import 'package:astra/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// The answers onboarding collects are asked once and used forever, so the
/// thing worth testing is that they survive being written down — a preference
/// that silently resets to its default is a story that quietly stops sounding
/// like the person who asked for it.
void main() {
  test('every answer survives a round trip through storage', () {
    const preferences = StoryPreferences(
      category: DesireCategory.love,
      desire: 'Abhirami and I are close, and it feels easy',
      timeframe: Timeframe.threeMonths,
      place: StoryPlace.cafe,
      placeDetail: 'Kochi',
      cast: {StoryCast.someone},
      personName: 'Abhirami',
      feelings: {Feeling.loved, Feeling.peaceful},
      futureShape: FutureShape.oneThing,
      style: StoryStyle.romantic,
      realism: Realism.memory,
      extras: 'She calls me by my full name when she is teasing',
      authenticity: Authenticity.conversations,
    );

    final restored = StoryPreferences.fromMap(preferences.toMap());

    expect(restored.category, DesireCategory.love);
    expect(restored.desire, preferences.desire);
    expect(restored.timeframe, Timeframe.threeMonths);
    expect(restored.place, StoryPlace.cafe);
    expect(restored.placeDetail, 'Kochi');
    expect(restored.cast, {StoryCast.someone});
    expect(restored.personName, 'Abhirami');
    expect(restored.feelings, {Feeling.loved, Feeling.peaceful});
    expect(restored.futureShape, FutureShape.oneThing);
    expect(restored.style, StoryStyle.romantic);
    expect(restored.realism, Realism.memory);
    expect(restored.extras, preferences.extras);
    expect(restored.authenticity, Authenticity.conversations);
  });

  test('a profile written before onboarding asked still reads', () {
    // Every stored profile from before these questions existed has no
    // `preferences` key at all. It has to open, not throw — the alternative is
    // an app that loses every existing user's account on update.
    final legacy = UserProfile.fromMap({
      'name': 'Sana',
      'intentions': ['career'],
      'aspiration': 'I lead my own studio',
      'joinedAt': DateTime(2026).toIso8601String(),
    });

    expect(legacy.name, 'Sana');
    expect(legacy.preferences.desire, isEmpty);
    // The old field still carries the sentence, which is why the brief falls
    // back to it rather than treating an empty `preferences.desire` as "no
    // desire".
    expect(legacy.aspiration, 'I lead my own studio');
  });

  test('every category belongs to a life area the rest of the app knows', () {
    // Ten categories over six intentions. The mapping is what lets onboarding
    // ask in the user's words while the library filter, the affirmations and
    // the daily card keep working off one axis.
    for (final category in DesireCategory.values) {
      expect(Intention.values, contains(category.intention));
    }
  });

  test('preferences travel with the profile', () {
    final profile = UserProfile.empty().copyWith(
      name: 'Sana',
      preferences: const StoryPreferences(
        desire: 'I run five kilometres without stopping',
        category: DesireCategory.health,
      ),
    );

    final restored = UserProfile.fromMap(profile.toMap());

    expect(restored.preferences.desire, 'I run five kilometres without stopping');
    expect(restored.preferences.category, DesireCategory.health);
  });
}
