import '../models/station.dart';

/// A command recognised from a spoken phrase.
sealed class VoiceCommand {
  const VoiceCommand();
}

/// "play", "включи": play the selected station.
class PlayCommand extends VoiceCommand {
  const PlayCommand();
}

/// "stop", "pause", "стоп".
class StopCommand extends VoiceCommand {
  const StopCommand();
}

/// "next", "следующая".
class NextCommand extends VoiceCommand {
  const NextCommand();
}

/// "previous", "предыдущая".
class PreviousCommand extends VoiceCommand {
  const PreviousCommand();
}

/// "play 96.2", "включи радио паради".
class PlayStationCommand extends VoiceCommand {
  const PlayStationCommand(this.station);

  final Station station;
}

/// "play some jazz", "включи рок".
class PlayGenreCommand extends VoiceCommand {
  const PlayGenreCommand(this.genre);

  final String genre;
}

/// "add to favourites", "в избранное".
class FavoriteCommand extends VoiceCommand {
  const FavoriteCommand();
}

/// Nothing matched.
class UnknownCommand extends VoiceCommand {
  const UnknownCommand(this.phrase);

  final String phrase;
}

/// Turns recognised speech (English, Russian or Belarusian) into a
/// [VoiceCommand].
///
/// Matching is keyword based and runs on the device: no cloud service or API
/// key is involved. Order matters: "stop" wins over everything, then
/// navigation, then a specific station, then a genre, then a plain "play".
class VoiceCommandParser {
  VoiceCommandParser(List<Station> stations) : _stations = List.of(stations);

  final List<Station> _stations;

  // Word lists per language: English, Russian, Belarusian. Russian and
  // Belarusian entries are often stems ("следующ") so that every ending
  // matches. Text is normalised first, so "ё" is "е" and "ў" is "у".
  static const _stopWords = [
    ...['stop', 'pause', 'quiet', 'silence', 'turn off', 'shut up'],
    ...['стоп', 'пауза', 'выключи', 'останови', 'хватит', 'тишина', 'замолчи'],
    ...['спыні', 'хопіць', 'цішыня', 'выключы', 'паўза'],
  ];
  static const _nextWords = [
    ...['next', 'skip', 'forward', 'another'],
    ...['следующ', 'дальше', 'вперед', 'переключи', 'другую', 'другое'],
    ...['наступн', 'далей', 'пераключы', 'іншую', 'іншае'],
  ];
  static const _previousWords = [
    ...['previous', 'go back', 'back', 'last station'],
    ...['предыдущ', 'назад', 'прошл', 'вернись'],
    ...['папярэдн', 'вярні', 'мінул'],
  ];
  static const _favoriteWords = [
    ...['favourite', 'favorite', 'like this', 'love this'],
    ...['избранн', 'нравится', 'лайк'],
    ...['абран', 'упадабан', 'падабаецца'],
  ];
  static const _playWords = [
    ...['play', 'start', 'resume', 'turn on', 'listen', 'music', 'radio'],
    ...[
      'включи',
      'играй',
      'запусти',
      'продолж',
      'поставь',
      'давай',
      'музык',
      'радио',
    ],
    ...['уключы', 'грай', 'запусці', 'працяг', 'пастаў', 'радыё'],
  ];

  /// Words for each genre used in `assets/stations.json`.
  static const genreWords = <String, List<String>>{
    'rock': ['rock', 'рок'],
    'jazz': ['jazz', 'джаз'],
    'pop': ['pop', 'поп', 'попс'],
    'retro': [
      ...['retro', 'oldies', 'old songs', 'classic hits'],
      ...['ретро', 'старые песни', 'старое'],
      ...['рэтра', 'старыя песні', 'старое'],
    ],
    'humor': [
      ...['humor', 'humour', 'comedy', 'funny', 'jokes'],
      ...['юмор', 'смешн', 'шутк'],
      ...['гумар', 'смешн', 'жарт'],
    ],
    'indie': [
      'indie',
      'alternative',
      'инди',
      'альтернатив',
      'індзі',
      'альтэрнатыў',
    ],
    'chill': [
      ...['chill', 'ambient', 'relax', 'calm', 'lounge'],
      ...['чил', 'спокойн', 'расслаб', 'эмбиент'],
      ...['чыл', 'спакойн', 'адпачын', 'эмбіент'],
    ],
  };

  /// Extra spoken names for stations, mostly Cyrillic spellings.
  static const stationAliases = <String, List<String>>{
    'humor-fm': ['юмор фм', 'гумар фм', 'humor fm', 'humour fm'],
    'legendy-fm': ['легенды', 'legendy', 'legends'],
    'melodii-veka': [
      ...['мелодии века', 'melodii veka', 'melodies of the century'],
      'мелодыі стагоддзя',
    ],
    'kexp': ['kexp', 'k e x p', 'кексп'],
    'radio-paradise': [
      ...['radio paradise', 'paradise', 'радио парадайз', 'парадайз'],
      ...['паради', 'радыё парадайз'],
    ],
    'jazz24': ['jazz24', 'jazz 24', 'джаз 24'],
    'groove-salad': ['groove salad', 'грув салад', 'салад'],
    'indie-pop-rocks': ['indie pop rocks', 'инди поп', 'індзі поп'],
  };

  VoiceCommand parse(String phrase) {
    final text = normalize(phrase);
    if (text.isEmpty) return UnknownCommand(phrase);

    if (_containsAny(text, _stopWords)) return const StopCommand();
    if (_containsAny(text, _nextWords)) return const NextCommand();
    if (_containsAny(text, _previousWords)) return const PreviousCommand();
    if (_containsAny(text, _favoriteWords)) return const FavoriteCommand();

    final station = findStation(text);
    if (station != null) return PlayStationCommand(station);

    for (final entry in genreWords.entries) {
      if (_containsAny(text, entry.value) &&
          _stations.any((s) => s.genre == entry.key)) {
        return PlayGenreCommand(entry.key);
      }
    }

    if (_containsAny(text, _playWords)) return const PlayCommand();
    return UnknownCommand(phrase);
  }

  /// Finds a station by FM frequency ("96.2", "96 point 2", "96 и 2") or by
  /// name or alias.
  Station? findStation(String normalized) {
    final frequency = RegExp(
      r'(\d{2,3})(?:\s*(?:\.|point|dot|и|і|точка|кропка)\s*(\d))?',
    ).allMatches(normalized);
    for (final match in frequency) {
      final spoken = match.group(2) == null
          ? match.group(1)!
          : '${match.group(1)}.${match.group(2)}';
      for (final station in _stations) {
        final f = station.frequency;
        if (f == null) continue;
        if (f == spoken ||
            (match.group(2) == null && f.split('.').first == spoken)) {
          return station;
        }
      }
    }

    // Prefer the longest matching name so "indie pop rocks" beats "pop".
    Station? best;
    var bestLength = 0;
    for (final station in _stations) {
      final names = [normalize(station.name), ...?stationAliases[station.id]];
      for (final name in names) {
        if (name.length > bestLength && _containsWord(normalized, name)) {
          best = station;
          bestLength = name.length;
        }
      }
    }
    return best;
  }

  /// Lower-cases, replaces "ё" and "ў", turns decimal commas into dots and removes
  /// punctuation, so "Включи 96,2!" becomes "включи 96.2".
  static String normalize(String input) => input
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll('ў', 'у')
      .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}')
      .replaceAll(RegExp(r'[^\p{L}\p{N}.\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\.(?!\d)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _containsAny(String text, List<String> words) =>
      words.any((w) => _containsWord(text, w));

  /// True when [word] starts at a word boundary, so "rock" does not match
  /// "brock" but the stem "следующ" matches "следующую".
  static bool _containsWord(String text, String word) {
    word = word.replaceAll('ў', 'у');
    var index = text.indexOf(word);
    while (index >= 0) {
      if (index == 0 || text[index - 1] == ' ') return true;
      index = text.indexOf(word, index + 1);
    }
    return false;
  }
}
