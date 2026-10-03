// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Belarusian (`be`).
class AppLocalizationsBe extends AppLocalizations {
  AppLocalizationsBe([String locale = 'be']) : super(locale);

  @override
  String get appTitle => 'Радыё';

  @override
  String headerSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count станцыі',
      many: '$count станцый',
      few: '$count станцыі',
      one: '$count станцыя',
    );
    return '$_temp0 · галасавое кіраванне';
  }

  @override
  String get sleepTimer => 'Таймер сну';

  @override
  String get sleepTimerOn => 'Таймер сну ўключаны';

  @override
  String get allStations => 'Усе станцыі';

  @override
  String get language => 'Мова';

  @override
  String get languageSystem => 'Мова сістэмы';

  @override
  String get addFavorite => 'Дадаць у абранае';

  @override
  String get removeFavorite => 'Выдаліць з абранага';

  @override
  String get play => 'Слухаць';

  @override
  String get stop => 'Спыніць';

  @override
  String get previousStation => 'Папярэдняя станцыя';

  @override
  String get nextStation => 'Наступная станцыя';

  @override
  String get filterAll => 'Усе';

  @override
  String get filterFavorites => 'Абранае';

  @override
  String get genreRock => 'Рок';

  @override
  String get genreJazz => 'Джаз';

  @override
  String get genrePop => 'Поп';

  @override
  String get genreRetro => 'Рэтра';

  @override
  String get genreHumor => 'Гумар';

  @override
  String get genreIndie => 'Індзі';

  @override
  String get genreChill => 'Чыл';

  @override
  String get online => 'АНЛАЙН';

  @override
  String get noFavoritesTitle => 'У абраным пакуль пуста';

  @override
  String get noFavoritesHint =>
      'Націсніце на сэрца на картцы станцыі або скажыце «дадай у абранае».';

  @override
  String get statusIdle => 'Націсніце «Слухаць»';

  @override
  String statusLive(String station) {
    return 'У эфіры · $station';
  }

  @override
  String statusConnecting(String station) {
    return 'Падключэнне да $station…';
  }

  @override
  String get statusUnavailable => 'Паток недаступны';

  @override
  String streamError(String station) {
    return 'Не атрымалася ўключыць $station. Магчыма, станцыя зараз не вяшчае — паспрабуйце іншую.';
  }

  @override
  String get voiceButton => 'Скажыце «ўключы джаз» або «наступная»';

  @override
  String loadError(String error) {
    return 'Не атрымалася загрузіць спіс станцый: $error';
  }

  @override
  String stationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count станцыі',
      many: '$count станцый',
      few: '$count станцыі',
      one: '$count станцыя',
    );
    return '$_temp0';
  }

  @override
  String get searchHint => 'Пошук па назве, жанры або частаце';

  @override
  String get nothingFound => 'Нічога не знойдзена';

  @override
  String get sleepHintOff => 'Прайграванне спыніцца праз абраны час.';

  @override
  String sleepHintOn(String time) {
    return 'Прайграванне спыніцца а $time.';
  }

  @override
  String minutes(int count) {
    return '$count хв';
  }

  @override
  String get turnOff => 'Выключыць';

  @override
  String get voiceTitle => 'Галасавое кіраванне';

  @override
  String get voicePreparing => 'Падрыхтоўка мікрафона…';

  @override
  String get voiceListening => 'Слухаю…';

  @override
  String get voiceTapMic => 'Націсніце на мікрафон і скажыце каманду';

  @override
  String get voiceUnavailable =>
      'Распазнаванне маўлення тут недаступнае. Увядзіце каманду тэкстам.';

  @override
  String get voiceTypeHint => 'Або ўвядзіце каманду';

  @override
  String get voiceExamples =>
      'Уключы джаз|Наступная|Уключы 96,2|Уключы Radio Paradise|Дадай у абранае|Стоп';

  @override
  String replyPlaying(String station) {
    return 'Грае $station';
  }

  @override
  String replyPlayingGenre(String genre, String station) {
    return '$genre: $station';
  }

  @override
  String get replyStopped => 'Спынена';

  @override
  String replyFavoriteAdded(String station) {
    return '$station у абраным';
  }

  @override
  String replyFavoriteRemoved(String station) {
    return '$station больш не ў абраным';
  }

  @override
  String get replyNothingSelected => 'Станцыя не выбрана';

  @override
  String get replyNotHeard => 'Не пачуў, паўтарыце';

  @override
  String replyUnknown(String phrase) {
    return 'Невядомая каманда: «$phrase»';
  }
}
