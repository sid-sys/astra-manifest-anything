import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/story.dart';
import 'maya_audio_handler.dart';

@immutable
class PlaybackState {
  const PlaybackState({
    this.story,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.looping = false,
    this.speed = 1.0,
    this.queue = const [],
  });

  final Story? story;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool looping;

  /// Playback rate. Applies to real audio only — the read-along clock runs at
  /// the same rate regardless, since there is nothing to speed up.
  final double speed;

  /// Stories that play after the current one, in order.
  final List<Story> queue;

  bool get hasStory => story != null;

  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  PlaybackState copyWith({
    Story? story,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? looping,
    double? speed,
    List<Story>? queue,
  }) => PlaybackState(
    story: story ?? this.story,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    looping: looping ?? this.looping,
    speed: speed ?? this.speed,
    queue: queue ?? this.queue,
  );
}

/// Drives story playback, with looping and a queue — the two things reviewers
/// of the app this one is modelled on kept asking for.
///
/// A story whose text-to-speech hasn't finished yet has no [Story.audioUrl].
/// Rather than refusing to play it, the controller runs a virtual clock at the
/// story's intended length so the script can be read along on screen. Both
/// modes present the identical state to the UI.
class PlaybackController extends ChangeNotifier {
  PlaybackController() {
    // The notification's buttons call straight back into the methods below —
    // never into the platform player directly, so every route a press can
    // take goes through the same state machine a tap on screen does.
    mayaAudioHandler?.attach(
      onPlay: resume,
      onPause: pauseOnly,
      onStop: close,
      onSeek: seek,
      onSkipForward: () => skip(const Duration(seconds: 30)),
      onSkipBack: () => skip(const Duration(seconds: -10)),
    );

    _player.positionStream.listen((position) {
      if (_usingVirtualClock) return;
      _state = _state.copyWith(position: position);
      notifyListeners();
    });

    // The file is the final authority on its own length. The stored duration is
    // measured server-side and should agree, but if it ever drifts the scrub
    // bar must follow the audio rather than the metadata.
    _player.durationStream.listen((duration) {
      if (_usingVirtualClock || duration == null) return;
      _state = _state.copyWith(duration: duration);
      notifyListeners();
    });

    _player.playerStateStream.listen((playerState) {
      // The bed mirrors the voice, from the voice player's own state rather
      // than from calls placed next to each play and pause.
      //
      // Driving it by hand meant every new route through the controller was a
      // chance to forget one, and one was forgotten: pausing left the music
      // running under a voice that had stopped. There is only one thing the
      // music has to agree with, so it reads that thing directly.
      unawaited(_syncBed(playerState.playing));

      // The single source of truth for whether the voice is playing.
      //
      // `toggle` used to be the only place `_state.playing` was ever set —
      // flipped the instant the button was tapped, before the platform
      // player had actually answered. That worked as long as the player
      // agreed within a frame, and failed the moment it did not: a pause
      // command that took a beat to land, or one dropped entirely by the
      // platform layer, left the icon showing "paused" over audio that was
      // still audibly running, with nothing to correct it until another tap
      // happened to cancel it out. Reading it from the stream instead means
      // the icon can never say anything the player itself is not also
      // saying, no matter how a command in flight resolves.
      if (!_usingVirtualClock && _state.playing != playerState.playing) {
        _state = _state.copyWith(playing: playerState.playing);
        notifyListeners();
      }

      _pushNotificationState();

      if (_usingVirtualClock) return;
      if (playerState.processingState == ProcessingState.completed) {
        _onCompleted();
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();

  /// The music under the voice.
  ///
  /// A second player rather than a track mixed into the narration, and the
  /// reason is that mixing is permanent. Baked into the MP3, the bed is in
  /// every story ever made, at one fixed volume, for good — and the stories
  /// already written would never have it at all. Kept apart, it plays under
  /// everything including the back catalogue, and turning it off is a flag
  /// rather than re-rendering an archive.
  ///
  /// It also costs nothing: the file ships with the app, so there is no
  /// storage, no bandwidth, and no second thing that can fail to download.
  final AudioPlayer _bed = AudioPlayer();

  bool _bedReady = false;

  /// Whether music plays under the narration. On by default.
  bool get bedOn => _bedOn;
  bool _bedOn = true;

  /// Loads the bed once, lazily. A story that starts before the file is ready
  /// simply starts without it rather than waiting.
  Future<void> _prepareBed() async {
    if (_bedReady) return;
    try {
      await _bed.setAsset('assets/audio/meditation_bed.mp3');
      await _bed.setLoopMode(LoopMode.one);
      await _bed.setVolume(_bedVolume);
      _bedReady = true;
    } catch (error) {
      // Never let the music break the words. A missing or unplayable bed
      // leaves the narration exactly as it was.
      debugPrint('Maya: could not load the background bed — $error');
    }
  }

  /// Matches the bed to whatever the voice is doing right now.
  Future<void> _syncBed(bool playing) async {
    if (!_bedOn || !playing) {
      if (_bedReady) {
        try {
          await _bed.pause();
        } catch (_) {
          // Nothing loaded yet. Silence is already the desired state.
        }
      }
      return;
    }

    await _prepareBed();
    if (!_bedReady) return;

    try {
      await _bed.setVolume(_bedVolume);
      await _bed.play();
    } catch (error) {
      debugPrint('Maya: background bed failed — $error');
    }
  }

  /// Turns the music under the voice on or off, from wherever it is now.
  Future<void> toggleBed() async {
    _bedOn = !_bedOn;
    notifyListeners();
    await _syncBed(_state.playing);
  }

  /// How loud the bed sits under the voice, 0 to 1.
  ///
  /// Adjustable rather than fixed because the right level depends on the room,
  /// the phone and the person — and because a number chosen once by whoever
  /// wrote the code is usually wrong for everybody else.
  double get bedVolume => _bedVolume;
  double _bedVolume = 0.10;

  Future<void> setBedVolume(double value) async {
    _bedVolume = value.clamp(0.0, 1.0);
    notifyListeners();
    if (_bedReady) {
      try {
        await _bed.setVolume(_bedVolume);
      } catch (error) {
        debugPrint('Maya: could not set bed volume — $error');
      }
    }
  }
  Timer? _virtualClock;
  bool _usingVirtualClock = false;

  PlaybackState _state = const PlaybackState();
  PlaybackState get state => _state;

  /// Puts a story on screen without starting it.
  ///
  /// Used for a story whose narration is still recording: the reader gets the
  /// words immediately, and nothing pretends to play until there is audio.
  void load(Story story, {List<Story> queue = const []}) {
    _stopVirtualClock();
    _usingVirtualClock = false;
    _state = _state.copyWith(
      story: story,
      queue: queue,
      position: Duration.zero,
      duration: story.duration,
      playing: false,
    );
    notifyListeners();
    _pushMediaItem(story);
  }

  /// Opens a story ready to play, and waits for the user to press play.
  ///
  /// The difference from [play] is one line, and it is the one the user asked
  /// for: tapping a title in the library used to start the audio immediately,
  /// which is the wrong default for something you listen to with your eyes
  /// closed. Opening a story and starting it are two decisions.
  ///
  /// The source is still loaded here, unlike [load], so the play button has
  /// something to play the instant it is pressed.
  Future<void> open(Story story, {List<Story> queue = const []}) async {
    _stopVirtualClock();

    _state = _state.copyWith(
      story: story,
      queue: queue,
      position: Duration.zero,
      duration: story.duration,
      playing: false,
    );
    notifyListeners();
    _pushMediaItem(story);

    if (!story.hasAudio) {
      _usingVirtualClock = true;
      return;
    }

    _usingVirtualClock = false;
    try {
      await _player.setUrl(story.audioUrl!);
      await _player.setLoopMode(_state.looping ? LoopMode.one : LoopMode.off);
      await _player.setSpeed(_state.speed);
    } catch (error) {
      debugPrint('Maya: audio failed, reading script instead — $error');
      _usingVirtualClock = true;
    }
    _pushNotificationState();
  }

  Future<void> play(Story story, {List<Story> queue = const []}) async {
    _stopVirtualClock();

    _state = _state.copyWith(
      story: story,
      queue: queue,
      position: Duration.zero,
      duration: story.duration,
      playing: true,
    );
    notifyListeners();
    _pushMediaItem(story);

    if (story.hasAudio) {
      _usingVirtualClock = false;
      try {
        await _player.setUrl(story.audioUrl!);
        await _player.setLoopMode(_state.looping ? LoopMode.one : LoopMode.off);
        await _player.setSpeed(_state.speed);
        await _player.play();
        _pushNotificationState();
        return;
      } catch (error) {
        debugPrint('Maya: audio failed, reading script instead — $error');
      }
    }

    _startVirtualClock();
    _pushNotificationState();
  }

  /// Attaches narration that finished after the story was already open.
  ///
  /// The story is written first and recorded second, so the player is usually
  /// showing the script by the time the audio lands. This swaps the source in
  /// underneath without disturbing the reader: nothing starts playing that was
  /// not already playing, and the position is kept.
  Future<void> adoptAudio(Story story) async {
    if (_state.story?.id != story.id || !story.hasAudio) return;

    final resumeAt = _state.position;
    final wasPlaying = _state.playing;

    _stopVirtualClock();
    _usingVirtualClock = false;
    _state = _state.copyWith(story: story, duration: story.duration);
    notifyListeners();
    _pushMediaItem(story);

    try {
      await _player.setUrl(story.audioUrl!);
      await _player.setLoopMode(_state.looping ? LoopMode.one : LoopMode.off);
      await _player.setSpeed(_state.speed);
      if (resumeAt > Duration.zero) await _player.seek(resumeAt);
      if (wasPlaying) await _player.play();
    } catch (error) {
      debugPrint('Maya: could not attach narration — $error');
      if (wasPlaying) _startVirtualClock();
    }
    _pushNotificationState();
  }

  /// Stops playback and clears the player.
  ///
  /// Closing means closing. The player used to leave the story loaded and a
  /// mini bar playing on, so the close button read as a minimise — audio kept
  /// going after the screen that owned it was gone, with no obvious way to
  /// stop it.
  Future<void> close() async {
    _stopVirtualClock();
    _usingVirtualClock = false;
    _state = const PlaybackState();
    notifyListeners();

    try {
      await _player.stop();
      await _bed.pause();
    } catch (error) {
      debugPrint('Maya: could not stop the player — $error');
    }
    // Clears the notification rather than leaving it on a story that no
    // longer plays — the one thing a "stopped" card must never show is a
    // pause button over silence.
    mayaAudioHandler?.mediaItem.add(null);
    _pushNotificationState();
  }

  /// True while a play/pause command is already in flight.
  ///
  /// A second tap that lands before the first has resolved used to compute
  /// its own "next" state from `_state.playing`, which the first tap had
  /// already flipped optimistically — so a fast double-tap could read as
  /// pause-then-play or play-then-pause depending on timing, sending the
  /// platform player two commands in a row it was never asked to reconcile.
  /// Dropped instead: the tap that lands mid-command is the one that loses.
  bool _toggling = false;

  Future<void> toggle() async {
    if (!_state.hasStory || _toggling) return;
    await (_state.playing ? pauseOnly() : resume());
  }

  /// Starts or resumes, unconditionally. Unlike [toggle], never flips —
  /// called from the notification's play button, which always means "play",
  /// never "whatever the other one wasn't doing".
  Future<void> resume() async {
    if (!_state.hasStory || _toggling) return;
    _toggling = true;
    try {
      _state = _state.copyWith(playing: true);
      notifyListeners();
      if (_usingVirtualClock) {
        _startVirtualClock();
        _pushNotificationState();
        return;
      }
      await _player.play();
    } finally {
      _toggling = false;
    }
  }

  /// Pauses, unconditionally — the notification's pause button's other half.
  Future<void> pauseOnly() async {
    if (!_state.hasStory || _toggling) return;
    _toggling = true;
    try {
      _state = _state.copyWith(playing: false);
      notifyListeners();
      if (_usingVirtualClock) {
        _virtualClock?.cancel();
        _pushNotificationState();
        return;
      }
      await _player.pause();
    } finally {
      _toggling = false;
    }
  }

  Future<void> seek(Duration position) async {
    _state = _state.copyWith(position: position);
    notifyListeners();
    if (!_usingVirtualClock) await _player.seek(position);
    _pushNotificationState();
  }

  Future<void> skip(Duration delta) =>
      seek(_clamp(_state.position + delta));

  /// The rates the player cycles through. Nothing below 1 — these are already
  /// narrated slowly, and slower turns the voice into a drone.
  static const speeds = [1.0, 1.25, 1.5, 0.75];

  /// Advances to the next rate and returns it.
  Future<void> cycleSpeed() async {
    final next = speeds[(speeds.indexOf(_state.speed) + 1) % speeds.length];
    _state = _state.copyWith(speed: next);
    notifyListeners();
    if (!_usingVirtualClock) await _player.setSpeed(next);
  }

  Future<void> toggleLoop() async {
    final looping = !_state.looping;
    _state = _state.copyWith(looping: looping);
    notifyListeners();
    if (!_usingVirtualClock) {
      await _player.setLoopMode(looping ? LoopMode.one : LoopMode.off);
    }
  }

  Future<void> next() async {
    if (_state.queue.isEmpty) return;
    final [upcoming, ...rest] = _state.queue;
    await play(upcoming, queue: rest);
  }

  void enqueue(Story story) {
    _state = _state.copyWith(queue: [..._state.queue, story]);
    notifyListeners();
  }

  Duration _clamp(Duration value) {
    if (value < Duration.zero) return Duration.zero;
    if (value > _state.duration) return _state.duration;
    return value;
  }

  void _startVirtualClock() {
    _usingVirtualClock = true;
    _virtualClock?.cancel();
    _virtualClock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final next = _state.position + const Duration(milliseconds: 250);
      if (next >= _state.duration) {
        _onCompleted();
        return;
      }
      _state = _state.copyWith(position: next);
      notifyListeners();
    });
  }

  void _stopVirtualClock() {
    _virtualClock?.cancel();
    _virtualClock = null;
  }

  void _onCompleted() {
    if (_state.looping && _state.hasStory) {
      _state = _state.copyWith(position: Duration.zero);
      notifyListeners();
      if (_usingVirtualClock) _startVirtualClock();
      return;
    }

    if (_state.queue.isNotEmpty) {
      unawaited(next());
      return;
    }

    _stopVirtualClock();
    _state = _state.copyWith(playing: false, position: _state.duration);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopVirtualClock();
    _player.dispose();
    _bed.dispose();
    super.dispose();
  }

  /// Tells the notification what is on screen. Called whenever a story
  /// changes, never on every tick — the title and duration are the only
  /// things about a story that are ever wrong until the next one loads.
  void _pushMediaItem(Story story) {
    mayaAudioHandler?.mediaItem.add(
      audio_service.MediaItem(
        id: story.id,
        title: story.title,
        album: 'Maya',
        duration: story.duration,
      ),
    );
  }

  /// Tells the notification what the player is doing right now — playing or
  /// not, and from where, so the card's own clock can keep ticking between
  /// pushes without this having to fire every second.
  void _pushNotificationState() {
    mayaAudioHandler?.playbackState.add(
      audio_service.PlaybackState(
        controls: [
          audio_service.MediaControl.rewind,
          _state.playing
              ? audio_service.MediaControl.pause
              : audio_service.MediaControl.play,
          audio_service.MediaControl.fastForward,
          audio_service.MediaControl.stop,
        ],
        systemActions: const {
          audio_service.MediaAction.seek,
          audio_service.MediaAction.seekForward,
          audio_service.MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _state.hasStory
            ? audio_service.AudioProcessingState.ready
            : audio_service.AudioProcessingState.idle,
        playing: _state.playing,
        updatePosition: _state.position,
        speed: _state.speed,
      ),
    );
  }
}
