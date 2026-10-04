import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../app_build.dart';
import '../models/plan.dart';

/// The address allowed to open the admin panel.
///
/// Duplicated from `ADMIN_EMAIL` in `functions/index.js` on purpose, and the
/// copy in the function is the one that decides. This one only chooses whether
/// to draw a button — nothing on a device can be trusted to grant access, since
/// anyone can edit an APK and hand themselves any answer they like.
const adminEmail = 'sidharthbabu9@gmail.com';

/// One account, as the panel shows it.
class AdminUser {
  const AdminUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.providers,
    required this.signedUpAt,
    required this.lastSeenAt,
    required this.stories,
    required this.storiesThisMonth,
    required this.subscribed,
    required this.stage,
    this.wish,
    this.manifests = 0,
    this.affirmations = 0,
    this.paywallViews = 0,
    this.subscribeTaps = 0,
    this.purchaseCancels = 0,
    this.purchaseFails = 0,
    this.appOpens = 0,
    this.trialShown,
    this.lastError,
    this.wishes = const [],
    this.typed = const [],
    this.typedCount = 0,
    this.madeCount = 0,
    this.generateOk = 0,
    this.generateFailed = 0,
    this.pushReady = false,
    this.appBuild = 0,
    this.signupBuild = 0,
  });

  /// The newest build this account has opened; 0 if it has only ever used an
  /// older one.
  final int appBuild;

  /// The build that created the account; 0 if it predates the paywall build.
  final int signupBuild;

  /// Has the new app (the one with the paywall and the 7-day trial).
  bool get onNewApp => appBuild >= kGateFromBuild;

  /// Signed up on the new app, so it is behind the paywall.
  bool get isNewSignup => signupBuild >= kGateFromBuild;

  /// The last wish this person typed on Home or Affirmations, in their words.
  final String? wish;
  final int manifests;
  final int affirmations;

  /// How often they saw the price, pressed subscribe, backed out of the store
  /// sheet, or hit an error in it. These say what stops people paying.
  final int paywallViews;
  final int subscribeTaps;
  final int purchaseCancels;
  final int purchaseFails;
  final int appOpens;

  /// Whether the last paywall they saw showed the free trial. Null if unknown.
  final bool? trialShown;
  final String? lastError;

  /// Every manifestation this account typed, newest first — the wish itself,
  /// never the script written from it.
  final List<AdminWish> wishes;

  /// Every wish this account typed, newest first, each marked with whether it
  /// ever produced a manifestation or a set of affirmations.
  final List<AdminTyped> typed;

  /// How many times they pressed Continue on a wish, how many distinct wishes
  /// turned into something, and how many generation attempts succeeded or
  /// failed (counted since tracking began).
  final int typedCount;
  final int madeCount;
  final int generateOk;
  final int generateFailed;

  /// Whether this phone can be reached by a push at all — reminders on, with a
  /// push address stored.
  final bool pushReady;

  final String uid;
  final String? email;
  final String? name;
  final List<String> providers;
  final DateTime? signedUpAt;
  final DateTime? lastSeenAt;

  /// Every story this account has ever generated, counted from a server-side
  /// counter that only goes up — deleting a story does not give it back.
  final int stories;
  final int storiesThisMonth;
  final bool subscribed;

  /// The furthest step this account reached, derived server-side from data the
  /// app already writes. Not a screen — nothing records which screen anyone
  /// closed the app on — but it does say which step they stopped after.
  final AdminStage stage;

  factory AdminUser.fromMap(Map<String, dynamic> map) => AdminUser(
    uid: map['uid'] as String? ?? '',
    email: map['email'] as String?,
    name: (map['name'] as String?)?.trim().isEmpty ?? true
        ? null
        : (map['name'] as String).trim(),
    providers: ((map['providers'] as List?) ?? const [])
        .map((provider) => provider.toString())
        .toList(),
    signedUpAt: DateTime.tryParse(map['signedUpAt'] as String? ?? ''),
    lastSeenAt: DateTime.tryParse(map['lastSeenAt'] as String? ?? ''),
    stories: (map['stories'] as num?)?.toInt() ?? 0,
    storiesThisMonth: (map['storiesThisMonth'] as num?)?.toInt() ?? 0,
    subscribed: map['subscribed'] as bool? ?? false,
    stage: AdminStage.fromWire(map['stage'] as String?),
    wish: (map['wish'] as String?)?.trim().isEmpty ?? true
        ? null
        : (map['wish'] as String).trim(),
    manifests: (map['manifests'] as num?)?.toInt() ?? 0,
    affirmations: (map['affirmations'] as num?)?.toInt() ?? 0,
    paywallViews: (map['paywallViews'] as num?)?.toInt() ?? 0,
    subscribeTaps: (map['subscribeTaps'] as num?)?.toInt() ?? 0,
    purchaseCancels: (map['purchaseCancels'] as num?)?.toInt() ?? 0,
    purchaseFails: (map['purchaseFails'] as num?)?.toInt() ?? 0,
    appOpens: (map['appOpens'] as num?)?.toInt() ?? 0,
    trialShown: map['trialShown'] as bool?,
    lastError: map['lastError'] as String?,
    wishes: ((map['wishes'] as List?) ?? const [])
        .map((w) => AdminWish.fromMap(Map<String, dynamic>.from(w as Map)))
        .toList(),
    typed: ((map['typed'] as List?) ?? const [])
        .map((w) => AdminTyped.fromMap(Map<String, dynamic>.from(w as Map)))
        .toList(),
    typedCount: (map['typedCount'] as num?)?.toInt() ?? 0,
    madeCount: (map['madeCount'] as num?)?.toInt() ?? 0,
    generateOk: (map['generateOk'] as num?)?.toInt() ?? 0,
    generateFailed: (map['generateFailed'] as num?)?.toInt() ?? 0,
    pushReady: map['pushReady'] as bool? ?? false,
    appBuild: (map['appBuild'] as num?)?.toInt() ?? 0,
    signupBuild: (map['signupBuild'] as num?)?.toInt() ?? 0,
  );
}

/// One typed wish behind a manifestation, in the account's own words.
class AdminWish {
  const AdminWish({required this.dream, this.createdAt});

  final String dream;
  final DateTime? createdAt;

  factory AdminWish.fromMap(Map<String, dynamic> map) => AdminWish(
    dream: map['dream'] as String? ?? '',
    createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
  );
}

/// One wish an account typed, and what became of it.
class AdminTyped {
  const AdminTyped({required this.wish, this.at, this.made});

  final String wish;
  final DateTime? at;

  /// "manifestation", "affirmations", or null when nothing was ever generated
  /// from it.
  final String? made;

  bool get wasMade => made != null;

  factory AdminTyped.fromMap(Map<String, dynamic> map) => AdminTyped(
    wish: map['wish'] as String? ?? '',
    at: DateTime.tryParse(map['at'] as String? ?? ''),
    made: map['made'] as String?,
  );
}

/// How far an account got, worst to best.
enum AdminStage {
  /// Signed up before the new tracking existed and has not opened a build
  /// that reports it yet — not a step in the funnel, just unknown so far.
  notUpdated('Has not opened the latest version yet'),
  opened('Opened the app, no wish typed'),
  typedWish('Typed a wish, never saw the price'),
  sawPaywall('Saw the price, did not press subscribe'),
  tappedSubscribe('Pressed subscribe, did not pay'),
  subscribed('Subscribed, nothing written yet'),
  writing('Subscribed and writing');

  const AdminStage(this.label);

  final String label;

  static AdminStage fromWire(String? value) => switch (value) {
    'typed-wish' => typedWish,
    'saw-paywall' => sawPaywall,
    'tapped-subscribe' => tappedSubscribe,
    'subscribed' => subscribed,
    'writing' => writing,
    'not-updated' => notUpdated,
    _ => opened,
  };
}

/// Everything the panel shows at once.
/// An account that has been closed but not yet destroyed.
///
/// The credential is already gone — this person cannot sign in, and the
/// address is free for them to sign up with again. What is left is data under
/// a uid nothing points at, waiting out the week in which a mistake can still
/// be undone.
class DeletedAccount {
  const DeletedAccount({
    required this.uid,
    this.email,
    this.name,
    this.deletedAt,
    this.purgeAfter,
  });

  final String uid;
  final String? email;
  final String? name;
  final DateTime? deletedAt;

  /// When what is left of it is destroyed for good.
  final DateTime? purgeAfter;

  /// Whole days remaining, rounded up, or zero once the date has passed.
  int get daysLeft {
    if (purgeAfter == null) return 0;
    final gap = purgeAfter!.difference(DateTime.now());
    return gap.isNegative ? 0 : gap.inHours ~/ 24 + 1;
  }

  factory DeletedAccount.fromMap(Map<String, dynamic> map) => DeletedAccount(
    uid: map['uid'] as String? ?? '',
    email: map['email'] as String?,
    name: map['name'] as String?,
    deletedAt: DateTime.tryParse(map['deletedAt'] as String? ?? ''),
    purgeAfter: DateTime.tryParse(map['purgeAfter'] as String? ?? ''),
  );
}

class AdminOverview {
  const AdminOverview({
    required this.totalUsers,
    required this.totalStories,
    this.totalAffirmations = 0,
    this.pushReachable = 0,
    required this.subscribers,
    required this.users,
    this.deleted = const [],
  });

  final int totalUsers;
  final int totalStories;
  final int totalAffirmations;

  /// Accounts with a push address stored — the ceiling on who an
  /// announcement can reach.
  final int pushReachable;
  final int subscribers;
  final List<AdminUser> users;

  /// Closed accounts still inside their week, soonest to be destroyed first.
  final List<DeletedAccount> deleted;

  factory AdminOverview.fromMap(Map<String, dynamic> map) => AdminOverview(
    totalUsers: (map['totalUsers'] as num?)?.toInt() ?? 0,
    totalStories: (map['totalStories'] as num?)?.toInt() ?? 0,
    totalAffirmations: (map['totalAffirmations'] as num?)?.toInt() ?? 0,
    pushReachable: (map['pushReachable'] as num?)?.toInt() ?? 0,
    subscribers: (map['subscribers'] as num?)?.toInt() ?? 0,
    users: ((map['users'] as List?) ?? const [])
        .map((user) => AdminUser.fromMap(Map<String, dynamic>.from(user as Map)))
        .toList(),
    deleted: ((map['deleted'] as List?) ?? const [])
        .map(
          (row) => DeletedAccount.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(),
  );
}

/// One announcement, and how it landed.
///
/// [opened] is the only number here that came from a person. The rest are
/// what the server and Google between them reported: [delivered] means FCM
/// accepted the token, not that a phone showed anything. A notification can be
/// delivered and swiped away without ever being read, and nothing tells us the
/// difference — so "sent 40, opened 12" means twelve people tapped it, and the
/// other twenty-eight are unknown rather than uninterested.
class Broadcast {
  const Broadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.recipients,
    required this.delivered,
    required this.failed,
    required this.opened,
    this.sentAt,
  });

  final String id;
  final String title;
  final String body;

  /// Devices it was addressed to.
  final int recipients;

  /// Devices Google accepted it for.
  final int delivered;

  /// Devices it could not be sent to — usually an uninstall.
  final int failed;

  /// People who tapped it.
  final int opened;

  final DateTime? sentAt;

  /// Of the ones that got out, how many were opened. Zero rather than a
  /// division by zero when nothing was delivered.
  double get openRate => delivered == 0 ? 0 : opened / delivered;

  factory Broadcast.fromMap(Map<String, dynamic> map) => Broadcast(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    recipients: (map['recipients'] as num?)?.toInt() ?? 0,
    delivered: (map['delivered'] as num?)?.toInt() ?? 0,
    failed: (map['failed'] as num?)?.toInt() ?? 0,
    opened: (map['opened'] as num?)?.toInt() ?? 0,
    sentAt: DateTime.tryParse(map['sentAt'] as String? ?? ''),
  );
}

/// One person on the receiving end of one announcement.
class BroadcastRecipient {
  const BroadcastRecipient({
    required this.uid,
    required this.delivered,
    required this.opened,
    this.email,
    this.openedAt,
  });

  final String uid;

  /// Null for an account closed since the send. The row is kept anyway —
  /// "sent to somebody who has since left" is true and worth seeing.
  final String? email;
  final bool delivered;
  final bool opened;
  final DateTime? openedAt;

  factory BroadcastRecipient.fromMap(Map<String, dynamic> map) =>
      BroadcastRecipient(
        uid: map['uid'] as String? ?? '',
        email: map['email'] as String?,
        delivered: map['delivered'] as bool? ?? false,
        opened: map['opened'] as bool? ?? false,
        openedAt: DateTime.tryParse(map['openedAt'] as String? ?? ''),
      );
}

/// Reads the account overview, for the one account allowed to.
class AdminService {
  AdminService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;

  FirebaseFunctions get _functions =>
      _injected ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Whether to offer the panel at all on this device.
  ///
  /// Two conditions, and the second is the one that matters. Firebase keeps one
  /// account per email address, so an address that also has a password on it
  /// can be signed into without Google ever being involved — an email check on
  /// its own would let that session through.
  ///
  /// [User.providerData] cannot answer this: it lists what the account has
  /// *linked*, which stays true no matter how the current session was opened.
  /// The token's `signInProvider` describes this session specifically, so it is
  /// the only client-side answer that means anything.
  ///
  /// The server checks the same two claims on the same token and refuses on its
  /// own account. This just avoids drawing a button that would fail.
  static Future<bool> isAdmin(User? user) async {
    // Debug builds only: a test guest may open the panel to see how it looks.
    // It shows sample data (see [overview]) and every action still goes to the
    // server, which refuses anyone but the real admin account.
    if (kDebugMode && (user?.isAnonymous ?? false)) return true;

    if (user == null || user.email != adminEmail) return false;

    try {
      final token = await user.getIdTokenResult();
      return token.signInProvider == 'google.com';
    } catch (_) {
      // Offline, or a token that would not refresh. No panel, no error — it is
      // a button, and the panel needs the network anyway.
      return false;
    }
  }

  Future<AdminOverview> overview() async {
    if (kDebugMode && (FirebaseAuth.instance.currentUser?.isAnonymous ?? false)) {
      return _sampleOverview();
    }

    final result = await _functions
        .httpsCallable('adminOverview')
        .call<Map<Object?, Object?>>();

    return AdminOverview.fromMap(Map<String, dynamic>.from(result.data));
  }

  /// Puts a test entitlement on an account, or takes it off with [days] of 0.
  ///
  /// This being a server call rather than a Firestore write is the reason the
  /// whole entitlement design holds: nothing on a device can write that
  /// document, this app included. The function re-checks the same admin claims
  /// on its own account, so this method existing in a decompiled APK grants
  /// nobody anything.
  ///
  /// What it is *for* is the gap between "the paywall took a purchase" and
  /// "the story generated". Play will not issue a receipt to a web build, and
  /// a licence tester still needs a signed build on a real device, so without
  /// this there is no way to see what a subscriber sees except by becoming one.
  /// Removes the fields the old onboarding wrote, from every account.
  /// Returns how many accounts were cleaned.
  Future<int> cleanOldFields() async {
    final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable(
          'adminCleanOldFields',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
        )
        .call<Map<Object?, Object?>>();
    return (result.data['cleaned'] as num?)?.toInt() ?? 0;
  }

  Future<void> setTrial({
    required String uid,
    int days = PricingCatalog.trialDays,
  }) async {
    await _functions
        .httpsCallable('adminGrantTrial')
        .call<Map<Object?, Object?>>({'uid': uid, 'days': days});
  }

  /// Sends one announcement to every device that will take one.
  ///
  /// Rare by design. A push nobody asked for is the quickest way to be
  /// uninstalled, and Play treats unsolicited promotional notifications as
  /// spam — so this exists for the handful of moments that genuinely warrant
  /// it, like telling people the app they already have now looks different.
  Future<Broadcast> broadcast({
    required String title,
    required String body,
  }) async {
    final result = await _functions
        .httpsCallable('adminBroadcast')
        .call<Map<Object?, Object?>>({'title': title, 'body': body});

    final data = Map<String, dynamic>.from(result.data);
    return Broadcast.fromMap({...data, 'title': title, 'body': body});
  }

  /// Every announcement sent, newest first.
  Future<List<Broadcast>> broadcasts() async {
    final result = await _functions
        .httpsCallable('adminBroadcasts')
        .call<Map<Object?, Object?>>();

    final rows = (Map<String, dynamic>.from(result.data)['broadcasts'] as List?) ?? const [];
    return rows
        .map((row) => Broadcast.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Who one announcement reached, and who opened it.
  Future<List<BroadcastRecipient>> recipients(String broadcastId) async {
    final result = await _functions
        .httpsCallable('adminBroadcasts')
        .call<Map<Object?, Object?>>({'id': broadcastId});

    final rows = (Map<String, dynamic>.from(result.data)['recipients'] as List?) ?? const [];
    return rows
        .map((row) => BroadcastRecipient.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Closes somebody else's account.
  ///
  /// Immediate and not undoable from here: the credential is destroyed, so
  /// they cannot sign in and their email address is free to sign up with
  /// again — as a new account, with none of the old one's writing in it.
  ///
  /// Their data waits a week before it is destroyed, which is the only room
  /// there is to change your mind. Undoing it inside that week is a job for
  /// the console, not a button — there is no restore path in the app, on
  /// purpose, because a restore button next to a delete button is how the
  /// wrong one gets pressed twice.
  ///
  /// Returns the date the data is destroyed.
  Future<DateTime?> deleteAccount(String uid) async {
    final result = await _functions
        .httpsCallable('adminDeleteAccount')
        .call<Map<Object?, Object?>>({'uid': uid});

    final data = Map<String, dynamic>.from(result.data);
    return DateTime.tryParse(data['purgeAfter'] as String? ?? '');
  }
}

/// Made-up people, for looking at the panel without the real admin account.
/// Debug builds only, and only ever returned to a test guest.
AdminOverview _sampleOverview() {
  final now = DateTime.now();
  AdminUser user(
    String name,
    String email, {
    required AdminStage stage,
    int opens = 1,
    int typed = 0,
    int made = 0,
    int views = 0,
    int taps = 0,
    int cancels = 0,
    int errors = 0,
    int genFailed = 0,
    bool? trial,
    bool subscribed = false,
    bool push = false,
    String? lastError,
    List<AdminTyped> wishes = const [],
    int daysAgo = 1,
    int build = 0,
  }) => AdminUser(
    uid: email,
    email: email,
    name: name,
    providers: const ['google.com'],
    signedUpAt: now.subtract(Duration(days: daysAgo)),
    lastSeenAt: now.subtract(Duration(hours: daysAgo * 3)),
    stories: made,
    storiesThisMonth: made,
    subscribed: subscribed,
    stage: stage,
    manifests: made,
    affirmations: made,
    appOpens: opens,
    typedCount: typed,
    madeCount: wishes.where((w) => w.wasMade).length,
    paywallViews: views,
    subscribeTaps: taps,
    purchaseCancels: cancels,
    purchaseFails: errors,
    generateFailed: genFailed,
    trialShown: trial,
    pushReady: push,
    appBuild: build,
    signupBuild: build,
    lastError: lastError,
    typed: wishes,
    wish: wishes.isEmpty ? null : wishes.first.wish,
  );

  return AdminOverview(
    totalUsers: 4,
    totalStories: 3,
    totalAffirmations: 5,
    pushReachable: 1,
    subscribers: 1,
    users: [
      user('Sample Priya', 'priya@example.com',
          stage: AdminStage.writing,
          opens: 9, typed: 3, made: 2, views: 2, taps: 1, trial: true,
          subscribed: true, push: true, daysAgo: 6, build: 40,
          wishes: [
            AdminTyped(wish: 'I want to buy my dream home', at: now, made: 'manifestation'),
            AdminTyped(wish: 'I want to feel calm before exams', at: now, made: 'affirmations'),
            AdminTyped(wish: 'I want a promotion this year', at: now),
          ]),
      user('Sample Larry', 'larry@example.com',
          stage: AdminStage.sawPaywall,
          opens: 2, typed: 1, views: 2, trial: true, daysAgo: 1, build: 40,
          wishes: [AdminTyped(wish: 'I want the lines under my eyes to go away', at: now)]),
      user('Sample Karen', 'karen@example.com',
          stage: AdminStage.tappedSubscribe,
          opens: 4, typed: 2, views: 3, taps: 2, cancels: 1, errors: 1,
          trial: false, lastError: 'PlatformException(BillingResponse.itemUnavailable)',
          daysAgo: 2,
          wishes: [
            AdminTyped(wish: 'I want to leave the job that is making me small', at: now),
            AdminTyped(wish: 'I want to speak up in the room and not shake', at: now),
          ]),
      user('Sample Betty', 'betty@example.com',
          stage: AdminStage.opened, daysAgo: 0),
    ],
  );
}
