import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radioapp/data/online_catalog.dart';
import 'package:radioapp/data/radio_browser.dart';
import 'package:radioapp/models/station.dart';

Map<String, Object?> row({
  String uuid = 'u1',
  String name = 'Radio Test',
  String url = 'http://example.com/live',
  String urlResolved = 'https://example.com/live.mp3',
  String tags = 'pop,hits',
  String countryCode = 'BY',
  String country = 'Belarus',
  String languageCodes = 'ru',
  String language = 'russian',
  String favicon = 'https://example.com/logo.png',
  String codec = 'MP3',
  int bitrate = 128,
}) => {
  'stationuuid': uuid,
  'name': name,
  'url': url,
  'url_resolved': urlResolved,
  'tags': tags,
  'countrycode': countryCode,
  'country': country,
  'languagecodes': languageCodes,
  'language': language,
  'favicon': favicon,
  'codec': codec,
  'bitrate': bitrate,
  'votes': 10,
  'lastcheckok': 1,
};

void main() {
  group('RadioBrowserClient.stationFromJson', () {
    test('maps the fields the app needs', () {
      final station = RadioBrowserClient.stationFromJson(row())!;

      expect(station.id, 'rb:u1');
      expect(station.name, 'Radio Test');
      expect(station.streamUrl, 'https://example.com/live.mp3');
      expect(station.countryCode, 'BY');
      expect(station.language, 'ru');
      expect(station.genre, 'pop');
      expect(station.logoUrl, 'https://example.com/logo.png');
      expect(station.isFeatured, isFalse);
      expect(station.location!.of('ru'), 'Беларусь');
      expect(station.location!.of('be'), 'Беларусь');
      expect(station.description.of('en'), contains('MP3 128 kbps'));
    });

    test('falls back to url and skips rows without a usable stream', () {
      expect(
        RadioBrowserClient.stationFromJson(row(urlResolved: ''))!.streamUrl,
        'http://example.com/live',
      );
      expect(
        RadioBrowserClient.stationFromJson(row(url: '', urlResolved: '')),
        isNull,
      );
      expect(
        RadioBrowserClient.stationFromJson(row(urlResolved: 'rtsp://x/y')),
        isNull,
      );
      expect(RadioBrowserClient.stationFromJson(row(uuid: '')), isNull);
      expect(RadioBrowserClient.stationFromJson(row(name: '  ')), isNull);
    });

    test('collects languages from codes and names', () {
      final station = RadioBrowserClient.stationFromJson(
        row(languageCodes: 'be', language: 'belarusian,russian'),
      )!;
      expect(station.languages, ['be', 'ru']);
      expect(
        RadioBrowserClient.stationFromJson(
          row(languageCodes: '', language: 'english'),
        )!.languages,
        ['en'],
      );
    });

    test('keeps only https logos', () {
      expect(
        RadioBrowserClient.stationFromJson(row(favicon: 'http://x/logo.png'))!
            .logoUrl,
        isNull,
      );
      expect(
        RadioBrowserClient.stationFromJson(row(favicon: ''))!.logoUrl,
        isNull,
      );
    });

    test('reads the FM frequency from the name', () {
      expect(
        RadioBrowserClient.frequencyFromName('Radio Mir 104.2 FM'),
        '104.2',
      );
      expect(RadioBrowserClient.frequencyFromName('Радио Минск 92,4'), '92.4');
      expect(RadioBrowserClient.frequencyFromName('Hits 24/7'), isNull);
      expect(
        RadioBrowserClient.frequencyFromName('Since 1999.5 years'),
        isNull,
      );
    });

    test('maps tags onto known genres', () {
      expect(RadioBrowserClient.genreFromTags(['news', 'talk']), 'news');
      expect(RadioBrowserClient.genreFromTags(['Classical']), 'classical');
      expect(RadioBrowserClient.genreFromTags(['smooth jazz']), 'jazz');
      expect(RadioBrowserClient.genreFromTags(['шансон']), 'chanson');
      expect(
        RadioBrowserClient.genreFromTags(['house', 'dance']),
        'electronic',
      );
      expect(RadioBrowserClient.genreFromTags(['80s']), 'retro');
      expect(RadioBrowserClient.genreFromTags(['rock', 'metal']), 'rock');
      expect(RadioBrowserClient.genreFromTags(['top 40']), 'pop');
      expect(RadioBrowserClient.genreFromTags([]), 'other');
    });

    test('gives a station the same colour every time', () {
      expect(
        RadioBrowserClient.colorFor('abc'),
        RadioBrowserClient.colorFor('abc'),
      );
    });
  });

  group('RadioBrowserClient requests', () {
    test('asks for working stations and fails over to the next server', () async {
      final requested = <Uri>[];
      final client = RadioBrowserClient(
        servers: ['bad.example', 'good.example'],
        client: MockClient((request) async {
          requested.add(request.url);
          if (request.url.host == 'bad.example') {
            return http.Response('oops', 500);
          }
          return http.Response(
            jsonEncode([row(), row(uuid: 'u2', name: 'Other')]),
            200,
          );
        }),
      );
      // Server order is shuffled; whichever comes first, the good one answers.
      final stations = await client.search(countryCode: 'BY', limit: 10);

      expect(stations.map((s) => s.id), ['rb:u1', 'rb:u2']);
      final last = requested.last;
      expect(last.host, 'good.example');
      expect(last.path, '/json/stations/search');
      expect(last.queryParameters, containsPair('countrycode', 'BY'));
      expect(last.queryParameters, containsPair('hidebroken', 'true'));
      expect(last.queryParameters, containsPair('limit', '10'));
      expect(last.queryParameters.containsKey('language'), isFalse);
    });

    test('throws when every server fails', () async {
      final client = RadioBrowserClient(
        servers: ['a.example', 'b.example'],
        client: MockClient((_) async => http.Response('down', 503)),
      );
      expect(client.search(), throwsA(isA<RadioBrowserException>()));
    });
  });

  group('RadioBrowserCatalog', () {
    late DateTime now;
    late InMemoryCatalogCache cache;
    late List<Uri> requests;
    var failing = false;

    RadioBrowserCatalog catalog() => RadioBrowserCatalog(
      client: RadioBrowserClient(
        servers: ['api.example'],
        client: MockClient((request) async {
          requests.add(request.url);
          if (failing) return http.Response('down', 503);
          final country = request.url.queryParameters['countrycode'] ?? 'XX';
          final language = request.url.queryParameters['language'] ?? 'any';
          return http.Response(
            jsonEncode([
              row(
                uuid: '$country-$language',
                name: 'Radio $country $language',
                countryCode: country == 'XX' ? 'US' : country,
              ),
              row(
                uuid: 'shared',
                name: 'Shared Radio',
                urlResolved: 'https://shared.example/live',
              ),
            ]),
            200,
          );
        }),
      ),
      cache: cache,
      now: () => now,
    );

    setUp(() {
      now = DateTime(2026, 10, 4, 12);
      cache = InMemoryCatalogCache();
      requests = [];
      failing = false;
    });

    test('downloads Belarus, Russia, both languages and world favourites, without duplicates', () async {
      final stations = await catalog().load();

      expect(requests, hasLength(5));
      final belarus = requests.firstWhere(
        (u) => u.queryParameters['countrycode'] == 'BY',
      );
      expect(
        belarus.queryParameters['hidebroken'],
        'false',
        reason: 'Belarus-only streams look broken abroad',
      );
      expect(
        requests.where((u) => u.queryParameters['language'] == 'belarusian'),
        hasLength(1),
      );
      expect(stations.where((s) => s.name == 'Shared Radio'), hasLength(1));
      expect(cache.value!.stations, stations);
    });

    test('uses a fresh cache and refreshes a stale one', () async {
      await catalog().load();
      requests.clear();

      now = now.add(const Duration(hours: 6));
      await catalog().load();
      expect(requests, isEmpty);

      now = now.add(const Duration(hours: 7));
      await catalog().load();
      expect(requests, isNotEmpty);
    });

    test(
      'falls back to a stale cache when offline and fails without one',
      () async {
        final saved = await catalog().load();
        failing = true;
        now = now.add(const Duration(days: 3));

        expect(await catalog().load(), saved);
        cache.value = null;
        expect(catalog().load(), throwsA(isA<RadioBrowserException>()));
      },
    );

    test('finds a replacement stream by name', () async {
      final featured = Station.fromJson({
        'id': 'shared-radio',
        'name': 'Shared Radio',
        'tagline': 't',
        'description': 'd',
        'genre': 'pop',
        'language': 'ru',
        'country': 'BY',
        'color': '#ffffff',
        'streamUrl': 'https://old.example/dead',
      });

      final replacement = await catalog().findReplacement(featured);
      expect(replacement!.streamUrl, 'https://shared.example/live');
      expect(requests.single.queryParameters['name'], 'Shared Radio');
    });
  });

  group('Station JSON round trip', () {
    test('toJson is readable by fromJson', () {
      final station = RadioBrowserClient.stationFromJson(
        row(languageCodes: 'be,ru'),
      )!;
      final copy = Station.fromJson(
        jsonDecode(jsonEncode(station.toJson())) as Map<String, Object?>,
      );

      expect(copy.id, station.id);
      expect(copy.streamUrl, station.streamUrl);
      expect(copy.languages, ['be', 'ru']);
      expect(copy.countryCode, 'BY');
      expect(copy.logoUrl, station.logoUrl);
      expect(copy.isFeatured, isFalse);
      expect(copy.color, station.color);
      expect(copy.location!.of('ru'), 'Беларусь');
    });
  });
}
