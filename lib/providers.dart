import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'services/billing_service.dart';
import 'services/astra_repository.dart';
import 'services/notification_service.dart';
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

final repositoryProvider = Provider<AstraRepository>(
  (ref) => AstraRepository(ref.watch(sharedPreferencesProvider)),
);

final storyServiceProvider = Provider<StoryService>(
  (ref) => StoryService(repository: ref.watch(repositoryProvider)),
);

final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(ref.watch(repositoryProvider)),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// Keeps the server's idea of this device in step with the profile.
///
/// The affirmation itself is written and sent by a scheduled Cloud Function;
/// all the app has to do is make sure the function knows where to send it and
/// in what timezone. So this writes a push token and an IANA zone when
/// reminders are on, and erases both when they are off.
///
/// Called on launch and after any change that moves the answer — turning
/// reminders on or off, changing the time, signing in. Cheap enough to call on
/// every launch: it only writes when something actually differs, so the common
/// case is one token read and no network at all.
Future<void> refreshPushRegistration(WidgetRef ref) async {
  final profile = ref.read(profileProvider);
  final notifications = ref.read(notificationServiceProvider);
  final profiles = ref.read(profileProvider.notifier);

  if (!profile.remindersOn) {
    await notifications.unregister();
    if (profile.fcmToken != null) {
      await profiles.update(profile.copyWith(clearPush: true));
    }
    return;
  }

  final registration = await notifications.register();
  if (registration.token == null) return;

  if (registration.token == profile.fcmToken &&
      registration.zone == profile.timezone) {
    return;
  }

  await profiles.update(
    profile.copyWith(fcmToken: registration.token, timezone: registration.zone),
  );
}

final billingServiceProvider = Provider<BillingService>((ref) {
  final billing = BillingService();
  ref.onDispose(billing.dispose);
  return billing;
});

/// Whether this account is on Plus, according to the server.
///
/// Streamed from the entitlement document that only `verifyPurchase` writes.
/// The client cannot write it — Firestore rules deny it — which is the whole
/// point: subscription used to be a boolean on the user's own profile, so
/// anyone able to reach Firestore could grant themselves a plan.
///
/// Defaults to false whenever the answer is unknown: offline, signed out, or
/// mid-load. Free is the safe direction to be wrong in, and the server refuses
/// over-quota generation regardless of what this says.
final entitlementProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(false);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('entitlement')
      .snapshots()
      .map((snap) {
        final data = snap.data();
        if (data == null || data['isSubscribed'] != true) return false;

        final expiry = DateTime.tryParse(data['expiryTime'] as String? ?? '');
        return expiry == null || expiry.isAfter(DateTime.now());
      })
      .handleError((Object error) {
        debugPrint('Astra: entitlement stream failed — $error');
      });
});

/// The one place the app asks "is this user paying?".
final isSubscribedProvider = Provider<bool>(
  (ref) => ref.watch(entitlementProvider).valueOrNull ?? false,
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
/// afterwards — store it and keep the library in sync. This
/// exists so neither screen owns that sequence privately and they cannot drift.
class StoryComposer {
  StoryComposer(this._ref);

  final Ref _ref;

  /// Writes the script and stores it. Returns before any audio exists, so the
  /// story can be on screen in about twenty seconds instead of a hundred.
  /// [profile] overrides the stored one. Onboarding needs that: it generates
  /// its first story before it commits the profile to state, because
  /// committing is what tears its own screen down.
  Future<Story> compose({
    required Intention intention,
    required String scene,
    UserProfile? profile,
  }) async {
    final story = await _ref
        .read(storyServiceProvider)
        .write(
          profile: profile ?? _ref.read(profileProvider),
          intention: intention,
          scene: scene,
        );

    await _ref.read(storiesProvider.notifier).add(story);
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

  // There is no `subscribe()`. Granting Plus was a local write that the app
  // made to its own profile document, which meant the answer to "is this user
  // paying" was a field the user could set. It now lives in a document only
  // `verifyPurchase` writes, from a receipt Google confirmed — see
  // [entitlementProvider]. The `isSubscribed` field on UserProfile survives
  // only so old stored profiles still parse.

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

/// The line on the Home card.
///
/// Prefers whatever was actually pushed to this person's phone this morning,
/// so the card and the notification never disagree — a phone that said one
/// sentence at eight and an app that says another at nine leaves the user with
/// no way to tell which one was theirs.
///
/// Falls back to the curated pool, which is the right answer more often than it
/// sounds: before the first push has ever been sent, when reminders are off
/// entirely, and when generation failed. A generated line that failed to
/// generate should degrade to a real line, not to an empty card.
final dailyAffirmationProvider = Provider<String>((ref) {
  final intentions = ref.watch(
    profileProvider.select((profile) => profile.intentions),
  );
  final curated = Affirmations.forDay(
    DateTime.now(),
    intentions,
    ref.watch(tasteProvider),
  );

  return ref.watch(sentAffirmationProvider).valueOrNull ?? curated;
});

/// The affirmation the server last pushed, straight from the document it wrote.
final sentAffirmationProvider = StreamProvider<String?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('affirmations')
      .snapshots()
      .map((snap) {
        final line = snap.data()?['lastSent'] as String?;
        return (line == null || line.isEmpty) ? null : line;
      })
      .handleError((Object error) {
        debugPrint('Astra: sent affirmation unavailable — $error');
      });
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

// -------------------------------------------------------------------- usage

/// What the user has spent this month, and what they have left.
///
/// This existed nowhere before: the server enforced a quota the app never
/// showed, so the first time anyone learned there was a limit was the moment
/// they hit it. A limit worth enforcing is worth displaying.
class Usage {
  const Usage({
    required this.used,
    required this.limit,
    required this.plan,
    required this.detail,
  });

  /// Stories written against [limit], counted over whatever window that limit
  /// belongs to — the month on Plus, all time on the free tier. Counting a
  /// month against a lifetime cap would report the wrong number every time a
  /// month rolled over.
  final int used;

  /// Null when nothing is left to meter: the free day is over and there is no
  /// allowance to draw a ring around.
  final int? limit;

  /// 'Astra Plus', 'Free day', 'Free'.
  final String plan;

  /// The sentence under the meter, in whatever unit actually binds.
  final String detail;

  int get left => limit == null ? 0 : (limit! - used).clamp(0, limit!);

  double get fraction =>
      limit == null || limit == 0 ? 1 : (used / limit!).clamp(0, 1);
}

final usageProvider = Provider<Usage>((ref) {
  final profile = ref.watch(profileProvider);
  final stories = ref.watch(storiesProvider);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);

  // The server's answer, not the profile's. `profile.isSubscribed` is a local
  // field the app itself writes; this is a document only the purchase
  // verifier can touch.
  if (ref.watch(isSubscribedProvider)) {
    // Count from whichever is later: the start of the month, or the moment
    // they subscribed. Someone who used their free stories and then paid on
    // the same day was being billed a month's allowance for the stories that
    // convinced them to pay.
    final since = profile.subscribedAt == null
        ? monthStart
        : (profile.subscribedAt!.isAfter(monthStart)
              ? profile.subscribedAt!
              : monthStart);
    final onPlan = stories
        .where((story) => !story.createdAt.isBefore(since))
        .length;
    final left = PricingCatalog.plusMonthlyStories - onPlan;
    return Usage(
      used: onPlan,
      limit: PricingCatalog.plusMonthlyStories,
      plan: 'Astra Plus',
      detail: left > 0
          ? '$left left this month · unlimited listening · resets on the 1st'
          : 'Used up this month · your library still replays',
    );
  }

  // The free tier is a lifetime count, not a window: three stories, ever, and
  // then a plan. Nothing expires, so there is no clock to display and no way
  // to be caught out by one.
  final free = PricingCatalog.freeStories;
  final left = free - stories.length;

  return Usage(
    used: stories.length.clamp(0, free),
    limit: free,
    plan: 'Free',
    detail: left > 0
        ? '$left free ${left == 1 ? 'story' : 'stories'} left · Plus writes '
              '${PricingCatalog.plusMonthlyStories} a month'
        : 'Free stories used · Plus writes '
              '${PricingCatalog.plusMonthlyStories} a month, and your library '
              'replays without limit',
  );
});

/// Minutes of audio in the library.
///
/// Named for what it counts. It was called "minutes listened" and shown under
/// that label, while actually summing the length of every story whether or not
/// a second of it had ever been played.
final minutesInLibraryProvider = Provider<int>((ref) {
  final total = ref
      .watch(storiesProvider)
      .fold<int>(0, (total, story) => total + story.duration.inMinutes);
  return total;
});

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);
