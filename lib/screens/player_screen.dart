import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/story_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/starfield.dart';

/// Full-screen playback: scrub, loop, queue, and — while the narration audio
/// is still being produced — the script to read along with.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final state = playback.state;
    final playing = state.story;

    // PlaybackState holds the story as it was when playback started, so the
    // favourite and offline flags on it go stale the moment either is toggled.
    // The library is the live copy — read from there and fall back to the
    // snapshot only if this story is not in it.
    final story = playing == null
        ? null
        : ref.watch(storiesProvider).firstWhere(
            (candidate) => candidate.id == playing.id,
            orElse: () => playing,
          );

    if (story == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const EmptyState(
          glyph: '✦',
          title: 'Nothing playing',
          body: 'Pick a story from your library and it will appear here.',
        ),
      );
    }

    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    color: AstraColors.dim,
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Close player',
                  ),
                  Expanded(child: Wordmark('Now Playing')),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: AstraSpacing.screenPadding,
                  children: [
                    const SizedBox(height: AstraSpacing.lg),
                    Center(
                      child: Container(
                        width: 148,
                        height: 148,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AstraColors.line),
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.4),
                            colors: [Color(0xFF2A3160), AstraColors.inkRaised],
                          ),
                        ),
                        child: Text(
                          story.intention.glyph,
                          style: TextStyle(
                            fontSize: 42,
                            color: story.intention.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AstraSpacing.lg),
                    Text(
                      story.title,
                      textAlign: TextAlign.center,
                      style: AstraTextStyles.display(22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${story.intention.label} · ${voiceLabel(story.voice)} · '
                      '${story.durationLabel}',
                      textAlign: TextAlign.center,
                      style: AstraTextStyles.small,
                    ),
                    const SizedBox(height: AstraSpacing.xl),

                    _Waveform(progress: state.progress),
                    const SizedBox(height: AstraSpacing.md),

                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: AstraColors.gold,
                        inactiveTrackColor: AstraColors.line,
                        thumbColor: AstraColors.gold,
                        overlayColor: AstraColors.gold.withValues(alpha: 0.12),
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: state.progress,
                        onChanged: (value) => playback.seek(
                          state.duration * value,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_clock(state.position),
                              style: AstraTextStyles.small),
                          Text(_clock(state.duration),
                              style: AstraTextStyles.small),
                        ],
                      ),
                    ),
                    const SizedBox(height: AstraSpacing.lg),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ControlButton(
                          icon: Icons.replay_10_rounded,
                          tooltip: 'Back 10 seconds',
                          onTap: () =>
                              playback.skip(const Duration(seconds: -10)),
                        ),
                        const SizedBox(width: 18),
                        _PlayButton(
                          playing: state.playing,
                          onTap: playback.toggle,
                        ),
                        const SizedBox(width: 18),
                        _ControlButton(
                          icon: Icons.forward_30_rounded,
                          tooltip: 'Forward 30 seconds',
                          onTap: () =>
                              playback.skip(const Duration(seconds: 30)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AstraSpacing.lg),

                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AstraSpacing.sm,
                      runSpacing: AstraSpacing.sm,
                      children: [
                        TagChip(
                          label: state.looping ? '∞  Loop on' : '∞  Loop',
                          selected: state.looping,
                          onTap: playback.toggleLoop,
                        ),
                        TagChip(
                          label: state.queue.isEmpty
                              ? 'Queue empty'
                              : '${state.queue.length} up next',
                          selected: state.queue.isNotEmpty,
                          onTap: state.queue.isEmpty ? null : playback.next,
                        ),
                        TagChip(
                          label: '${_rate(state.speed)}  Speed',
                          selected: state.speed != 1.0,
                          onTap: playback.cycleSpeed,
                        ),
                        TagChip(
                          label: story.favorite ? '♥  Favourite' : '♡  Favourite',
                          selected: story.favorite,
                          onTap: () => ref
                              .read(storiesProvider.notifier)
                              .toggleFavorite(story),
                        ),
                        TagChip(
                          label: story.downloaded ? '✓  Offline' : '↓  Offline',
                          selected: story.downloaded,
                          onTap: () => ref
                              .read(storiesProvider.notifier)
                              .toggleDownloaded(story),
                        ),
                      ],
                    ),
                    const SizedBox(height: AstraSpacing.xl),

                    // Always shown, not only when the audio is missing. Some
                    // people read along, some prefer reading to listening, and
                    // hiding the words behind a failure state served neither.
                    AstraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story.hasAudio ? 'READ ALONG' : 'READ IT',
                            style: AstraTextStyles.eyebrow,
                          ),
                          const SizedBox(height: AstraSpacing.sm),
                          SelectableText(
                            story.script.trim(),
                            style: AstraTextStyles.body.copyWith(height: 1.7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AstraSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `1x`, `1.25x` — trailing zeros dropped so the chip stays narrow.
  static String _rate(double speed) {
    final text = speed.toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '${text}x';
  }

  static String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: playing ? 'Pause' : 'Play',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 66,
        height: 66,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AstraColors.goldGradient,
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 32,
          color: const Color(0xFF14101F),
        ),
      ),
    ),
  );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AstraColors.cardRaised,
          border: Border.all(color: AstraColors.line),
        ),
        child: Icon(icon, size: 22, color: AstraColors.gold),
      ),
    ),
  );
}

/// Decorative level meter. The bars left of the playhead are lit gold; the
/// rest stay violet and dim, so progress reads at a glance without numbers.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.progress});

  final double progress;

  static const _barCount = 34;

  @override
  Widget build(BuildContext context) {
    final random = Random(11);
    final heights = List.generate(
      _barCount,
      (_) => 0.22 + random.nextDouble() * 0.78,
    );
    final litUpTo = (progress * _barCount).round();

    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _barCount; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: FractionallySizedBox(
                  heightFactor: heights[i],
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: i < litUpTo
                          ? AstraColors.gold
                          : AstraColors.violet.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
