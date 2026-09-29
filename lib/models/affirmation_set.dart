import 'intention.dart';
import 'story.dart';

/// Five affirmations written for one goal.
///
/// A set rather than five loose lines, because the five are written together
/// and only make sense together: the brief asks for a balance of belief,
/// possibility, present experience, progress and gratitude, which is a property
/// of the group. Shuffling one line in from another goal breaks it.
class AffirmationSet {
  const AffirmationSet({
    required this.id,
    required this.goal,
    required this.lines,
    required this.createdAt,
    this.audioUrl,
    this.duration = Duration.zero,
  });

  final String id;

  /// What the user typed, in their own words. The title everywhere it is
  /// listed, and the thing the five lines are about.
  final String goal;

  final List<String> lines;
  final DateTime createdAt;

  /// The five lines read aloud, when narration succeeded. Null for sets
  /// written before audio existed or when narration failed.
  final String? audioUrl;
  final Duration duration;

  bool get hasAudio => audioUrl != null;

  /// The same audio in the shape the player already understands, so loop,
  /// background music and the read-along all apply unchanged.
  Story asStory() => Story(
    id: id,
    title: goal,
    intention: Intention.confidence,
    script: lines.join('\n\n'),
    duration: duration,
    voice: 'sage',
    createdAt: createdAt,
    audioUrl: audioUrl,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'goal': goal,
    'lines': lines,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'audioUrl': audioUrl,
    'durationSeconds': duration.inSeconds,
  };

  factory AffirmationSet.fromMap(Map<String, dynamic> map) => AffirmationSet(
    id: map['id'] as String? ?? '',
    goal: map['goal'] as String? ?? '',
    lines: ((map['lines'] as List?) ?? const [])
        .map((line) => line.toString())
        .where((line) => line.trim().isNotEmpty)
        .toList(),
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    audioUrl: map['audioUrl'] as String?,
    duration: Duration(seconds: (map['durationSeconds'] as num?)?.toInt() ?? 0),
  );
}
