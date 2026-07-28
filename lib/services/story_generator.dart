import 'dart:math';

import '../models/intention.dart';
import '../models/story.dart';
import '../models/user_profile.dart';

/// Turns a profile plus a scene prompt into a first-person narrative.
///
/// This on-device generator is the v1 stand-in. The production path is a Cloud
/// Function that calls the Claude API for the script and a TTS voice for the
/// audio, so the API keys never ship in the app; [generate] is the seam that
/// swaps out — its signature already matches what that call will return.
class StoryGenerator {
  StoryGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  Future<Story> generate({
    required UserProfile profile,
    required Intention intention,
    required String scene,
    required Duration length,
    required String voice,
  }) async {
    // Stands in for the round trip to the generation service.
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    final name = profile.name.isEmpty ? 'you' : profile.name;
    final wish = scene.trim().isEmpty ? profile.aspiration.trim() : scene.trim();

    return Story(
      id: 'story_${DateTime.now().microsecondsSinceEpoch}',
      title: _title(intention, wish),
      intention: intention,
      script: _script(name: name, intention: intention, wish: wish),
      duration: length,
      voice: voice,
      createdAt: DateTime.now(),
    );
  }

  String _title(Intention intention, String wish) {
    if (wish.isEmpty) return _fallbackTitles[intention]!;

    // Lift the most concrete-sounding fragment out of what the user wrote.
    final fragment = wish
        .split(RegExp(r'[.,;\n]'))
        .map((s) => s.trim())
        .firstWhere((s) => s.length > 8, orElse: () => wish.trim());

    final words = fragment.split(RegExp(r'\s+')).take(7).join(' ');
    final cleaned = words.replaceAll(RegExp(r'^(i|my|the|a|an)\s+', caseSensitive: false), '');
    return cleaned.isEmpty
        ? _fallbackTitles[intention]!
        : cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  String _script({
    required String name,
    required Intention intention,
    required String wish,
  }) {
    final opening = _openings[_random.nextInt(_openings.length)];
    final anchor = wish.isEmpty ? _fallbackTitles[intention]!.toLowerCase() : wish;

    return '''
$opening

It's already true. The version of $name who wanted $anchor — that's not who you are this morning. You're the one who has it.

${_sensory[intention]}

You notice how ordinary it feels. Not a fantasy you're straining toward, just a Tuesday in the life you built. Your body knows the difference between wishing and remembering, and right now it is remembering.

${_closings[intention]}

Stay here a moment longer. Then open your eyes and go be this person.
''';
  }

  static const _openings = [
    'Breathe out. Let the room go soft.',
    'Settle in. Nothing to reach for here.',
    'Close your eyes. Let the day fall away behind you.',
  ];

  static const _fallbackTitles = {
    Intention.career: 'The work that is finally yours',
    Intention.abundance: 'The month the numbers changed',
    Intention.love: 'The morning you were chosen back',
    Intention.health: 'The body that carries you well',
    Intention.confidence: 'Speaking, unshaken',
    Intention.peace: 'A quiet that stays',
  };

  static const _sensory = {
    Intention.career:
        'There is a desk with your name on it, and it was never handed to you — you made the room it sits in. Someone is waiting on your decision and you already know what it is.',
    Intention.abundance:
        'You open the account without holding your breath. The number is calm, and so are you. Money has stopped being a question you carry into every room.',
    Intention.love:
        'There is someone in the next room who is glad you exist. Not performing it — glad, in the plain way that needs no witness.',
    Intention.health:
        'You take the stairs without thinking about the stairs. Your body is not a project today. It is simply the thing that carries you through a good morning.',
    Intention.confidence:
        'The room turns toward you and your voice does not shake. You say the difficult sentence and the ceiling stays up.',
    Intention.peace:
        'Nothing is urgent. Your phone is face down and the quiet is not waiting to be interrupted.',
  };

  static const _closings = {
    Intention.career:
        'The work found you because you kept showing up as the person who could do it.',
    Intention.abundance:
        'Money moved toward you because you moved first, and kept moving.',
    Intention.love:
        'You were loved plainly, without having to earn the next day of it.',
    Intention.health:
        'You gave your body kindness long enough that it gave it back.',
    Intention.confidence:
        'You stopped waiting to feel ready and became ready on the way.',
    Intention.peace:
        'The quiet was never somewhere else. You just stopped leaving it.',
  };
}
