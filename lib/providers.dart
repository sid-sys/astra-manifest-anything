import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/journal_entry.dart';
import 'models/plan.dart';
import 'models/story.dart';
import 'models/user_profile.dart';
import 'services/astra_repository.dart';
import 'services/playback_controller.dart';
import 'services/region_service.dart';
import 'services/story_service.dart';

/// Overridden in `main` once the platform is ready.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider needs an override'),
);

/// Null when anonymous sign-in was unavailable — the app then runs local-only.
final uidProvider = Provider<String?>((ref) => null);

final repositoryProvider = Provider<AstraRepository>(
  (ref) => AstraRepository(
    ref.watch(sharedPreferencesProvider),
    uid: ref.watch(uidProvider),
  ),
);

final storyServiceProvider = Provider<StoryService>(
  (ref) => StoryService(
    repository: ref.watch(repositoryProvider),
    signedIn: ref.watch(uidProvider) != null,
  ),
);

// ------------------------------------------------------------------ profile

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier(this._repository)
    : super(_repository.loadProfile() ?? UserProfile.empty());

  final AstraRepository _repository;

  Future<void> update(UserProfile profile) async {
    state = profile;
    await _repository.saveProfile(profile);
  }

  Future<void> markFreeStoryUsed() =>
      update(state.copyWith(freeStoryUsed: true));

  Future<void> subscribe() => update(state.copyWith(isSubscribed: true));
}

final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile>(
  (ref) => ProfileNotifier(ref.watch(repositoryProvider)),
);

// ------------------------------------------------------------------ stories

class StoriesNotifier extends StateNotifier<List<Story>> {
  StoriesNotifier(this._repository) : super(_repository.loadStories()) {
    unawaited(_restoreFromCloud());
  }

  final AstraRepository _repository;

  /// Pulls in any story Firestore has that this device does not.
  ///
  /// The device copy stays authoritative — nothing here overwrites a local
  /// story — so this only ever adds. It runs after the first frame has already
  /// been built from local state, which is why the library is never blocked on
  /// the network.
  Future<void> _restoreFromCloud() async {
    final cloud = await _repository.fetchCloudStories();
    if (cloud.isEmpty) return;

    final known = state.map((story) => story.id).toSet();
    final missing = cloud.where((story) => !known.contains(story.id)).toList();
    if (missing.isEmpty) return;

    final merged = [...state, ...missing]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    state = merged;
    await _repository.saveStories(merged);
  }

  Future<void> add(Story story) async {
    state = [story, ...state];
    await _repository.addStory(story);
  }

  Future<void> update(Story story) async {
    state = [
      for (final existing in state)
        if (existing.id == story.id) story else existing,
    ];
    await _repository.updateStory(story);
  }

  Future<void> remove(String storyId) async {
    state = state.where((s) => s.id != storyId).toList();
    await _repository.deleteStory(storyId);
  }

  Future<void> toggleDownloaded(Story story) =>
      update(story.copyWith(downloaded: !story.downloaded));
}

final storiesProvider = StateNotifierProvider<StoriesNotifier, List<Story>>(
  (ref) => StoriesNotifier(ref.watch(repositoryProvider)),
);

/// The story surfaced on Home. Newest first, so tonight's generation is
/// tonight's ritual.
final dailyStoryProvider = Provider<Story?>((ref) {
  final stories = ref.watch(storiesProvider);
  return stories.isEmpty ? null : stories.first;
});

// ------------------------------------------------------------------ journal

class JournalNotifier extends StateNotifier<List<JournalEntry>> {
  JournalNotifier(this._repository) : super(_repository.loadJournal());

  final AstraRepository _repository;

  Future<void> add(JournalEntry entry) async {
    state = [entry, ...state];
    await _repository.addJournalEntry(entry);
  }

  Future<void> remove(String entryId) async {
    state = state.where((e) => e.id != entryId).toList();
    await _repository.deleteJournalEntry(entryId);
  }
}

final journalProvider =
    StateNotifierProvider<JournalNotifier, List<JournalEntry>>(
      (ref) => JournalNotifier(ref.watch(repositoryProvider)),
    );

// ------------------------------------------------------------------- region

/// Rebuilds when the user overrides their region in Settings.
final regionServiceProvider = Provider<RegionService>((ref) {
  final override = ref.watch(
    profileProvider.select((profile) => profile.countryOverride),
  );
  return RegionService(overrideCountryCode: override);
});

final plansProvider = Provider<List<Plan>>(
  (ref) => ref.watch(regionServiceProvider).plans,
);

// ----------------------------------------------------------------- playback

final playbackProvider = ChangeNotifierProvider<PlaybackController>(
  (ref) => PlaybackController(),
);

// ------------------------------------------------------------------ streaks

/// Consecutive days ending today that have at least one journal entry or story.
final streakProvider = Provider<int>((ref) {
  final days = <DateTime>{
    for (final story in ref.watch(storiesProvider)) _dayOf(story.createdAt),
    for (final entry in ref.watch(journalProvider)) _dayOf(entry.createdAt),
  };
  if (days.isEmpty) return 0;

  var streak = 0;
  var cursor = _dayOf(DateTime.now());

  // Yesterday still counts as an unbroken streak until today ends.
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;
  }

  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});

/// Distinct days practised in the current calendar month.
final daysPractisedThisMonthProvider = Provider<int>((ref) {
  final now = DateTime.now();
  final days = <DateTime>{
    for (final story in ref.watch(storiesProvider)) _dayOf(story.createdAt),
    for (final entry in ref.watch(journalProvider)) _dayOf(entry.createdAt),
  };
  return days
      .where((d) => d.year == now.year && d.month == now.month)
      .length;
});

final minutesListenedProvider = Provider<int>((ref) {
  final total = ref
      .watch(storiesProvider)
      .fold<int>(0, (sum, story) => sum + story.duration.inMinutes);
  return total;
});

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);
