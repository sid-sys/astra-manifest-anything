import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';

/// The script, with the line being spoken lit and the rest dimmed.
///
/// The timing is proportional: each line gets a share of the running time
/// equal to its share of the words. That is an approximation — the narrator
/// pauses at paragraph breaks and does not read every word at the same speed —
/// but it needs no timing data from the TTS, which does not return any, and it
/// stays honest across a whole story because the errors do not accumulate.
class ScriptView extends StatefulWidget {
  const ScriptView({
    super.key,
    required this.script,
    required this.position,
    required this.duration,
    this.following = true,
  });

  final String script;
  final Duration position;
  final Duration duration;

  /// Whether to scroll the lit line into view. False when nothing is playing,
  /// so a reader scrolling ahead is not dragged back.
  final bool following;

  @override
  State<ScriptView> createState() => _ScriptViewState();
}

class _ScriptViewState extends State<ScriptView> {
  final _lineKeys = <int, GlobalKey>{};
  int _lastScrolledTo = -1;

  @override
  void didUpdateWidget(ScriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.following) return;

    final active = _activeLine;
    if (active != _lastScrolledTo) {
      _lastScrolledTo = active;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(active));
    }
  }

  List<String> get _lines => splitScript(widget.script);

  int get _activeLine {
    final lines = _lines;
    if (lines.isEmpty || widget.duration == Duration.zero) return -1;

    final progress =
        widget.position.inMilliseconds / widget.duration.inMilliseconds;
    final counts = lines.map(_wordCount).toList();
    final total = counts.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) return -1;

    var spoken = 0;
    for (var i = 0; i < lines.length; i++) {
      spoken += counts[i];
      if (spoken / total > progress) return i;
    }
    return lines.length - 1;
  }

  void _reveal(int line) {
    final key = _lineKeys[line];
    final context = key?.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      alignment: 0.35,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final active = _activeLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            key: _lineKeys.putIfAbsent(i, GlobalKey.new),
            padding: const EdgeInsets.only(bottom: 10),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: AstraTextStyles.body.copyWith(
                height: 1.65,
                fontSize: 15.5,
                color: i == active
                    ? AstraColors.text
                    : AstraColors.dim.withValues(alpha: 0.62),
                fontWeight: i == active ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(lines[i]),
            ),
          ),
      ],
    );
  }

  static int _wordCount(String line) =>
      line.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

/// Breaks a script into the units that light up one at a time.
///
/// Sentences rather than paragraphs: a paragraph can run twenty seconds, and
/// a highlight that sits still that long stops looking like it is tracking
/// anything. Split points keep their punctuation so nothing reads as clipped.
List<String> splitScript(String script) {
  final lines = <String>[];

  for (final paragraph in script.split(RegExp(r'\n\s*\n'))) {
    final trimmed = paragraph.trim();
    if (trimmed.isEmpty) continue;

    final buffer = StringBuffer();
    for (final piece in trimmed.split(RegExp(r'(?<=[.!?])\s+'))) {
      final sentence = piece.trim();
      if (sentence.isEmpty) continue;

      // Very short sentences ride along with the next one — "I said yes."
      // alone on a line flashes past too quickly to read.
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(sentence);

      if (_ScriptViewState._wordCount(buffer.toString()) >= 6) {
        lines.add(buffer.toString());
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) lines.add(buffer.toString());
  }

  return lines;
}
