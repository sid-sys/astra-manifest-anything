import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story.dart';
import '../providers.dart';
import '../services/playback_controller.dart';
import '../services/story_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/script_view.dart';
import '../widgets/aura_background.dart';

/// Full-screen playback.
///
/// Three bands: a fixed header, the story scrolling in the middle, and the
/// transport pinned to the bottom. The transport used to scroll with
/// everything else, which meant the script auto-scrolling to the line being
/// spoken carried the pause button off the screen — the one control you reach
/// for while listening was the one you had to go hunting for.
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
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                story: story,
                onClose: () {
                  playback.close();
                  Navigator.of(context).maybePop();
                },
                onFavorite: () =>
                    ref.read(storiesProvider.notifier).toggleFavorite(story),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  children: [
                    const SizedBox(height: AstraSpacing.md),
                    Center(child: _Orb(story: story)),
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
                    const SizedBox(height: AstraSpacing.lg),

                    if (state.queue.isNotEmpty)
                      Center(
                        child: TagChip(
                          label: '${state.queue.length} up next',
                          selected: true,
                          onTap: playback.next,
                        ),
                      ),
                    const SizedBox(height: AstraSpacing.lg),

                    // Always shown, not only when the audio is missing. The
                    // story is written before it is narrated, so this is what
                    // the reader has for the first minute — and some people
                    // prefer reading to listening anyway.
                    AstraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story.hasAudio ? 'READ ALONG' : 'YOUR STORY',
                            style: AstraTextStyles.eyebrow,
                          ),
                          const SizedBox(height: AstraSpacing.md),
                          ScriptView(
                            script: story.script,
                            position: state.position,
                            duration: state.duration,
                            following: state.playing,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AstraSpacing.lg),
                  ],
                ),
              ),
              _Transport(story: story, state: state, playback: playback),
            ],
          ),
        ),
      ),
    );
  }
}

/// Close, wordmark, and the favourite toggle.
class _Header extends StatelessWidget {
  const _Header({
    required this.story,
    required this.onClose,
    required this.onFavorite,
  });

  final Story story;
  final VoidCallback onClose;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        // A cross, not a chevron. The chevron promised a minimise, and this
        // stops playback outright.
        icon: const Icon(Icons.close_rounded),
        color: AstraColors.dim,
        onPressed: onClose,
        tooltip: 'Close player',
      ),
      Expanded(child: Wordmark('Now Playing')),
      IconButton(
        icon: Icon(
          story.favorite ? Icons.favorite : Icons.favorite_border,
          color: story.favorite ? AstraColors.accent : AstraColors.dim,
        ),
        onPressed: onFavorite,
        tooltip: story.favorite ? 'Remove from favourites' : 'Add to favourites',
      ),
    ],
  );
}

class _Orb extends StatelessWidget {
  const _Orb({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) => Container(
    width: 120,
    height: 120,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      // The orb catches the light from the top-left, same as everything else
      // on the wash — a flat disc here would be the only object in the app
      // that is not lit.
      gradient: const RadialGradient(
        center: Alignment(-0.35, -0.45),
        radius: 0.95,
        colors: [Colors.white, AstraColors.auraTop],
      ),
      boxShadow: AstraColors.liftedShadow,
    ),
    child: Text(
      story.intention.glyph,
      style: TextStyle(fontSize: 36, color: story.intention.accent),
    ),
  );
}

/// The pinned control bar: scrubber, times, and everything you press while
/// listening, in one row that never leaves the screen.
class _Transport extends StatelessWidget {
  const _Transport({
    required this.story,
    required this.state,
    required this.playback,
  });

  final Story story;
  final PlaybackState state;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AstraColors.canvasRaised,
      border: Border(top: BorderSide(color: AstraColors.line)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Waveform(progress: state.progress),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AstraColors.accent,
              inactiveTrackColor: AstraColors.line,
              thumbColor: AstraColors.accent,
              overlayColor: AstraColors.accent.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: state.progress,
              onChanged: (value) => playback.seek(state.duration * value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_clock(state.position), style: AstraTextStyles.small),
                Text(_clock(state.duration), style: AstraTextStyles.small),
              ],
            ),
          ),
          const SizedBox(height: AstraSpacing.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _IconToggle(
                icon: Icons.repeat_rounded,
                active: state.looping,
                tooltip: state.looping ? 'Loop on' : 'Loop',
                onTap: playback.toggleLoop,
              ),
              _ControlButton(
                icon: Icons.replay_10_rounded,
                tooltip: 'Back 10 seconds',
                onTap: () => playback.skip(const Duration(seconds: -10)),
              ),
              _PlayButton(
                playing: state.playing,
                // Nothing to play until the narration lands. The button says
                // so rather than sitting there dead.
                recording: !story.hasAudio,
                onTap: playback.toggle,
              ),
              _ControlButton(
                icon: Icons.forward_30_rounded,
                tooltip: 'Forward 30 seconds',
                onTap: () => playback.skip(const Duration(seconds: 30)),
              ),
              _SpeedButton(speed: state.speed, onTap: playback.cycleSpeed),
            ],
          ),

          if (!story.hasAudio) ...[
            const SizedBox(height: AstraSpacing.sm),
            Text(
              'Recording your narration. The words are above to read in the '
              'meantime.',
              textAlign: TextAlign.center,
              style: AstraTextStyles.small,
            ),
          ],
        ],
      ),
    ),
  );

  static String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// An icon that fills in when its setting is on.
///
/// The whole disc changes, not just the glyph's colour. A 22px icon switching
/// between grey and gold is close to unreadable at a glance — you have to
/// compare it against something to know which state you are in, and there is
/// nothing to compare it against.
class _IconToggle extends StatelessWidget {
  const _IconToggle({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      toggled: active,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AstraColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            border: Border.all(
              color: active ? AstraColors.accent : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 21,
            color: active ? AstraColors.accent : AstraColors.dim,
          ),
        ),
      ),
    ),
  );
}

/// Playback rate, printed rather than drawn — `1x` says more than any icon.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.onTap});

  final double speed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Playback speed',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: speed == 1.0
              ? Colors.transparent
              : AstraColors.accent.withValues(alpha: 0.16),
          border: Border.all(
            color: speed == 1.0 ? Colors.transparent : AstraColors.accent,
          ),
        ),
        child: Text(
          _rate(speed),
          style: AstraTextStyles.label.copyWith(
            fontSize: 13,
            color: speed == 1.0 ? AstraColors.dim : AstraColors.accent,
          ),
        ),
      ),
    ),
  );

  /// `1x`, `1.25x` — trailing zeros dropped so the label stays narrow.
  static String _rate(double speed) {
    final text = speed
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '${text}x';
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.onTap,
    this.recording = false,
  });

  final bool playing;
  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: !recording,
    label: recording ? 'Recording narration' : (playing ? 'Pause' : 'Play'),
    child: Opacity(
      opacity: recording ? 0.55 : 1,
      child: InkWell(
        onTap: recording ? null : onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AstraColors.accentGradient,
          ),
          child: recording
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AstraColors.onAccent,
                  ),
                )
              : Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 30,
                  color: AstraColors.onAccent,
                ),
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
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AstraColors.cardRaised,
          border: Border.all(color: AstraColors.line),
        ),
        child: Icon(icon, size: 21, color: AstraColors.accent),
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
      height: 34,
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
                          ? AstraColors.accent
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
