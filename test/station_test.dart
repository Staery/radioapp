import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:radioapp/data/station_repository.dart';
import 'package:radioapp/models/station.dart';
import 'package:radioapp/voice/voice_command.dart';

Map<String, Object?> _json({Map<String, Object?> override = const {}}) => {
  'id': 'melodii-veka',
  'name': 'Melodii Veka',
  'frequency': '96.2',
  'location': 'Minsk',
  'tagline': {
    'en': 'Songs of the century',
    'ru': 'Песни века',
    'be': 'Песні стагоддзя',
  },
  'description': 'Melodies of the 20th century.',
  'genre': 'Retro',
  'language': 'RU',
  'color': '0xFF8B5CF6',
  'streamUrl': 'https://air.melodiiveka.by:8443/mv',
  ...override,
};

void main() {
  group('Station.fromJson', () {
    test('reads every field and normalises genre and language', () {
      final station = Station.fromJson(_json());

      expect(station.id, 'melodii-veka');
      expect(station.frequency, '96.2');
      expect(
        station.location!.of('ru'),
        'Minsk',
        reason: 'plain strings work for every language',
      );
      expect(station.tagline.of('ru'), 'Песни века');
      expect(station.tagline.of('be'), 'Песні стагоддзя');
      expect(
        station.tagline.of('de'),
        'Songs of the century',
        reason: 'falls back to English',
      );
      expect(station.genre, 'retro');
      expect(station.language, 'ru');
      expect(station.color, const Color(0xFF8B5CF6));
      expect(station.displayFrequency, '96.2 FM');
    });

    test('internet stations without frequency show their name', () {
      final station = Station.fromJson(_json(override: {'frequency': null}));

      expect(station.frequency, isNull);
      expect(station.displayFrequency, 'Melodii Veka');
    });

    test('rejects missing or empty required fields', () {
      expect(
        () => Station.fromJson(_json(override: {'name': ''})),
        throwsFormatException,
      );
      expect(
        () => Station.fromJson(_json()..remove('streamUrl')),
        throwsFormatException,
      );
    });

    test('rejects empty translations', () {
      expect(
        () => Station.fromJson(
          _json(
            override: {
              'tagline': {'en': 'ok', 'ru': ' '},
            },
          ),
        ),
        throwsFormatException,
      );
      expect(
        () =>
            Station.fromJson(_json(override: {'tagline': <String, Object?>{}})),
        throwsFormatException,
      );
    });

    test('rejects stream URLs that are not http(s)', () {
      expect(
        () => Station.fromJson(
          _json(override: {'streamUrl': 'ftp://example.com/radio'}),
        ),
        throwsFormatException,
      );
    });

    test('stations are equal by id', () {
      expect(
        Station.fromJson(_json()),
        Station.fromJson(_json(override: {'name': 'Other'})),
      );
    });
  });

  group('Station.parseColor', () {
    test('accepts 0x, # and short forms', () {
      expect(Station.parseColor('0xFF112233'), const Color(0xFF112233));
      expect(Station.parseColor('#112233'), const Color(0xFF112233));
      expect(Station.parseColor('#80112233'), const Color(0x80112233));
    });

    test('rejects garbage', () {
      expect(() => Station.parseColor('blue'), throwsFormatException);
      expect(() => Station.parseColor('#12345'), throwsFormatException);
    });
  });

  group('AssetStationRepository.parseStations', () {
    test('rejects duplicate ids', () {
      const item =
          '''{"id":"a","name":"A","tagline":"t","description":"d","genre":"pop",
          "language":"en","color":"#ffffff","streamUrl":"https://a.example/a.mp3"}''';
      expect(
        () =>
            AssetStationRepository.parseStations('{"stations":[$item,$item]}'),
        throwsFormatException,
      );
    });

    test('rejects a document without a station list', () {
      expect(
        () => AssetStationRepository.parseStations('{"radios":[]}'),
        throwsFormatException,
      );
    });
  });

  group('bundled catalogue', () {
    final stations = AssetStationRepository.parseStations(
      File('assets/stations.json').readAsStringSync(),
    );

    test('parses and is not empty', () {
      expect(stations, isNotEmpty);
    });

    test('every genre can be asked for by voice', () {
      for (final station in stations) {
        expect(
          VoiceCommandParser.genreWords.keys,
          contains(station.genre),
          reason: '${station.id} has genre ${station.genre}',
        );
      }
    });

    test(
      'every station has spoken aliases and aliases point to real stations',
      () {
        final ids = stations.map((s) => s.id).toSet();
        expect(VoiceCommandParser.stationAliases.keys.toSet(), ids);
      },
    );

    test(
      'every station is translated into English, Russian and Belarusian',
      () {
        for (final station in stations) {
          for (final text in [
            station.tagline,
            station.description,
            station.location!,
          ]) {
            expect(text.values.keys.toSet(), {
              'en',
              'ru',
              'be',
            }, reason: station.id);
          }
        }
      },
    );

    test('FM frequencies are unique', () {
      final frequencies = stations
          .map((s) => s.frequency)
          .whereType<String>()
          .toList();
      expect(frequencies.toSet().length, frequencies.length);
    });
  });
}
