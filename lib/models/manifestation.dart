import 'intention.dart';
import 'story.dart';

/// One guided manifestation: a wish, the script written from it, and the audio.
///
/// Deliberately not a [Story]. They look similar — text plus an MP3 — and
/// sharing the class would have saved a file, but they differ in every way that
/// the app then has to branch on: a story is a scene in the third minute of
/// someone's future and is written from twelve onboarding answers; a
/// manifestation is a slow second-person read built from one sentence the user
/// typed today. They have separate monthly allowances because they cost
/// different amounts to make, separate voices, and separate places in the app.
///
/// Two types that are told apart by a flag are two types.
class Manifestation {
  const Manifestation({
    required this.id,
    required this.dream,
    required this.script,
    required this.duration,
    required this.createdAt,
    this.audioUrl,
  });

  final String id;

  /// What the user asked for, in their own words. This is the title everywhere
  /// it is listed — never the script's first line, because every script opens
  /// with the same "close your eyes" and a list of those is unreadable.
  final String dream;

  final String script;
  final Duration duration;
  final DateTime createdAt;
  final String? audioUrl;

  bool get hasAudio => audioUrl != null;

  String get durationLabel {
    final minutes = duration.inMinutes;
    return minutes < 1 ? 'under a minute' : '$minutes min';
  }

  /// The script as it should be *read*, without the markdown the model leaves
  /// behind.
  ///
  /// The writing prompt asks for emphasis and pauses, and the model returns
  /// them as `**bold**` and `---` rules. Those are for the eye. Fed to a
  /// narrator they are either read aloud as "asterisk asterisk" or, worse,
  /// silently change the pacing — so they are stripped for display and the
  /// server strips them again before narrating.
  String get readable => script
      .replaceAll(RegExp(r'^#{1,6}\s+.*$', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*---+\s*$', multiLine: true), '')
      .replaceAll('**', '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  /// The same audio, in the shape the player already understands.
  ///
  /// The player, the loop button, the speed control, the background music and
  /// the read-along clock are all built around [Story], and every one of them
  /// applies here unchanged. Writing a second controller and a second player
  /// screen to avoid one adapter would be two more places for the music to
  /// forget to pause.
  ///
  /// The conversion is one-way and only for playback. Nothing writes a
  /// manifestation back through the story library, which is why the id keeps
  /// its `manifest_` prefix — anything that did would be visible immediately.
  Story asStory() => Story(
    id: id,
    title: dream,
    intention: Intention.peace,
    script: readable,
    duration: duration,
    voice: 'elevenlabs',
    createdAt: createdAt,
    audioUrl: audioUrl,
  );

  Manifestation copyWith({String? audioUrl, Duration? duration}) =>
      Manifestation(
        id: id,
        dream: dream,
        script: script,
        duration: duration ?? this.duration,
        createdAt: createdAt,
        audioUrl: audioUrl ?? this.audioUrl,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'dream': dream,
    'script': script,
    'durationSeconds': duration.inSeconds,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'audioUrl': audioUrl,
  };

  factory Manifestation.fromMap(Map<String, dynamic> map) => Manifestation(
    id: map['id'] as String? ?? '',
    dream: map['dream'] as String? ?? map['title'] as String? ?? '',
    script: map['script'] as String? ?? '',
    duration: Duration(seconds: (map['durationSeconds'] as num?)?.toInt() ?? 0),
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    audioUrl: map['audioUrl'] as String?,
  );
}
