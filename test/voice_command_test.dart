import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:radioapp/data/station_repository.dart';
import 'package:radioapp/voice/voice_command.dart';

void main() {
  final stations = AssetStationRepository.parseStations(
    File('assets/stations.json').readAsStringSync(),
  );
  final parser = VoiceCommandParser(stations);

  String? stationId(String phrase) => switch (parser.parse(phrase)) {
    PlayStationCommand(:final station) => station.id,
    _ => null,
  };

  String? genre(String phrase) => switch (parser.parse(phrase)) {
    PlayGenreCommand(:final genre) => genre,
    _ => null,
  };

  group('basic commands', () {
    const cases = <String, Type>{
      'Stop': StopCommand,
      'pause the music': StopCommand,
      'Стоп!': StopCommand,
      'выключи радио': StopCommand,
      'next': NextCommand,
      'Next station please': NextCommand,
      'следующая': NextCommand,
      'переключи': NextCommand,
      'previous': PreviousCommand,
      'go back': PreviousCommand,
      'предыдущую станцию': PreviousCommand,
      'назад': PreviousCommand,
      'play': PlayCommand,
      'Play some music': PlayCommand,
      'включи радио': PlayCommand,
      'продолжай': PlayCommand,
      'add to favourites': FavoriteCommand,
      'добавь в избранное': FavoriteCommand,
    };
    cases.forEach((phrase, type) {
      test(
        '"$phrase" → $type',
        () => expect(parser.parse(phrase).runtimeType, type),
      );
    });
  });

  group('belarusian', () {
    const cases = <String, Type>{
      'Спыні': StopCommand,
      'паўза': StopCommand,
      'наступная': NextCommand,
      'пераключы на іншую': NextCommand,
      'папярэдняя станцыя': PreviousCommand,
      'дадай у абранае': FavoriteCommand,
      'уключы радыё': PlayCommand,
      'ўключы музыку': PlayCommand,
    };
    cases.forEach((phrase, type) {
      test(
        '"$phrase" → $type',
        () => expect(parser.parse(phrase).runtimeType, type),
      );
    });

    test('genres and stations', () {
      expect(genre('уключы рэтра'), 'retro');
      expect(genre('хачу нешта спакойнае'), 'chill');
      expect(genre('ўключы гумар'), 'humor');
      expect(stationId('уключы 94 і 1'), 'legendy-fm');
      expect(stationId('уключы 92 кропка 8'), 'humor-fm');
      expect(stationId('уключы наша радыё'), 'nashe-radio');
    });
  });

  group('stations', () {
    test('by frequency', () {
      expect(stationId('play 88.3'), 'retro-fm');
      expect(stationId('включи 106,2'), 'europa-plus');
      expect(stationId('play 92 point 8'), 'humor-fm');
      expect(stationId('включи 94 и 1'), 'legendy-fm');
      expect(stationId('play 90.3'), 'kexp');
    });

    test('by whole-number frequency when it is unambiguous', () {
      expect(stationId('play 94'), 'legendy-fm');
    });

    test('by name and alias', () {
      expect(stationId('play Radio Paradise'), 'radio-paradise');
      expect(stationId('включи наше радио'), 'nashe-radio');
      expect(stationId('play BBC'), 'bbc-world-service');
      expect(stationId('включи радио рекорд'), 'radio-record');
      expect(stationId('Play KEXP'), 'kexp');
      expect(stationId('play jazz 24'), 'jazz24');
      expect(stationId('play groove salad'), 'groove-salad');
    });

    test('the longest name wins over a genre word inside it', () {
      expect(stationId('play indie pop rocks'), 'indie-pop-rocks');
    });

    test('unknown frequency falls back to a plain play', () {
      expect(parser.parse('play 107 FM'), isA<PlayCommand>());
    });
  });

  group('genres', () {
    test('english and russian words', () {
      expect(genre('play some jazz'), 'jazz');
      expect(genre('Play rock music'), 'rock');
      expect(genre('включи рок'), 'rock');
      expect(genre('хочу что-нибудь спокойное'), 'chill');
      expect(genre('поставь ретро'), 'retro');
      expect(genre('something funny'), 'humor');
      expect(genre('инди'), 'indie');
    });

    test('words only match at the start of a word', () {
      expect(genre('play brock'), isNull);
    });
  });

  group('priorities and edge cases', () {
    test('stop wins over everything else', () {
      expect(parser.parse('stop the jazz'), isA<StopCommand>());
    });

    test('navigation wins over play', () {
      expect(parser.parse('play next'), isA<NextCommand>());
    });

    test('empty and unknown phrases', () {
      expect(parser.parse('   '), isA<UnknownCommand>());
      final unknown = parser.parse('what is the weather');
      expect(unknown, isA<UnknownCommand>());
      expect((unknown as UnknownCommand).phrase, 'what is the weather');
    });

    test('genres that no station has are ignored', () {
      final jazzless = VoiceCommandParser(
        stations.where((s) => s.genre != 'jazz').toList(),
      );
      expect(jazzless.parse('play jazz'), isA<PlayCommand>());
    });
  });

  group('normalize', () {
    test(
      'lower-cases, replaces ё, keeps decimal dots and drops punctuation',
      () {
        expect(
          VoiceCommandParser.normalize('Включи «Мелодии Века», 96,2!'),
          'включи мелодии века 96.2',
        );
        expect(VoiceCommandParser.normalize('Ещё. Раз.'), 'еще раз');
      },
    );
  });
}
