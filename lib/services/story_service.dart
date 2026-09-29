import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/intention.dart';
import '../models/story.dart';
import '../models/story_preferences.dart';
import '../models/user_profile.dart';
import 'astra_repository.dart';
import 'story_generator.dart';

/// The narrator voices the app offers.
///
/// These are OpenAI voice ids, sent to the function verbatim and echoed back on
/// the stored story. Keeping the id as the source of truth — rather than
/// mapping invented names onto it — means the label in the library is always
/// the voice the listener actually heard.
const astraVoices = <String>['marin', 'coral', 'shimmer', 'sage'];

/// Presentation form of a voice id: `marin` reads as `Marin` in the UI.
String voiceLabel(String id) =>
    id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);

/// Every story runs about this long. Must match `STORY_MINUTES` in the
/// function, which is what actually sizes the script.
const storyLength = Duration(minutes: 5);

/// Thrown when the server refuses because the caller is out of stories.
///
/// Distinct from a generic failure because the response is different: this one
/// opens the paywall, everything else shows an error.
class StoryQuotaExceeded implements Exception {
  const StoryQuotaExceeded(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Produces a story by calling the `generateStory` Cloud Function.
///
/// The generation itself has to run server-side: it needs the Anthropic and
/// OpenAI keys, and anything shipped inside an APK can be pulled back out of
/// it. The function holds the keys, enforces the quota, and returns audio the
/// player can stream.
///
/// Without a signed-in uid there is nothing to authenticate the call with, so
/// the on-device [StoryGenerator] stands in and the user still gets a readable
/// story. That is the same promise the rest of the app makes — Firebase is for
/// sync, never a gate.
class StoryService {
  StoryService({
    required this.repository,
    StoryGenerator? offlineGenerator,
    FirebaseFunctions? functions,
  }) : _offlineGenerator = offlineGenerator ?? StoryGenerator(),
       _functions =
           functions ??
           // Must match the deployed region; the default (us-central1) would
           // 404 against a function that lives in asia-south1.
           FirebaseFunctions.instanceFor(region: 'asia-south1');

  final AstraRepository repository;
  final StoryGenerator _offlineGenerator;
  final FirebaseFunctions _functions;

  /// Whether there is an account to generate against. Derived from the
  /// repository rather than passed in, so that signing out mid-session cannot
  /// leave this service believing in a uid that is gone.
  bool get signedIn => repository.uid != null;

  /// Writes the script. Returns as soon as the words exist — no audio yet.
  /// [scene] is today's moment, in the user's words, and is usually empty —
  /// the whole point of storing preferences is that nobody restates their
  /// desire every morning. [focus] says what to do when it is: continue the
  /// main storyline, go somewhere new in the same life, or let Maya choose.
  Future<Story> write({
    required UserProfile profile,
    required Intention intention,
    required String scene,
    StoryFocus focus = StoryFocus.desire,
  }) async {
    if (!signedIn) {
      return _offlineGenerator.generate(
        profile: profile,
        intention: intention,
        scene: scene,
        length: storyLength,
        voice: profile.voice,
      );
    }

    // The function reads the profile from Firestore rather than trusting the
    // request body, so the mirrored copy has to be current before the call.
    // Writing it again here is idempotent and costs one document write.
    await repository.saveProfile(profile);

    try {
      final result = await _call('writeStory', const Duration(seconds: 170), {
        'intention': intention.name,
        'scene': scene.trim(),
        'focus': focus.name,
      });

      final data = Map<String, dynamic>.from(result as Map);
      return Story.fromMap(data['id'] as String, data);
    } on FirebaseFunctionsException catch (error) {
      throw _translate(error, 'write');
    }
  }

  /// Records the narration for a story that has already been written.
  ///
  /// Returns the same story carrying its audio. Safe to call twice: the
  /// function hands back existing audio rather than paying to record it again.
  Future<Story> narrate(Story story) async {
    if (!signedIn) return story;

    try {
      // Narration is the slow half — comfortably past the 60s default, so the
      // timeout has to be raised or the client hangs up on work it has already
      // been charged for.
      final result = await _call('narrateStory', const Duration(seconds: 570), {
        'storyId': story.id,
      });

      final data = Map<String, dynamic>.from(result as Map);
      return story.copyWith(
        audioUrl: data['audioUrl'] as String?,
        duration: Duration(
          seconds: (data['durationSeconds'] as num?)?.toInt() ??
              story.duration.inSeconds,
        ),
        voice: data['voice'] as String?,
      );
    } on FirebaseFunctionsException catch (error) {
      throw _translate(error, 'narrate');
    }
  }

  Future<Object?> _call(
    String name,
    Duration timeout,
    Map<String, dynamic> payload,
  ) async {
    final callable = _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: timeout),
    );
    final result = await callable.call(payload);
    return result.data;
  }

  Exception _translate(FirebaseFunctionsException error, String stage) {
    if (error.code == 'resource-exhausted') {
      return StoryQuotaExceeded(error.message ?? 'Your free day has ended.');
    }
    debugPrint('Maya: $stage failed — ${error.code} ${error.message}');
    return error;
  }
}
