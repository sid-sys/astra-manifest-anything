import 'package:audio_service/audio_service.dart';

/// The one instance the app creates, in `main`, once `AudioService.init`
/// returns it. Null wherever that failed — a platform without the pieces for
/// it, or a plain `flutter run` on a device that has never granted the
/// permission — so [PlaybackController] can read it defensively everywhere
/// and simply not update it rather than crash.
MayaAudioHandler? mayaAudioHandler;

/// Bridges [PlaybackController] to the OS media notification and lock-screen
/// card.
///
/// Built directly against `audio_service` rather than the more convenient
/// `just_audio_background`, and that choice is load-bearing, not a
/// preference. `just_audio_background` hard-caps the whole app at one
/// `AudioPlayer` instance — and this app always runs two: the narration and
/// the background bed underneath it. The first attempt used that package, and
/// it silently broke the bed on every single play: the moment the bed player
/// tried to load, the platform threw "supports only a single player
/// instance" and the bed just never started, with nothing on screen saying
/// so.
///
/// This class never touches how either `AudioPlayer` is constructed. It only
/// mirrors [PlaybackController]'s own state into the notification, and
/// forwards the notification's buttons back into whichever callbacks
/// [attach] was given. Both players keep working exactly as they did before
/// either notification existed.
class MayaAudioHandler extends BaseAudioHandler with SeekHandler {
  _Callbacks? _callbacks;

  /// Wires the notification's buttons to a controller. Called once
  /// [PlaybackController] exists, since the handler itself is built before
  /// that — `AudioService.init` has to run before `runApp`, and the
  /// controller is built lazily behind a Riverpod provider.
  void attach({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onStop,
    required Future<void> Function(Duration) onSeek,
    required Future<void> Function() onSkipForward,
    required Future<void> Function() onSkipBack,
  }) {
    _callbacks = _Callbacks(
      onPlay: onPlay,
      onPause: onPause,
      onStop: onStop,
      onSeek: onSeek,
      onSkipForward: onSkipForward,
      onSkipBack: onSkipBack,
    );
  }

  @override
  Future<void> play() async => _callbacks?.onPlay();

  @override
  Future<void> pause() async => _callbacks?.onPause();

  @override
  Future<void> stop() async {
    await _callbacks?.onStop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _callbacks?.onSeek(position);

  @override
  Future<void> fastForward() async => _callbacks?.onSkipForward();

  @override
  Future<void> rewind() async => _callbacks?.onSkipBack();

  @override
  Future<void> skipToNext() async => _callbacks?.onSkipForward();

  @override
  Future<void> skipToPrevious() async => _callbacks?.onSkipBack();
}

class _Callbacks {
  _Callbacks({
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onSeek,
    required this.onSkipForward,
    required this.onSkipBack,
  });

  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function() onStop;
  final Future<void> Function(Duration) onSeek;
  final Future<void> Function() onSkipForward;
  final Future<void> Function() onSkipBack;
}
