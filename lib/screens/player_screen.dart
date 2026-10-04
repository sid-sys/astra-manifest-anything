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
import '../widgets/report_content.dart';
import '../widgets/session_feedback.dart';

/// Full-screen playback.
///
/// Three bands: a fixed header, the story scrolling in the middle, and the
/// transport pinned to the bottom. The transport used to scroll with
/// everything else, which meant the script auto-scrolling to the line being
/// spoken carried the pause button off the screen — the one control you reach
/// for while listening was the one you had to go hunting for.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  /// Rolled once, when the screen opens.
  ///
  /// Not read inside `build`: a fresh roll on every rebuild would make the card
  /// appear and vanish as the position ticked, which is the one thing more
  /// annoying than being asked every time.
  late final bool _askForFeedback = SessionFeedback.shouldAsk();

  /// Set when the audio reaches the end. The question is asked *after* the
  /// session, never during it — a mood card sliding in over a meditation is
  /// the opposite of what the meditation was for.
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);

    // "Finished" means the audio actually ran out, not that the user scrubbed
    // near the end — hence the position check against a real duration rather
    // than a progress fraction, which is 1.0 for a moment on an empty track.
    final done = playback.state.duration > Duration.zero &&
        playback.state.position >= playback.state.duration -
            const Duration(seconds: 2);
    if (done && !_finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _finished = true);
      });
    }
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
                onReport: () => reportContent(
                  context,
                  ref,
                  kind: 'story',
                  contentId: story.id,
                  excerpt: '${story.title}\n\n${story.script}',
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  children: [
                    const SizedBox(height: AstraSpacing.md),
                    Center(child: _Orb(story: story, playing: state.playing)),
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
                    // Asked after the session, and only sometimes.
                    //
                    // Both conditions matter. Asking during a meditation is
                    // the opposite of what the meditation is for, and asking
                    // after every single one turns the question into
                    // furniture — people learn its shape and tap the middle
                    // answer to clear it, which produces data that looks real
                    // and is not.
                    if (_finished && _askForFeedback) ...[
                      const SizedBox(height: AstraSpacing.lg),
                      SessionFeedback(about: story.id),
                    ],
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
    required this.onReport,
  });

  final Story story;
  final VoidCallback onClose;
  final VoidCallback onFavorite;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        // A cross, not a chevron. The chevron promised a minimise, and this
        // stops playback outright.
        icon: const AstraIcon('ui_close', size: 28),
        onPressed: onClose,
        tooltip: 'Close player',
      ),
      Expanded(child: Wordmark('Now Playing')),
      ReportButton(onTap: onReport),
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
  const _Orb({required this.story, required this.playing});

  final Story story;

  /// Turns only while the audio does. A sphere revolving over a paused player
  /// says the app is doing something when it is not, and the stillness is a
  /// clearer "paused" than the icon on the button.
  final bool playing;

  @override
  Widget build(BuildContext context) => AstraMascot(
    // Listening while it plays, asleep when it is paused. She bobs only while
    // there is sound, so stillness reads as "paused" the way the orb's did.
    playing ? 'mascot_listen' : 'mascot_sleep',
    size: 168,
    still: !playing,
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
    decoration: BoxDecoration(
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
                asset: 'ui_repeat',
                active: state.looping,
                tooltip: state.looping ? 'Loop on' : 'Loop',
                onTap: playback.toggleLoop,
              ),
              _ControlButton(
                asset: 'ui_rewind',
                caption: '10',
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
                asset: 'ui_forward',
                caption: '30',
                tooltip: 'Forward 30 seconds',
                onTap: () => playback.skip(const Duration(seconds: 30)),
              ),
              _SpeedButton(speed: state.speed, onTap: playback.cycleSpeed),
            ],
          ),

          // The music under the voice, and how loud it sits.
          //
          // A slider rather than a fixed level, because the right amount of
          // music depends on the room, the phone and the person — and because
          // some people want the words alone.
          const SizedBox(height: AstraSpacing.md),
          Row(
            children: [
              _ControlButton(
                asset: 'ui_music',
                faded: !playback.bedOn,
                tooltip: playback.bedOn ? 'Music on' : 'Music off',
                onTap: playback.toggleBed,
              ),
              Expanded(
                child: Slider(
                  value: playback.bedVolume,
                  max: 0.5,
                  activeColor: AstraColors.accent,
                  inactiveColor: AstraColors.line,
                  onChanged: playback.bedOn
                      ? (value) => playback.setBedVolume(value)
                      : null,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${(playback.bedVolume * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: AstraTextStyles.small,
                ),
              ),
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
    required this.asset,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final String asset;
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
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AstraColors.accent.withValues(alpha: 0.22)
                : Colors.transparent,
            border: Border.all(
              color: active ? AstraColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: AstraIcon(asset, size: 36, opacity: active ? 1 : 0.55),
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
        child: SizedBox(
          width: 76,
          height: 76,
          child: Center(
            child: recording
                ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AstraColors.accent,
                    ),
                  )
                : AstraIcon(playing ? 'ui_pause' : 'ui_play', size: 72),
          ),
        ),
      ),
    ),
  );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.asset,
    required this.tooltip,
    required this.onTap,
    this.caption,
    this.faded = false,
  });

  /// The picture, from `assets/icons`.
  final String asset;
  final String tooltip;
  final VoidCallback onTap;

  /// A short number printed over the corner of the picture — the 10 and 30 in
  /// "back 10 seconds" and "forward 30". The pictures carry no text of their
  /// own, so the number is the only thing that says how far a tap goes.
  final String? caption;
  final bool faded;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AstraIcon(asset, size: 44, opacity: faded ? 0.4 : 1),
            if (caption != null)
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AstraColors.canvasRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AstraColors.line),
                  ),
                  child: Text(
                    caption!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AstraColors.text,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
