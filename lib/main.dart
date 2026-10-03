import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'app.dart';
import 'data/favorites_store.dart';
import 'data/station_repository.dart';
import 'player/radio_player.dart';
import 'state/locale_controller.dart';
import 'voice/voice_input.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows and Linux play streams through libmpv; other platforms ignore this.
  JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0B14),
    ),
  );
  await JustAudioRadioPlayer.configureAudioSession();

  runApp(
    RadioApp(
      repository: AssetStationRepository(),
      player: JustAudioRadioPlayer(),
      favorites: SharedPreferencesFavoritesStore(),
      voice: SpeechToTextVoiceInput(),
      localeStore: SharedPreferencesLocaleStore(),
    ),
  );
}
