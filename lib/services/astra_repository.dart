import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/affirmation_taste.dart';
import '../models/story.dart';
import '../models/user_profile.dart';

/// Offline-first storage for everything the user creates.
///
/// The device copy is authoritative for reads, so the app is fully usable with
/// no network and no account. When a Firebase uid is available every write is
/// mirrored to Firestore for backup and cross-device restore; a failure there
/// is logged and swallowed rather than surfaced, because losing the cloud copy
/// must never cost the user their story.
class AstraRepository {
  AstraRepository(this._prefs);

  static const _profileKey = 'astra.profile';
  static const _storiesKey = 'astra.stories';
  static const _tasteKey = 'astra.taste';
  static const _avatarKey = 'astra.avatar';

  final SharedPreferences _prefs;

  /// The signed-in account, read live rather than captured at construction.
  ///
  /// It has to be live because it changes underneath us: signing out or
  /// deleting the account leaves any captured copy pointing at a uid that no
  /// longer exists, and the next mirrored write would recreate the very
  /// document the user asked to be rid of. Null means no account — either
  /// sign-in was unavailable or the user signed out — and every cloud write
  /// then quietly becomes a no-op.
  String? get uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (error) {
      // Firebase never initialised. Local storage is the whole app then.
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  // ---------------------------------------------------------------- profile

  UserProfile? loadProfile() {
    final raw = _prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return UserProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      debugPrint('Maya: could not decode stored profile — $error');
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(_profileKey, jsonEncode(profile.toMap()));
    await _mirror(() => _userDoc.set(profile.toMap(), SetOptions(merge: true)));
  }

  /// Records how far through onboarding this account has got.
  ///
  /// Cloud only, and deliberately so: this exists to be read by somebody other
  /// than the person it describes, and a copy on their own phone would answer
  /// nobody's question.
  ///
  /// It fills a real blind spot. The profile is not written until onboarding
  /// *finishes*, so an account that stopped at question seven looked exactly
  /// like one that stopped at question one — both are an auth record and
  /// nothing else. Twelve questions is the longest thing this app asks anyone
  /// to do, and until now there was no way to see where people gave up.
  ///
  /// Written into the user document rather than a collection of its own, so
  /// the admin overview picks it up in a read it was already making.
  ///
  /// At most twelve tiny writes per account, and only while onboarding. This
  /// is the furthest question of the *most recent* attempt, not of all time:
  /// onboarding restarts at question one when the app is relaunched, so a
  /// second abandoned run overwrites the first — which is the more useful of
  /// the two answers anyway.
  /// Records how a listening session felt.
  ///
  /// Cloud only, and fire-and-forget. Nothing in the app reads it back — it is
  /// there to answer "does this actually make people feel better", which is a
  /// question about the whole product rather than about one user's screen, and
  /// storing it on the device would answer it for nobody.
  Future<void> recordSessionMood({
    required String about,
    required String mood,
  }) => _mirror(
    () => _userDoc.collection('sessions').add({
      'about': about,
      'mood': mood,
      'at': DateTime.now().toUtc().toIso8601String(),
    }),
  );

  /// The profile as Firestore has it, or null if there is no account, no
  /// network, or nothing has ever been saved there.
  ///
  /// The read half of the profile mirror — [fetchCloudStories] already had
  /// one of these and the profile never did, which is exactly the bug it
  /// caused: sign out wipes local storage, and without this, signing back
  /// into the very account that wrote a profile looked like a brand new one.
  /// Nothing else in the app re-downloaded it.
  Future<UserProfile?> fetchCloudProfile() async {
    if (uid == null) return null;
    try {
      final snapshot = await _userDoc.get();
      final data = snapshot.data();
      if (data == null) return null;
      return UserProfile.fromMap(data);
    } catch (error) {
      debugPrint('Maya: could not read cloud profile — $error');
      return null;
    }
  }

  /// Removes everything Maya has stored on this device.
  ///
  /// Named keys rather than `prefs.clear()`: the preference store belongs to
  /// the whole app, and a wipe that also took out something a plugin had put
  /// there would be a bug nobody would think to look for here.
  Future<void> clearLocal() async {
    for (final key in [_profileKey, _storiesKey, _tasteKey, _avatarKey]) {
      await _prefs.remove(key);
    }
  }

  // ----------------------------------------------------------------- avatar

  /// The profile photo, base64-encoded, or null if none was chosen.
  ///
  /// Deliberately not part of [UserProfile] and deliberately not mirrored: the
  /// profile document is written on every settings change, and pushing 20KB of
  /// image through each of those writes to back up something the story
  /// generator never reads would be paying for nothing. A photo that does not
  /// survive a reinstall is an acceptable loss; a story is not.
  String? loadAvatar() => _prefs.getString(_avatarKey);

  Future<void> saveAvatar(String? base64) async {
    if (base64 == null) {
      await _prefs.remove(_avatarKey);
      return;
    }
    await _prefs.setString(_avatarKey, base64);
  }

  // ---------------------------------------------------------------- stories

  List<Story> loadStories() =>
      _loadList(_storiesKey, (id, map) => Story.fromMap(id, map))
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> saveStories(List<Story> stories) async {
    await _saveList(_storiesKey, {
      for (final story in stories) story.id: story.toMap(),
    });
  }

  Future<void> addStory(Story story) async {
    final stories = loadStories()..insert(0, story);
    await saveStories(stories);
    await _mirror(
      // Merged, not replaced: the generating function writes fields the client
      // model does not carry (audioPath), and a plain set would erase them.
      () => _userDoc
          .collection('stories')
          .doc(story.id)
          .set(story.toMap(), SetOptions(merge: true)),
    );
  }

  /// Stories held in Firestore, or an empty list when there is no account,
  /// no network, or anything else goes wrong.
  ///
  /// This is the read half of the mirror. It covers two cases: a fresh install
  /// signing back in, and — more commonly — a story the function finished and
  /// stored after the client had already stopped waiting for it. The audio
  /// exists and has been paid for either way, so it should come back.
  Future<List<Story>> fetchCloudStories() async {
    if (uid == null) return const [];
    try {
      final snapshot = await _userDoc.collection('stories').get();
      return snapshot.docs
          .map((doc) => Story.fromMap(doc.id, doc.data()))
          .toList();
    } catch (error) {
      debugPrint('Maya: could not read cloud stories — $error');
      return const [];
    }
  }

  Future<void> updateStory(Story story) async {
    final stories = loadStories();
    final index = stories.indexWhere((s) => s.id == story.id);
    if (index == -1) return addStory(story);

    stories[index] = story;
    await saveStories(stories);
    await _mirror(
      // Merged, not replaced: the generating function writes fields the client
      // model does not carry (audioPath), and a plain set would erase them.
      () => _userDoc
          .collection('stories')
          .doc(story.id)
          .set(story.toMap(), SetOptions(merge: true)),
    );
  }

  Future<void> deleteStory(String storyId) async {
    final stories = loadStories()..removeWhere((s) => s.id == storyId);
    await saveStories(stories);
    await _mirror(() => _userDoc.collection('stories').doc(storyId).delete());
  }

  // ------------------------------------------------------------------ taste

  AffirmationTaste loadTaste() {
    final raw = _prefs.getString(_tasteKey);
    if (raw == null) return const AffirmationTaste();
    try {
      return AffirmationTaste.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      debugPrint('Maya: could not decode affirmation taste — $error');
      return const AffirmationTaste();
    }
  }

  Future<void> saveTaste(AffirmationTaste taste) async {
    await _prefs.setString(_tasteKey, jsonEncode(taste.toMap()));
    await _mirror(
      () => _userDoc.set({'affirmationTaste': taste.toMap()}, SetOptions(merge: true)),
    );
  }

  // ----------------------------------------------------------------- shared

  List<T> _loadList<T>(
    String key,
    T Function(String id, Map<String, dynamic> map) decode,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null) return <T>[];

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.entries
          .map((e) => decode(e.key, e.value as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('Maya: could not decode "$key" — $error');
      return <T>[];
    }
  }

  Future<void> _saveList(String key, Map<String, dynamic> byId) =>
      _prefs.setString(key, jsonEncode(byId));

  Future<void> _mirror(Future<void> Function() write) async {
    if (uid == null) return;
    try {
      await write();
    } catch (error) {
      debugPrint('Maya: cloud sync skipped — $error');
    }
  }

  // ---------------------------------------------------------------- reports

  /// Flags one piece of generated content — a story or an affirmation line.
  ///
  /// Unlike every write above, this one does not go through [_mirror] and does
  /// not swallow its own failure. A profile edit that quietly fails to sync
  /// costs nothing the user can see; a report that quietly fails to send is a
  /// person who believes something has been flagged when nobody has heard
  /// about it, which is the one failure mode Play's Generative AI policy exists
  /// to prevent. The caller is expected to show its own error if this throws.
  Future<void> submitReport({
    required String kind,
    required String contentId,
    required String excerpt,
    String? reason,
  }) async {
    final reporter = uid;
    if (reporter == null) {
      throw StateError('Signed out — nothing to attach the report to.');
    }

    await FirebaseFirestore.instance.collection('reports').add({
      'uid': reporter,
      'kind': kind,
      'contentId': contentId,
      // Capped well short of the full script: enough for a reviewer to find
      // and recognise the piece, not a duplicate of data already sitting in
      // the user's own `stories` subcollection.
      'excerpt': excerpt.length > 600 ? excerpt.substring(0, 600) : excerpt,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
