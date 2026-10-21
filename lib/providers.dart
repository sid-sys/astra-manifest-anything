import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_build.dart';
import 'models/affirmation_set.dart';
import 'models/affirmation_taste.dart';
import 'models/intention.dart';
import 'models/manifestation.dart';
import 'models/plan.dart';
import 'models/story.dart';
import 'models/story_preferences.dart';
import 'models/user_profile.dart';
import 'services/account_service.dart';
import 'services/admin_service.dart';
import 'services/affirmation_service.dart';
import 'services/affirmations.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/device_service.dart';
import 'services/feedback_service.dart';
import 'services/manifest_service.dart';
import 'services/astra_repository.dart';
import 'services/notification_service.dart';
import 'services/plan_service.dart';
import 'services/playback_controller.dart';
import 'services/region_service.dart';
import 'services/tracking_service.dart';
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
/// upgrade prompt and to warn before a one-way sign-out — never to withhold a
/// feature. A guest is a full user.
final isGuestProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.isAnonymous ?? false,
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

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();

  // Tapping one of our announcements tells the server it was read.
  //
  // Wired here rather than inside the service so that class keeps knowing
  // nothing about Cloud Functions. Fire and forget: a report that fails is a
  // number slightly low in the admin panel, which is not worth showing the
  // user an error about, and never worth blocking the screen they tapped
  // through to.
  service.onBroadcastOpened = (broadcastId) {
    unawaited(
      FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('markBroadcastOpened')
          .call<Map<Object?, Object?>>({'broadcastId': broadcastId})
          .catchError((Object error) {
            debugPrint('Mayow: could not report a broadcast open — $error');
            throw error;
          }),
    );
  };

  return service;
});

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
    // Daily reminders are off, but the "your trial ends tomorrow" notice may
    // not be: deleting the device token would silence that one too.
    if (profile.trialPushToken == null) await notifications.unregister();
    if (profile.fcmToken != null) {
      await profiles.update(profile.copyWith(clearPush: true));
    }
    await enableTrialNotice(ref, ask: false);
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

/// Lets the server warn this person the day before their free trial ends.
///
/// That notice is the one that tells somebody how to cancel before they are
/// charged, so it has its own push address on the profile, separate from the
/// daily reminders: switching reminders off must not switch this off.
///
/// With [ask] the system permission dialog is shown if needed; without it the
/// call only refreshes an address that was already given. Returns whether the
/// notice can be delivered.
Future<bool> enableTrialNotice(WidgetRef ref, {bool ask = true}) async {
  final notifications = ref.read(notificationServiceProvider);
  final profiles = ref.read(profileProvider.notifier);

  if (ask) {
    final granted = await notifications.requestPermission();
    if (!granted) return false;
  } else if (ref.read(profileProvider).trialPushToken == null) {
    return false;
  }

  final registration = await notifications.register();
  final token = registration.token;
  if (token == null) return false;

  final profile = ref.read(profileProvider);
  if (profile.trialPushToken != token || profile.timezone == null) {
    await profiles.update(
      profile.copyWith(
        trialPushToken: token,
        timezone: profile.timezone ?? registration.zone,
      ),
    );
  }
  return true;
}

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

/// Whether to show the admin panel's door on this device.
///
/// Recomputed whenever the signed-in user changes, and false while it is being
/// worked out — the check reads the ID token, which can need a network round
/// trip, and a button that appears a moment late is better than one that
/// appears for the wrong person a moment early.
///
/// This decides nothing but whether a button is drawn. `adminOverview` checks
/// the same claims on the server and refuses on its own account, because an
/// APK can be edited to return true here.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  return AdminService.isAdmin(user);
});

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

        final expiry = entitlementExpiry(data['expiryTime']);
        return expiry == null || expiry.isAfter(DateTime.now());
      })
      .handleError((Object error) {
        debugPrint('Mayow: entitlement stream failed — $error');
      });
});

/// Reads an expiry out of whatever shape the field arrived in.
///
/// `verifyPurchase` writes Play's own ISO 8601 text, so a String is the shape
/// this normally sees. The other two exist because the field can also be typed
/// by hand — in the Firebase Console, or by `adminGrantTrial` — and a value
/// entered there as a date comes back as a [Timestamp]. The previous
/// `as String?` threw on that *inside* the stream's map, and the error handler
/// below swallowed it, so the entitlement silently never arrived: a document
/// that plainly said `isSubscribed: true` read as unsubscribed, with a paying
/// account stuck on the paywall and nothing in the log naming the cause.
///
/// Null for anything unreadable, which the caller treats as "no expiry" —
/// deliberately the same lenient reading the server takes, since `new Date()`
/// on a junk value there yields NaN and compares as not-expired too. Two ends
/// that disagree about an unparseable date is worse than either answer.
@visibleForTesting
DateTime? entitlementExpiry(Object? value) => switch (value) {
  String text => DateTime.tryParse(text),
  Timestamp stamp => stamp.toDate(),
  int millis => DateTime.fromMillisecondsSinceEpoch(millis),
  DateTime at => at,
  _ => null,
};

/// What the server knows about this account's subscription, in full.
///
/// [entitlementProvider] flattens all of this to a yes/no, which is the right
/// shape for a gate and the wrong shape for a screen that has to explain
/// itself. Profile needs to say "you cancelled, and it runs until the 3rd",
/// which is three separate facts: still entitled, no longer renewing, and the
/// date it stops.
class Entitlement {
  const Entitlement({
    required this.isSubscribed,
    required this.expiryTime,
    required this.state,
    required this.isTestGrant,
    required this.everSubscribed,
    this.startedAt,
  });

  static const none = Entitlement(
    isSubscribed: false,
    expiryTime: null,
    state: null,
    isTestGrant: false,
    everSubscribed: false,
  );

  /// Whether this account has ever paid, subscription live or long lapsed.
  ///
  /// True whenever the entitlement document exists at all, which only
  /// `verifyPurchase` and `adminGrantTrial` can make happen — so it cannot be
  /// faked from a device, and it does not decay when a plan runs out.
  ///
  /// It is the difference between two people the app was treating as one: a
  /// stranger who has never paid, and a subscriber whose month ended. The
  /// first has nothing to see. The second has a library, and was promised on
  /// the paywall itself that it "replays without limit, forever".
  final bool everSubscribed;

  final bool isSubscribed;
  final DateTime? expiryTime;

  /// When the subscription began. The free trial runs
  /// [PricingCatalog.trialDays] days from here.
  final DateTime? startedAt;

  /// When the free trial ends, or null once it already has (or never began).
  DateTime? get trialEndsAt {
    final start = startedAt;
    if (start == null || !isSubscribed) return null;
    final end = start.add(const Duration(days: PricingCatalog.trialDays));
    return end.isAfter(DateTime.now()) ? end : null;
  }

  /// Google Play's own word for it — `SUBSCRIPTION_STATE_ACTIVE`,
  /// `SUBSCRIPTION_STATE_CANCELED`, and so on. Stored verbatim rather than
  /// interpreted server-side, so a state Play adds later is still readable.
  final String? state;

  /// Written by `adminGrantTrial` rather than by a purchase. Never counted as
  /// revenue, and worth being able to see in the app.
  final bool isTestGrant;

  /// Cancelled, but still paid up.
  ///
  /// Play keeps a cancelled subscription `ACTIVE` until the period runs out,
  /// which is correct — the user paid for that time and should keep it. So
  /// "cancelled" and "still working" are both true at once, and the only
  /// honest thing to show is the date the second one stops.
  bool get isCancelled =>
      isSubscribed && state == 'SUBSCRIPTION_STATE_CANCELED';
}

/// The whole entitlement document, for the screens that explain it.
final entitlementDetailsProvider = StreamProvider<Entitlement>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(Entitlement.none);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('entitlement')
      .snapshots()
      .map((snap) {
        final data = snap.data();
        if (data == null) return Entitlement.none;

        final expiry = entitlementExpiry(data['expiryTime']);
        final live = data['isSubscribed'] == true &&
            (expiry == null || expiry.isAfter(DateTime.now()));

        return Entitlement(
          isSubscribed: live,
          expiryTime: expiry,
          state: data['state'] as String?,
          isTestGrant: data['source'] == 'admin-grant',
          // The document exists, so somebody paid at some point.
          everSubscribed: true,
          startedAt: entitlementExpiry(data['subscribedAt']),
        );
      })
      .handleError((Object error) {
        debugPrint('Mayow: entitlement detail stream failed — $error');
      });
});

/// The one place the app asks "is this user paying?".
final isSubscribedProvider = Provider<bool>(
  (ref) => ref.watch(entitlementProvider).valueOrNull ?? false,
);

/// Turns purchases into entitlements the moment an account exists.
///
/// Two cases, one mechanism. The hard paywall sells the trial *before* asking
/// for a sign-up, so the purchase arrives with no uid to attach it to and
/// [BillingService] deliberately leaves it unverified. And a paying user who
/// reinstalls has a live subscription on their Google account that this
/// install knows nothing about.
///
/// Both are answered by asking Play what this account already owns, at the
/// first moment there is somewhere to put the answer. Re-running it on every
/// sign-in is harmless — `verifyPurchase` is idempotent, it writes the same
/// entitlement from the same receipt.
final purchaseRestoreProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    final user = next.valueOrNull;
    if (user == null || user.isAnonymous) return;
    if (previous?.valueOrNull?.uid == user.uid) return;

    unawaited(
      ref
          .read(billingServiceProvider)
          .restore()
          .catchError(
            // A restore that fails is not something to interrupt a sign-in
            // over: the user may simply have never subscribed. The paywall's
            // own Restore button is the path for someone who has and is not
            // seeing it.
            (Object error) =>
                debugPrint('Mayow: restore on sign-in failed — $error'),
          ),
    );
  });
});

/// Drops every trace of the current user from memory and disk.
///
/// Emptying the profile is also the navigation: the tree rebuilds against an
/// empty `profile.isOnboarded` without anyone pushing a route. Each notifier is
/// reset explicitly rather than by invalidating the providers, because a
/// rebuilt notifier would read the same storage it is being asked to forget.
///
/// Where this lands the user is decided by [AstraApp], which routes on the
/// account rather than on the profile — so an empty profile sends a signed-out
/// user to sign-in and a signed-in one back through the questions.
Future<void> forgetEverythingLocal(ProviderContainer container) async {
  // A [ProviderContainer], not a [WidgetRef], and that is the entire point.
  //
  // A `WidgetRef` belongs to the widget that owns it and throws the moment that
  // widget is gone. Signing out ends the session, which makes the app rebuild
  // and destroy whatever screen the user pressed Log out on — so a wipe written
  // as `ref.read(...)` after `await signOut()` was reaching for a dead ref and
  // never ran. It failed silently, every time.
  //
  // What that looked like: sign out of one account, sign in as another, and the
  // new user landed on the paywall having never been asked a question, wearing
  // the previous person's name and answers. The account itself was clean — the
  // server had nothing for them — the leftovers were entirely on the phone.
  //
  // The container is owned by `ProviderScope` and outlives every screen under
  // it, so nothing here can be torn out mid-wipe.
  final repository = container.read(repositoryProvider);
  final stories = container.read(storiesProvider.notifier);
  final taste = container.read(tasteProvider.notifier);
  final avatar = container.read(avatarProvider.notifier);
  final profiles = container.read(profileProvider.notifier);

  await repository.clearLocal();
  stories.forget();
  taste.forget();
  avatar.forget();
  // Profile last: it is what the app routes on, so nothing rebuilds against a
  // half-cleared library.
  profiles.forget();
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
    StoryFocus focus = StoryFocus.desire,
    UserProfile? profile,
  }) async {
    final story = await _ref
        .read(storyServiceProvider)
        .write(
          profile: profile ?? _ref.read(profileProvider),
          intention: intention,
          scene: scene,
          focus: focus,
        );

    await _ref.read(storiesProvider.notifier).add(story);
    return story;
  }

  /// Records the narration and attaches it to the stored story.
  ///
  /// Runs after [compose] while the user is already reading. A failure here
  /// leaves a perfectly readable story behind, which is why it is logged
  /// rather than thrown — there is nothing for the reader to do about it.
  /// Returns the story with its audio attached, or the story unchanged if the
  /// narration failed — the caller opens a readable story either way.
  Future<Story> narrate(Story story) async {
    try {
      final withAudio = await _ref.read(storyServiceProvider).narrate(story);
      if (withAudio.audioUrl == null) return story;

      await _ref.read(storiesProvider.notifier).update(withAudio);
      _ref.read(playbackProvider).adoptAudio(withAudio);
      return withAudio;
    } catch (error) {
      debugPrint('Mayow: narration failed, story stays readable — $error');
      return story;
    }
  }
}

final storyComposerProvider = Provider<StoryComposer>(StoryComposer.new);

/// Reports what people do in the app to the admin panel.
final trackingProvider = Provider<TrackingService>((ref) => TrackingService());

final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService());

final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(),
);

// -------------------------------------------------------------- manifest

final manifestServiceProvider = Provider<ManifestService>(
  (ref) => ManifestService(),
);

/// Writes the four questions for a desire.
final planServiceProvider = Provider<PlanService>((ref) => PlanService());

/// Writes affirmation sets.
final affirmationServiceProvider = Provider<AffirmationService>(
  (ref) => AffirmationService(),
);

/// This account's affirmation sets, newest first.
///
/// Read from Firestore on demand for the same reason the manifestations are:
/// they are few, they are small, and fetching fresh means a signed-out phone
/// can never show the last account's list.
final affirmationSetsProvider = FutureProvider<List<AffirmationSet>>((
  ref,
) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const [];

  return ref.read(affirmationServiceProvider).all();
});

/// This account's manifestations, newest first.
///
/// Read from Firestore on demand rather than mirrored to the device like
/// stories are. There are at most ten a month, they are always played from a
/// streamed URL anyway, and fetching fresh means a signed-out phone can never
/// show the last account's list — which is the bug that cost the most time this
/// week, arriving by a different door.
final manifestationsProvider = FutureProvider<List<Manifestation>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const [];

  return ref.read(manifestServiceProvider).all();
});

// ------------------------------------------------------------------ profile

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier(this._repository, Ref ref)
    : super(_repository.loadProfile() ?? UserProfile.empty()) {
    // Restores the profile the moment a real account signs in. Local storage
    // is wiped on sign-out (`forgetEverythingLocal`), and nothing else in the
    // app ever re-downloads it — `StoriesNotifier` has this same restore for
    // the library, the profile never had the equivalent. Without it, signing
    // back into the very Google account that wrote a profile looked exactly
    // like a brand new one: `isOnboarded` read false against an empty local
    // copy while the real answers sat untouched in Firestore the whole time.
  }

  final AstraRepository _repository;

  /// Never overwrites an answer this device already has — only fills in when
  /// the device has nothing, which is exactly the signed-out-then-back-in
  /// case this exists for. A profile mid-onboarding on this phone should not
  /// be clobbered by an older one from the cloud.
  ///
  /// Driven by [profileRestoreProvider] rather than by a listener in here, so
  /// the routing has something to wait on. See the note there.
  Future<void> restoreFromCloud() async {
    if (state.isOnboarded) return;

    final cloud = await _repository.fetchCloudProfile();
    if (cloud == null || !cloud.isOnboarded) return;

    state = cloud;
    await _repository.saveProfile(cloud);
  }

  Future<void> update(UserProfile profile) async {
    state = profile;
    await _repository.saveProfile(profile);
  }

  /// What Mayow calls this person, first name only.
  ///
  /// Taken on the sign-up form and spoken by every manifestation, so it is
  /// trimmed to one word here rather than at each place that reads it.
  Future<void> setName(String name) async {
    final first = name.trim().split(RegExp(r'\s+')).first;
    if (first.isEmpty) return;
    await update(state.copyWith(name: first));
  }

  /// Adopts the display name from the sign-in provider, first name only.
  ///
  /// Only when there is nothing already — a name the user typed themselves is
  /// what they want to be called, and a Google account carrying their full
  /// legal name is not an improvement on it.
  ///
  /// First word, because this name is spoken aloud: the script opens with it,
  /// and "Sidharth, close your eyes" is right where the full name would be
  /// read out like a register.
  Future<void> adoptProviderName(String? displayName) async {
    if (state.name.trim().isNotEmpty) return;

    await setName(displayName ?? '');
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
  (ref) => ProfileNotifier(ref.watch(repositoryProvider), ref),
);

/// Pulls the signed-in account's profile down from Firestore, once per account.
///
/// A [FutureProvider] rather than a listener inside [ProfileNotifier], and the
/// difference is the whole point: a future has a *loading* state, and the
/// routing can wait on it.
///
/// It used to be fire-and-forget. The app chose a screen the instant somebody
/// signed in, while the download was still in flight, so a returning user was
/// routed on an empty local profile and landed on question one of onboarding —
/// their real answers arriving from Firestore a moment later, after the wrong
/// screen was already up. Worse on a bad connection, where the restore may not
/// land at all and they are asked to fill in a profile they already have.
///
/// Keyed on the signed-in user, so switching accounts re-runs it and staying on
/// one does not.
final profileRestoreProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.isAnonymous) return;

  final profile = ref.read(profileProvider.notifier);
  await profile.restoreFromCloud();

  // Take the name Google already knows, if we have none.
  //
  // Onboarding used to ask for it. Nothing does now, and nothing was reading
  // the one the provider hands over either — so a person who signed in with
  // Google was called "friend" by every manifestation the app wrote them,
  // while their real name sat one field away on the credential.
  //
  // After the cloud restore, never before: an account signing in on a second
  // phone has a name saved already, and this must not overwrite it.
  await profile.adoptProviderName(user.displayName);

  // Record which build this account is on, and which one made it.
  //
  // An account that has never finished onboarding is brand new, so it is
  // stamped with this build as its `signupBuild` and sits behind the paywall.
  // An account that finished onboarding on an older build has no stamp and
  // keeps the free run of the app. `appBuild` is the newest build the account
  // has opened; the admin panel uses it to tell old from new.
  final current = ref.read(profileProvider);
  final stamped = current.copyWith(
    signupBuild: current.signupBuild == 0 && !current.onboardingV2Done
        ? kAppBuild
        : null,
    appBuild: kAppBuild,
  );
  if (stamped.signupBuild != current.signupBuild ||
      stamped.appBuild != current.appBuild) {
    await profile.update(stamped);
  }
});

// ------------------------------------------------------------------ stories

class StoriesNotifier extends StateNotifier<List<Story>> {
  StoriesNotifier(this._repository) : super(_repository.loadStories());

  final AstraRepository _repository;

  /// Pulls in any story Firestore has that this device does not.
  ///
  /// The device copy stays authoritative — nothing here overwrites a local
  /// story — so this only ever adds. It runs after the first frame has already
  /// been built from local state, which is why the library is never blocked on
  /// the network.
  Future<void> restoreFromCloud() async {
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

/// Downloads this account's library, once per account.
///
/// The restore used to run inside [StoriesNotifier]'s constructor, which meant
/// it happened exactly once: at app launch, for whoever was signed in then. Log
/// out and back in — or switch accounts — and it never ran again, because the
/// notifier was already built. The local copy had just been wiped by
/// [forgetEverythingLocal], so the library came up empty and stayed empty until
/// the app was killed and reopened.
///
/// From the user's side that is indistinguishable from having lost everything.
/// Nothing was ever deleted: four stories sat in Firestore the whole time, the
/// app simply never asked for them again.
///
/// Keyed on the signed-in user, so switching accounts re-runs it.
final storiesRestoreProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return;

  await ref.read(storiesProvider.notifier).restoreFromCloud();
});

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
      debugPrint('Mayow: stored avatar could not be decoded — $error');
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
  ///
  /// A no-op, deliberately, when nothing has been passed: there is nothing to
  /// bring back. The empty-state screen checks `passed.isNotEmpty` before
  /// offering this button at all, so by the time it is called there is
  /// something for it to do — see [resetAll] for the case where there isn't.
  Future<void> reshuffle() =>
      _save(AffirmationTaste(liked: state.liked, passed: const {}));

  /// Clears kept and passed both, for when there is nothing left to reshuffle
  /// — every card in the chosen life areas has already been liked. Unlike
  /// [reshuffle], this does cost the user their answers, which is why the
  /// screen confirms before calling it.
  Future<void> resetAll() => _save(const AffirmationTaste());

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

/// The server's grouped batch — see `writeAffirmations` in
/// `functions/index.js` — read straight off the same document
/// [sentAffirmationProvider] watches, so the push queue and the browsable
/// deck are always drawn from the same week's writing.
final generatedAffirmationGroupsProvider = StreamProvider<List<AffirmationGroup>>((
  ref,
) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('affirmations')
      .snapshots()
      .map((snap) {
        final raw = snap.data()?['groups'] as List?;
        if (raw == null) return const <AffirmationGroup>[];
        return raw.map(AffirmationGroup.fromMap).whereType<AffirmationGroup>().toList();
      })
      .handleError((Object error) {
        debugPrint('Mayow: generated affirmations unavailable — $error');
      });
});

/// The cards still waiting to be swiped, best first.
///
/// Prefers the server's own generated groups — written from this person's
/// actual name, desire and life areas — over the curated static pool. The
/// curated pool is still what a build with no Firebase, no network at first
/// launch, or a generation that failed falls back to: a line that failed to
/// personalize should degrade to a real line, never to an empty deck.
final affirmationDeckProvider = Provider<List<Affirmation>>((ref) {
  final taste = ref.watch(tasteProvider);
  final generated = ref.watch(generatedAffirmationGroupsProvider).valueOrNull;

  if (generated != null && generated.isNotEmpty) {
    final cards = [
      for (final group in generated) ...group.toCards(),
    ].where((card) => !taste.hasSeen(card.line)).toList();

    if (cards.isNotEmpty) return cards;
  }

  final intentions = ref.watch(
    profileProvider.select((profile) => profile.intentions),
  );
  return Affirmations.deck(intentions, taste);
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
        debugPrint('Mayow: sent affirmation unavailable — $error');
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

/// The distinct days this account wrote something.
///
/// Manifestations *and* stories. The three providers below all used to count
/// only stories, which was right when a story was the product and silently
/// wrong the day manifestations replaced it: somebody who wrote one every
/// morning for a week was shown a streak of zero, an empty week strip and
/// nothing practised this month. The practice was working and the app said it
/// was not, which is the one thing a streak must never do.
Set<DateTime> _daysWritten(Ref ref) => {
  for (final made in ref.watch(everythingWrittenProvider))
    _dayOf(made.createdAt),
};

/// Consecutive days ending today with at least one thing written.
final streakProvider = Provider<int>((ref) {
  final days = _daysWritten(ref);
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
  final days = _daysWritten(ref);
  return days
      .where((d) => d.year == now.year && d.month == now.month)
      .length;
});

/// Monday to Sunday of the current week: true where something was written.
///
/// Days still ahead read as false and the UI draws them as empty rather than
/// missed — a week that starts by showing four failures is a discouraging way
/// to open an app about how things are already going well.
final weekActivityProvider = Provider<List<bool>>((ref) {
  final days = _daysWritten(ref);

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

  /// 'Mayow Plus', 'Free day', 'Free'.
  final String plan;

  /// The sentence under the meter, in whatever unit actually binds.
  final String detail;

  int get left => limit == null ? 0 : (limit! - used).clamp(0, limit!);

  double get fraction =>
      limit == null || limit == 0 ? 1 : (used / limit!).clamp(0, 1);
}

final usageProvider = Provider<Usage>((ref) {
  // Manifestations, not stories.
  //
  // This counted the library, which is now mostly old stories nobody can
  // write any more — so a subscriber who had written twelve stories last year
  // opened the app to "8 left this month" before touching anything, and a
  // person with an empty library saw a full allowance they could not spend.
  // The number has to count the thing the button actually makes.
  final made = ref.watch(manifestationsProvider).valueOrNull ?? const [];

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);

  // The server's answer, not the profile's. `profile.isSubscribed` is a local
  // field the app itself writes; this is a document only the purchase
  // verifier can touch.
  if (!ref.watch(isSubscribedProvider)) {
    // Nothing to meter. The free tier has no manifestations in it at all —
    // writing one is what the subscription is for — so the honest thing to
    // show is the price, not a ring at zero out of zero.
    return Usage(
      used: 0,
      limit: null,
      plan: 'Free',
      detail: 'Mayow Plus writes ${PricingCatalog.manifestMonthly} '
          'manifestations a month. Affirmations are free, always.',
    );
  }

  final thisMonth = made
      .where((one) => !one.createdAt.isBefore(monthStart))
      .length;
  final left = PricingCatalog.manifestMonthly - thisMonth;

  return Usage(
    used: thisMonth,
    limit: PricingCatalog.manifestMonthly,
    plan: 'Mayow Plus',
    detail: left > 0
        ? '$left of ${PricingCatalog.manifestMonthly} left this month · '
              'affirmations are free and unlimited · resets on the 1st'
        : 'All ${PricingCatalog.manifestMonthly} written this month · '
              'affirmations are free and carry on · resets on the 1st',
  );
});

/// How many manifestations were written since the subscription began.
int _madeSince(List<Manifestation> made, DateTime start) =>
    made.where((one) => !one.createdAt.isBefore(start)).length;

/// When the free trial ends, if all [PricingCatalog.trialManifests] of its
/// manifestations are already used. Null otherwise. While this is set the
/// button is replaced by a countdown to that moment.
///
/// Read once per rebuild, so the countdown widget invalidates it when it hits
/// zero and the lock lifts on its own.
final trialLockProvider = Provider<DateTime?>((ref) {
  final entitlement = ref.watch(entitlementDetailsProvider).valueOrNull;
  final ends = entitlement?.trialEndsAt;
  final start = entitlement?.startedAt;
  if (ends == null || start == null) return null;

  final made = ref.watch(manifestationsProvider).valueOrNull ?? const [];
  return _madeSince(made, start) >= PricingCatalog.trialManifests ? ends : null;
});

/// How many manifestations this account may still write this month.
///
/// Zero for anyone without a subscription, which is the same answer the server
/// gives. The button reads this rather than the [Usage] sentence, because a
/// screen that greys a button out has to be sure, and a sentence is for people.
final manifestsLeftProvider = Provider<int>((ref) {
  if (!ref.watch(isSubscribedProvider)) return 0;
  if (ref.watch(trialLockProvider) != null) return 0;
  final usage = ref.watch(usageProvider);
  return usage.limit == null ? 0 : usage.left;
});

/// Everything this account can play, newest first.
///
/// Manifestations and old stories in one list. Nothing new is written as a
/// story any more, but every story ever written still plays, and to the person
/// listening they are the same thing — so Home, the Library and the "minutes"
/// count all read this rather than each keeping its own opinion.
final everythingWrittenProvider = Provider<List<Story>>((ref) {
  final written = ref.watch(storiesProvider);
  final manifested =
      ref.watch(manifestationsProvider).valueOrNull?.map((m) => m.asStory()) ??
      const <Story>[];

  return [...manifested, ...written]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

/// Minutes of audio in the library.
///
/// Named for what it counts. It was called "minutes listened" and shown under
/// that label, while actually summing the length of every story whether or not
/// a second of it had ever been played.
final minutesInLibraryProvider = Provider<int>((ref) {
  return ref
      .watch(everythingWrittenProvider)
      .fold<int>(0, (total, story) => total + story.duration.inMinutes);
});

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);
