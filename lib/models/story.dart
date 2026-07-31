import 'intention.dart';

/// One generated audio narrative.
///
/// [audioUrl] stays null until the text-to-speech step has run; the player
/// falls back to reading the script on screen so a story is never unusable
/// while its audio is still being produced.
class Story {
  const Story({
    required this.id,
    required this.title,
    required this.intention,
    required this.script,
    required this.duration,
    required this.voice,
    required this.createdAt,
    this.audioUrl,
    this.favorite = false,
  });

  final String id;
  final String title;
  final Intention intention;
  final String script;
  final Duration duration;
  final String voice;
  final DateTime createdAt;
  final String? audioUrl;
  final bool favorite;

  bool get hasAudio => audioUrl != null;

  String get durationLabel => '${duration.inMinutes} min';

  Story copyWith({
    String? audioUrl,
    bool? favorite,
    Duration? duration,
    String? voice,
  }) => Story(
    id: id,
    title: title,
    intention: intention,
    script: script,
    duration: duration ?? this.duration,
    voice: voice ?? this.voice,
    createdAt: createdAt,
    audioUrl: audioUrl ?? this.audioUrl,
    favorite: favorite ?? this.favorite,
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'intention': intention.name,
    'script': script,
    'durationSeconds': duration.inSeconds,
    'voice': voice,
    'createdAt': createdAt.toIso8601String(),
    'audioUrl': audioUrl,
    'favorite': favorite,
  };

  factory Story.fromMap(String id, Map<String, dynamic> map) => Story(
    id: id,
    title: map['title'] as String? ?? 'Untitled story',
    intention: Intention.fromName(map['intention'] as String? ?? 'career'),
    script: map['script'] as String? ?? '',
    duration: Duration(seconds: (map['durationSeconds'] as num?)?.toInt() ?? 0),
    voice: map['voice'] as String? ?? 'marin',
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    audioUrl: map['audioUrl'] as String?,
    favorite: map['favorite'] as bool? ?? false,
  );
}
