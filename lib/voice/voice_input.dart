import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech recognition as seen by the UI.
abstract interface class VoiceInput {
  /// Asks for microphone permission and prepares the recogniser. Returns
  /// false when speech recognition is not available on this device.
  Future<bool> initialize();

  /// Listens for one phrase. [onResult] receives partial results while the
  /// user speaks and a final result at the end.
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    String? localeId,
  });

  Future<void> stop();
}

/// [VoiceInput] backed by the platform recogniser (Android SpeechRecognizer,
/// iOS Speech framework, Web Speech API in browsers).
class SpeechToTextVoiceInput implements VoiceInput {
  final _speech = SpeechToText();
  bool? _available;

  @override
  Future<bool> initialize() async {
    if (_available != null) return _available!;
    // speech_to_text has no Linux implementation.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      return _available = false;
    }
    try {
      _available = await _speech
          .initialize(onError: (_) {}, onStatus: (_) {})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // No recogniser or no permission: typed commands still work.
      _available = false;
    }
    return _available!;
  }

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    String? localeId,
  }) async {
    if (!await initialize()) return;
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}
