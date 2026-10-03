import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// What the audio engine is doing right now.
enum PlayerPhase { idle, loading, playing }

/// The audio engine as seen by the rest of the app.
///
/// Keeping it behind an interface lets the controller and widgets be tested
/// with a fake, without platform channels or network access.
abstract interface class RadioPlayer {
  Stream<PlayerPhase> get phases;

  /// Title of the current track, when the stream sends ICY metadata.
  Stream<String?> get trackTitles;

  /// Errors that happen after playback has started, e.g. a dropped stream.
  Stream<Object> get errors;

  /// Starts playing [url]. Completes once playback has started and throws if
  /// the stream cannot be opened.
  Future<void> play(String url);

  Future<void> stop();

  Future<void> setVolume(double volume);

  Future<void> dispose();
}

/// [RadioPlayer] backed by just_audio.
class JustAudioRadioPlayer implements RadioPlayer {
  JustAudioRadioPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _errorSubscription = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace _) => _errors.add(error),
    );
  }

  final AudioPlayer _player;
  final _errors = StreamController<Object>.broadcast();
  late final StreamSubscription<PlaybackEvent> _errorSubscription;

  /// Tells the OS that this app plays music, so it ducks for navigation
  /// prompts and pauses when headphones are unplugged.
  static Future<void> configureAudioSession() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } on MissingPluginException {
      // Desktop platforms without an audio session API.
    }
  }

  @override
  Stream<PlayerPhase> get phases => _player.playerStateStream.map((state) {
    switch (state.processingState) {
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return state.playing ? PlayerPhase.loading : PlayerPhase.idle;
      case ProcessingState.ready:
        return state.playing ? PlayerPhase.playing : PlayerPhase.idle;
      case ProcessingState.idle:
      case ProcessingState.completed:
        return PlayerPhase.idle;
    }
  }).distinct();

  @override
  Stream<String?> get trackTitles => _player.icyMetadataStream.map((metadata) {
    final title = metadata?.info?.title?.trim();
    return title == null || title.isEmpty ? null : title;
  }).distinct();

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> play(String url) async {
    await _player.setUrl(url);
    unawaited(_player.play());
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0, 1));

  @override
  Future<void> dispose() async {
    await _errorSubscription.cancel();
    await _errors.close();
    await _player.dispose();
  }
}
