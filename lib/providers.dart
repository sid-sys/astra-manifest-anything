import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/affirmation_taste.dart';
import 'models/intention.dart';
import 'models/plan.dart';
import 'models/story.dart';
import 'models/user_profile.dart';
import 'services/account_service.dart';
import 'services/affirmations.dart';
import 'services/auth_service.dart';
import 'services/astra_repository.dart';
import 'services/playback_controller.dart';
import 'services/region_service.dart';
import 'services/story_service.dart';

/// Overridden in `main` once the platform is ready.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider needs an override'),
);

/// False when Firebase could not start — no network at launch, a misconfigured
/// build. The app then has no accounts at all and runs on local storage, so
/// there is nothing to show a sign-in screen for. Overridden in `main`.
final firebaseReadyProvider = Provider<bool>((ref) => false);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Who is signed in, as a stream, so every screen reacts to a sign-out at once
/// rather than each holding its own stale copy.
final authStateProvider = StreamProvider<User?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return Stream.value(null);
  return ref.watch(authServiceProvider).authState();
});

/// Whether the current account is a guest. Used to decide whether to offer the
/// upgrade prompt, never to withhold a feature — a guest is a full user.
final isGuestProvider = Provider<bool>(
  (ref) =>
      ref.watch(authStateProvider).valueOrNull?.isAnonymous ??
      false,
);

final repositoryProvider = Provider<AstraRepository>(
  (ref) => AstraRepository(ref.watch(sharedPreferencesProvider)),
);

final storyServiceProvider = Provider<StoryService>(
  (ref) => StoryService(repository: ref.watch(repositoryProvider)),
);

final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(ref.watch(repositoryProvider)),
);

/// Drops every trace of the current user from memory and disk.
///
/// The app decides what to show from `profile.isOnboarded`, so emptying the
/// profile is also the navigation: the tree rebuilds on the onboarding screen
/// without anyone pushing a route. Each notifier is reset explicitly rather
/// than by invalidating the providers, because a rebuilt notifier would read
/// the same storage it is being asked to forget.
Future<void> forgetEverythingLocal(WidgetRef ref) async {
  await ref.read(repositoryProvider).clearLocal();
  ref.read(storiesProvider.notifier).forget();
  ref.read(tasteProvider.notifier).forget();
  ref.read(avatarProvider.notifier).forget();
  // Profile last: it is what the app routes on, so nothing rebuilds against a
  // half-cleared library.
  ref.read(profileProvider.notifier).forget();
}

/// Runs a generation end to end.
///
/// Home and Create both make stories and both have to do the same three things
/// afterwards — store it, start the trial clock, keep the library in sync. This
/// exists so neither screen owns that sequence privately and they cannot drift.
class StoryComposer {
  StoryComposer(this._ref);

  final Ref _ref;

  /// Writes the script and stores it. Returns before any audio exists, so the
  /// story can be on screen in about twenty seconds instead of a hundred.
  Future<Story> compose({
    required Intention intention,
    required String scene,
  }) async {
    final story = await _ref
        .read(storyServiceProvider)
        .write(
          profile: _ref.read(profileProvider),
          intention: intention,
          scene: scene,
        );

    await _ref.read(storiesProvider.notifier).add(story);
    await _ref.read(profileProvider.notifier).noteTrialStarted();
    return story;
  }

  /// Records the narration and attaches it to the stored story.
  ///
  /// Runs after [compose] while the user is already reading. A failure here
  /// leaves a perfectly readable story behind, which is why it is logged
  /// rather than thrown — there is nothing for the reader to do about it.
  Future<void> narrate(Story story) async {
    try {
      final withAudio = await _ref.read(storyServiceProvider).narrate(story);
      if (withAudio.audioUrl == null) return;

      await _ref.read(storiesProvider.notifier).update(withAudio);
      _ref.read(playbackProvider).adoptAudio(withAudio);
    } catch (error) {
      debugPrint('Astra: narration failed, story stays readable — $error');
    }
  }
}

final storyComposerProvider = Provider<StoryComposer>(StoryComposer.new);

// ------------------------------------------------------------------ profile

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier(this._repository)
    : super(_repository.loadProfile() ?? UserProfile.empty());

  final AstraRepository _repository;

  Future<void> update(UserProfile profile) async {
    state = profile;
    await _repository.saveProfile(profile);
  }

  /// Starts the free-day clock locally on the first successful generation.
  ///
  /// The server stamps its own copy and is the one that counts; this only keeps
  /// the on-screen copy honest between launches.
  Future<void> noteTrialStarted() async {
    if (state.trialStartedAt != null) return;
    await update(state.copyWith(trialStartedAt: DateTime.now()));
  }

  /// Backdates the clock so the UI stops offering a trial the server has
  /// already refused. Called when generation comes back resource-exhausted.
  Future<void> noteTrialOver() => update(
    state.copyWith(
      trialStartedAt: DateTime.now().subtract(const Duration(hours: 24)),
    ),
  );

  Future<void> subscribe() => update(state.copyWith(isSubscribed: true));

  /// Records that the subscription screen has been offered, so it is shown
  /// once after onboarding and never ambushes the user again.
  Future<void> markPaywallSeen() => update(state.copyWith(paywallSeen: true));

  /// Empties the profile without writing it back. Storage is cleared by the
  /// caller; saving here would re-create the record being erased.
  void forget() => state = UserProfile.empty();
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

  Future<void> toggleFavorite(Story story) =>
      update(story.copyWith(favorite: !story.favorite));

  /// Empties the library in memory. Storage is cleared by the caller.
  void forget() => state = const [];
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

// ------------------------------------------------------------------- avatar

/// The profile photo, decoded once and held in memory.
///
/// Stored as base64 on disk and as bytes here so the home screen can paint it
/// without decoding on every build. Null means no photo has been chosen, which
/// is the normal state — the avatar falls back to the user's initial.
class AvatarNotifier extends StateNotifier<Uint8List?> {
  AvatarNotifier(this._repository) : super(_decode(_repository.loadAvatar()));

  final AstraRepository _repository;

  static Uint8List? _decode(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (error) {
      debugPrint('Astra: stored avatar could not be decoded — $error');
      return null;
    }
  }

  Future<void> set(Uint8List? bytes) async {
    state = bytes;
    await _repository.saveAvatar(bytes == null ? null : base64Encode(bytes));
  }

  /// Drops the photo from memory. Storage is cleared by the caller.
  void forget() => state = null;
}

final avatarProvider = StateNotifierProvider<AvatarNotifier, Uint8List?>(
  (ref) => AvatarNotifier(ref.watch(repositoryProvider)),
);

// -------------------------------------------------------------------- taste

/// What the user has kept and thrown away in the affirmation deck.
class TasteNotifier extends StateNotifier<AffirmationTaste> {
  TasteNotifier(this._repository) : super(_repository.loadTaste());

  final AstraRepository _repository;

  Future<void> like(String line) => _save(state.like(line));
  Future<void> pass(String line) => _save(state.pass(line));
  Future<void> unlike(String line) => _save(state.unlike(line));

  /// Puts every passed line back in the deck. The liked ones stay liked —
  /// starting over should not cost the user the answers they meant.
  Future<void> reshuffle() =>
      _save(AffirmationTaste(liked: state.liked, passed: const {}));

  Future<void> _save(AffirmationTaste next) async {
    state = next;
    await _repository.saveTaste(next);
  }

  /// Forgets every keep and pass in memory. Storage is cleared by the caller.
  void forget() => state = const AffirmationTaste();
}

final tasteProvider = StateNotifierProvider<TasteNotifier, AffirmationTaste>(
  (ref) => TasteNotifier(ref.watch(repositoryProvider)),
);

/// The cards still waiting to be swiped, best first.
final affirmationDeckProvider = Provider<List<Affirmation>>((ref) {
  final intentions = ref.watch(
    profileProvider.select((profile) => profile.intentions),
  );
  return Affirmations.deck(intentions, ref.watch(tasteProvider));
});

/// Stories the user has hearted.
final favouriteStoriesProvider = Provider<List<Story>>(
  (ref) => ref.watch(storiesProvider).where((story) => story.favorite).toList(),
);

// ------------------------------------------------------------------- region

/// Region is resolved from the device locale alone — there is nothing to
/// configure, so nothing to rebuild on.
final regionServiceProvider = Provider<RegionService>((ref) => RegionService());

final plansProvider = Provider<List<Plan>>(
  (ref) => ref.watch(regionServiceProvider).plans,
);

// ----------------------------------------------------------------- playback

final playbackProvider = ChangeNotifierProvider<PlaybackController>(
  (ref) => PlaybackController(),
);

// ------------------------------------------------------------------ streaks

/// Consecutive days ending today with at least one story made.
final streakProvider = Provider<int>((ref) {
  final days = <DateTime>{
    for (final story in ref.watch(storiesProvider)) _dayOf(story.createdAt),
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
  };
  return days
      .where((d) => d.year == now.year && d.month == now.month)
      .length;
});

/// Monday to Sunday of the current week: true where a story was made.
///
/// Days still ahead read as false and the UI draws them as empty rather than
/// missed — a week that starts by showing four failures is a discouraging way
/// to open an app about how things are already going well.
final weekActivityProvider = Provider<List<bool>>((ref) {
  final days = <DateTime>{
    for (final story in ref.watch(storiesProvider)) _dayOf(story.createdAt),
  };

  final today = _dayOf(DateTime.now());
  final monday = today.subtract(Duration(days: today.weekday - 1));

  return [
    for (var i = 0; i < 7; i++) days.contains(monday.add(Duration(days: i))),
  ];
});

final minutesListenedProvider = Provider<int>((ref) {
  final total = ref
      .watch(storiesProvider)
      .fold<int>(0, (sum, story) => sum + story.duration.inMinutes);
  return total;
});

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);
