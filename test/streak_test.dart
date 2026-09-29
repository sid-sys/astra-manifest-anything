import 'package:astra/models/intention.dart';
import 'package:astra/models/manifestation.dart';
import 'package:astra/models/story.dart';
import 'package:astra/providers.dart';
import 'package:astra/services/astra_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The streak, the week strip, and days practised this month.
///
/// All three counted only stories. That was right while a story was the
/// product and silently wrong the day manifestations replaced it: somebody who
/// wrote one every morning for a week saw a streak of zero and an empty week.
/// The practice was working and the app said it was not.
Manifestation _made(DateTime when) => Manifestation(
  id: when.toIso8601String(),
  dream: 'I want a place of my own',
  script: '…',
  duration: const Duration(minutes: 4),
  createdAt: when,
);

Story _story(DateTime when) => Story(
  id: 'story_${when.toIso8601String()}',
  title: 'An older one',
  intention: Intention.peace,
  script: '…',
  duration: const Duration(minutes: 4),
  voice: 'elevenlabs',
  createdAt: when,
);

Future<ProviderContainer> _container({
  List<Manifestation> made = const [],
  List<Story> stories = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // Saved rather than overridden: the notifier loads from the repository when
  // it is built, so an override would be replaced by the first read.
  await AstraRepository(prefs).saveStories(stories);

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      manifestationsProvider.overrideWith((ref) async => made),
    ],
  );
  addTearDown(container.dispose);
  await container.read(manifestationsProvider.future);
  return container;
}

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int days) => today.subtract(Duration(days: days));

  test('manifestations count towards the streak', () async {
    final container = await _container(
      made: [_made(today), _made(daysAgo(1)), _made(daysAgo(2))],
    );

    expect(container.read(streakProvider), 3);
  });

  test('a manifestation and a story on the same day count once', () async {
    final container = await _container(
      made: [_made(today)],
      stories: [_story(today)],
    );

    expect(container.read(streakProvider), 1);
  });

  test('the two kinds join into one run', () async {
    // Written on a manifestation today and yesterday, a story the day before.
    final container = await _container(
      made: [_made(today), _made(daysAgo(1))],
      stories: [_story(daysAgo(2))],
    );

    expect(container.read(streakProvider), 3);
  });

  test('a gap ends the streak', () async {
    final container = await _container(
      made: [_made(today), _made(daysAgo(3))],
    );

    expect(container.read(streakProvider), 1);
  });

  test('nothing written is a streak of zero', () async {
    final container = await _container();
    expect(container.read(streakProvider), 0);
  });

  test('the week strip fills in for manifestations too', () async {
    final container = await _container(made: [_made(today)]);

    final week = container.read(weekActivityProvider);
    expect(week, hasLength(7));
    expect(week[today.weekday - 1], isTrue);
  });

  test('days practised this month counts manifestations', () async {
    final container = await _container(made: [_made(today), _made(today)]);

    // Two on the same day is one day practised.
    expect(container.read(daysPractisedThisMonthProvider), 1);
  });
}
