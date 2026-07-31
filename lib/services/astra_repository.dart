import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/journal_entry.dart';
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
  AstraRepository(this._prefs, {this.uid});

  static const _profileKey = 'astra.profile';
  static const _storiesKey = 'astra.stories';
  static const _journalKey = 'astra.journal';

  final SharedPreferences _prefs;

  /// Null when anonymous sign-in was unavailable; the repository then skips
  /// every cloud write and behaves as pure local storage.
  final String? uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  // ---------------------------------------------------------------- profile

  UserProfile? loadProfile() {
    final raw = _prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return UserProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      debugPrint('Astra: could not decode stored profile — $error');
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(_profileKey, jsonEncode(profile.toMap()));
    await _mirror(() => _userDoc.set(profile.toMap(), SetOptions(merge: true)));
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
      debugPrint('Astra: could not read cloud stories — $error');
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

  // ---------------------------------------------------------------- journal

  List<JournalEntry> loadJournal() =>
      _loadList(_journalKey, (id, map) => JournalEntry.fromMap(id, map))
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> addJournalEntry(JournalEntry entry) async {
    final entries = loadJournal()..insert(0, entry);
    await _saveList(_journalKey, {
      for (final e in entries) e.id: e.toMap(),
    });
    await _mirror(
      () => _userDoc.collection('journal').doc(entry.id).set(entry.toMap()),
    );
  }

  Future<void> deleteJournalEntry(String entryId) async {
    final entries = loadJournal()..removeWhere((e) => e.id == entryId);
    await _saveList(_journalKey, {
      for (final e in entries) e.id: e.toMap(),
    });
    await _mirror(() => _userDoc.collection('journal').doc(entryId).delete());
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
      debugPrint('Astra: could not decode "$key" — $error');
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
      debugPrint('Astra: cloud sync skipped — $error');
    }
  }
}
