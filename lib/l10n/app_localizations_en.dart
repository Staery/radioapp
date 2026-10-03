// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Radio';

  @override
  String headerSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count live stations',
      one: '$count live station',
    );
    return '$_temp0 · voice control';
  }

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get sleepTimerOn => 'Sleep timer is on';

  @override
  String get allStations => 'All stations';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get addFavorite => 'Add to favourites';

  @override
  String get removeFavorite => 'Remove from favourites';

  @override
  String get play => 'Play';

  @override
  String get stop => 'Stop';

  @override
  String get previousStation => 'Previous station';

  @override
  String get nextStation => 'Next station';

  @override
  String get filterAll => 'All';

  @override
  String get filterFavorites => 'Favourites';

  @override
  String get genreRock => 'Rock';

  @override
  String get genreJazz => 'Jazz';

  @override
  String get genrePop => 'Pop';

  @override
  String get genreRetro => 'Retro';

  @override
  String get genreHumor => 'Humor';

  @override
  String get genreIndie => 'Indie';

  @override
  String get genreChill => 'Chill';

  @override
  String get online => 'ONLINE';

  @override
  String get noFavoritesTitle => 'No favourites yet';

  @override
  String get noFavoritesHint =>
      'Tap the heart on a station card, or say “add to favourites”.';

  @override
  String get statusIdle => 'Tap play to listen';

  @override
  String statusLive(String station) {
    return 'Live · $station';
  }

  @override
  String statusConnecting(String station) {
    return 'Connecting to $station…';
  }

  @override
  String get statusUnavailable => 'Stream unavailable';

  @override
  String streamError(String station) {
    return 'Couldn\'t play $station. The stream may be offline, try another station.';
  }

  @override
  String get voiceButton => 'Say “play jazz” or “next”';

  @override
  String loadError(String error) {
    return 'Could not load the station list: $error';
  }

  @override
  String stationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stations',
      one: '$count station',
    );
    return '$_temp0';
  }

  @override
  String get searchHint => 'Search by name, genre or frequency';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get sleepHintOff =>
      'Playback stops automatically after the chosen time.';

  @override
  String sleepHintOn(String time) {
    return 'Playback stops at $time.';
  }

  @override
  String minutes(int count) {
    return '$count min';
  }

  @override
  String get turnOff => 'Turn off';

  @override
  String get voiceTitle => 'Voice control';

  @override
  String get voicePreparing => 'Getting the microphone ready…';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceTapMic => 'Tap the microphone and say a command';

  @override
  String get voiceUnavailable =>
      'Speech recognition is not available here. Type a command instead.';

  @override
  String get voiceTypeHint => 'Or type a command';

  @override
  String get voiceExamples =>
      'Play jazz|Next station|Play 96.2|Play Radio Paradise|Add to favourites|Stop';

  @override
  String replyPlaying(String station) {
    return 'Playing $station';
  }

  @override
  String replyPlayingGenre(String genre, String station) {
    return '$genre: $station';
  }

  @override
  String get replyStopped => 'Stopped';

  @override
  String replyFavoriteAdded(String station) {
    return '$station added to favourites';
  }

  @override
  String replyFavoriteRemoved(String station) {
    return '$station removed from favourites';
  }

  @override
  String get replyNothingSelected => 'No station is selected';

  @override
  String get replyNotHeard => 'I didn\'t catch that';

  @override
  String replyUnknown(String phrase) {
    return 'Unknown command: “$phrase”';
  }
}
