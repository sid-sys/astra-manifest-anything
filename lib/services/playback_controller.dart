import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/story.dart';

@immutable
class PlaybackState {
  const PlaybackState({
    this.story,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.looping = false,
    this.queue = const [],
  });

  final Story? story;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool looping;

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
    List<Story>? queue,
  }) => PlaybackState(
    story: story ?? this.story,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    looping: looping ?? this.looping,
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
    _player.positionStream.listen((position) {
      if (_usingVirtualClock) return;
      _state = _state.copyWith(position: position);
      notifyListeners();
    });

    _player.playerStateStream.listen((playerState) {
      if (_usingVirtualClock) return;
      if (playerState.processingState == ProcessingState.completed) {
        _onCompleted();
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  Timer? _virtualClock;
  bool _usingVirtualClock = false;

  PlaybackState _state = const PlaybackState();
  PlaybackState get state => _state;

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

    if (story.hasAudio) {
      _usingVirtualClock = false;
      try {
        await _player.setUrl(story.audioUrl!);
        await _player.setLoopMode(_state.looping ? LoopMode.one : LoopMode.off);
        await _player.play();
        return;
      } catch (error) {
        debugPrint('Astra: audio failed, reading script instead — $error');
      }
    }

    _startVirtualClock();
  }

  Future<void> toggle() async {
    if (!_state.hasStory) return;

    final nextPlaying = !_state.playing;
    _state = _state.copyWith(playing: nextPlaying);
    notifyListeners();

    if (_usingVirtualClock) {
      nextPlaying ? _startVirtualClock() : _virtualClock?.cancel();
      return;
    }

    nextPlaying ? await _player.play() : await _player.pause();
  }

  Future<void> seek(Duration position) async {
    _state = _state.copyWith(position: position);
    notifyListeners();
    if (!_usingVirtualClock) await _player.seek(position);
  }

  Future<void> skip(Duration delta) =>
      seek(_clamp(_state.position + delta));

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
    super.dispose();
  }
}
