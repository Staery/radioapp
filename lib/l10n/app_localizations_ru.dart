// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Радио';

  @override
  String headerSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count станции',
      many: '$count станций',
      few: '$count станции',
      one: '$count станция',
    );
    return '$_temp0 · голосовое управление';
  }

  @override
  String get sleepTimer => 'Таймер сна';

  @override
  String get sleepTimerOn => 'Таймер сна включён';

  @override
  String get allStations => 'Все станции';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Язык системы';

  @override
  String get addFavorite => 'Добавить в избранное';

  @override
  String get removeFavorite => 'Убрать из избранного';

  @override
  String get play => 'Слушать';

  @override
  String get stop => 'Остановить';

  @override
  String get previousStation => 'Предыдущая станция';

  @override
  String get nextStation => 'Следующая станция';

  @override
  String get filterAll => 'Все';

  @override
  String get filterFavorites => 'Избранное';

  @override
  String get genreRock => 'Рок';

  @override
  String get genreJazz => 'Джаз';

  @override
  String get genrePop => 'Поп';

  @override
  String get genreRetro => 'Ретро';

  @override
  String get genreHumor => 'Юмор';

  @override
  String get genreIndie => 'Инди';

  @override
  String get genreChill => 'Чилл';

  @override
  String get online => 'ОНЛАЙН';

  @override
  String get noFavoritesTitle => 'В избранном пусто';

  @override
  String get noFavoritesHint =>
      'Нажмите на сердечко на карточке станции или скажите «добавь в избранное».';

  @override
  String get statusIdle => 'Нажмите «Слушать»';

  @override
  String statusLive(String station) {
    return 'В эфире · $station';
  }

  @override
  String statusConnecting(String station) {
    return 'Подключение к $station…';
  }

  @override
  String get statusUnavailable => 'Поток недоступен';

  @override
  String streamError(String station) {
    return 'Не удалось включить $station. Возможно, станция сейчас не вещает — попробуйте другую.';
  }

  @override
  String get voiceButton => 'Скажите «включи джаз» или «следующая»';

  @override
  String loadError(String error) {
    return 'Не удалось загрузить список станций: $error';
  }

  @override
  String stationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count станции',
      many: '$count станций',
      few: '$count станции',
      one: '$count станция',
    );
    return '$_temp0';
  }

  @override
  String get searchHint => 'Поиск по названию, жанру или частоте';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get sleepHintOff =>
      'Воспроизведение остановится через выбранное время.';

  @override
  String sleepHintOn(String time) {
    return 'Воспроизведение остановится в $time.';
  }

  @override
  String minutes(int count) {
    return '$count мин';
  }

  @override
  String get turnOff => 'Выключить';

  @override
  String get voiceTitle => 'Голосовое управление';

  @override
  String get voicePreparing => 'Подготовка микрофона…';

  @override
  String get voiceListening => 'Слушаю…';

  @override
  String get voiceTapMic => 'Нажмите на микрофон и скажите команду';

  @override
  String get voiceUnavailable =>
      'Распознавание речи здесь недоступно. Введите команду текстом.';

  @override
  String get voiceTypeHint => 'Или введите команду';

  @override
  String get voiceExamples =>
      'Включи джаз|Следующая|Включи 96,2|Включи Radio Paradise|Добавь в избранное|Стоп';

  @override
  String replyPlaying(String station) {
    return 'Играет $station';
  }

  @override
  String replyPlayingGenre(String genre, String station) {
    return '$genre: $station';
  }

  @override
  String get replyStopped => 'Остановлено';

  @override
  String replyFavoriteAdded(String station) {
    return '$station в избранном';
  }

  @override
  String replyFavoriteRemoved(String station) {
    return '$station больше не в избранном';
  }

  @override
  String get replyNothingSelected => 'Станция не выбрана';

  @override
  String get replyNotHeard => 'Не расслышал, повторите';

  @override
  String replyUnknown(String phrase) {
    return 'Неизвестная команда: «$phrase»';
  }
}
