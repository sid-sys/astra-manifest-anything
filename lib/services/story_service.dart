import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/intention.dart';
import '../models/story.dart';
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
    required this.signedIn,
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
  final bool signedIn;

  Future<Story> generate({
    required UserProfile profile,
    required Intention intention,
    required String scene,
    required String mood,
    required Duration length,
    required String voice,
  }) async {
    if (!signedIn) {
      return _offlineGenerator.generate(
        profile: profile,
        intention: intention,
        scene: scene,
        length: length,
        voice: voice,
      );
    }

    // The function reads the profile from Firestore rather than trusting the
    // request body, so the mirrored copy has to be current before the call.
    // Writing it again here is idempotent and costs one document write.
    await repository.saveProfile(profile);

    try {
      final result = await _functions
          .httpsCallable(
            'generateStory',
            // The default is 60 seconds and a story takes about 65 — writing it
            // and narrating it are both slow. Under the default the client gave
            // up on work the server had already finished and charged for, and
            // the story was lost. Sits just under the function's own 540s cap.
            options: HttpsCallableOptions(timeout: const Duration(seconds: 570)),
          )
          .call({
        'intention': intention.name,
        'scene': scene.trim(),
        'mood': mood,
        'lengthMinutes': length.inMinutes,
        'voice': voice,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return Story.fromMap(data['id'] as String, data);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'resource-exhausted') {
        throw StoryQuotaExceeded(
          error.message ?? 'Your free day has ended.',
        );
      }
      debugPrint('Astra: story generation failed — ${error.code} ${error.message}');
      rethrow;
    }
  }
}
