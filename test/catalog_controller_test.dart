import 'package:flutter_test/flutter_test.dart';
import 'package:radioapp/data/favorites_store.dart';
import 'package:radioapp/models/station.dart';
import 'package:radioapp/models/station_scope.dart';
import 'package:radioapp/player/radio_player.dart';
import 'package:radioapp/state/radio_controller.dart';

import 'fakes.dart';

void main() {
  late FakeRadioPlayer player;
  late FakeCatalog catalog;
  late FakeProbe probe;
  late InMemorySettingsStore settings;
  late RadioController radio;

  final minsk = Station.fromJson({
    'id': 'minsk-fm',
    'name': 'Minsk FM',
    'tagline': 't',
    'description': 'd',
    'genre': 'pop',
    'language': 'ru',
    'country': 'BY',
    'color': '#ff0000',
    'streamUrl': 'https://minsk.example/live',
  });
  final london = Station.fromJson({
    'id': 'london-jazz',
    'name': 'London Jazz',
    'tagline': 't',
    'description': 'd',
    'genre': 'jazz',
    'language': 'en',
    'country': 'GB',
    'color': '#0000ff',
    'streamUrl': 'https://london.example/live',
  });
  final belarusian = onlineStation('be1', languages: ['be']);
  final moscow = onlineStation('ru1', country: 'RU');
  final duplicate = onlineStation('dup', name: 'Minsk FM');

  Future<void> create({
    List<Station>? online,
    Set<String> broken = const {},
    Map<String, Station> replacements = const {},
    Object? catalogError,
  }) async {
    player = FakeRadioPlayer();
    catalog = FakeCatalog(
      online ?? [belarusian, moscow, duplicate],
      error: catalogError,
      replacements: replacements,
    );
    probe = FakeProbe(broken);
    radio = RadioController(
      repository: FakeRepository([minsk, london]),
      player: player,
      favorites: InMemoryFavoritesStore(),
      catalog: catalog,
      probe: probe,
      settings: settings,
    );
    await radio.load();
    await pumpEventQueue();
  }

  setUp(() => settings = InMemorySettingsStore());
  tearDown(() => radio.dispose());

  test(
    'online stations follow the featured ones, without duplicates',
    () async {
      await create();

      expect(radio.catalogStatus, CatalogStatus.loaded);
      expect(radio.stations, [minsk, london, belarusian, moscow]);
    },
  );

  test('a failed catalogue leaves the featured stations', () async {
    await create(catalogError: Exception('offline'));

    expect(radio.catalogStatus, CatalogStatus.failed);
    expect(radio.stations, [minsk, london]);

    catalog.error = null;
    await radio.refreshCatalog(force: true);
    expect(radio.stations, hasLength(4));
  });

  group('scope', () {
    test('filters by country, language and featured', () async {
      await create();

      await radio.setScope(StationScope.belarus);
      expect(radio.visibleStations, [minsk, belarusian]);
      await radio.setScope(StationScope.russia);
      expect(radio.visibleStations, [moscow]);
      await radio.setScope(StationScope.belarusian);
      expect(radio.visibleStations, [belarusian]);
      await radio.setScope(StationScope.russian);
      expect(radio.visibleStations, [minsk, moscow]);
      await radio.setScope(StationScope.english);
      expect(radio.visibleStations, [london]);
      await radio.setScope(StationScope.featured);
      expect(radio.visibleStations, [minsk, london]);
      expect(radio.countIn(StationScope.all), 4);
    });

    test('is remembered', () async {
      await create();
      await radio.setScope(StationScope.belarusian);
      radio.dispose();

      await create();
      expect(radio.scope, StationScope.belarusian);
      expect(radio.selected, belarusian);
    });

    test(
      'playing a station outside the scope shows everything again',
      () async {
        await create();
        await radio.setScope(StationScope.russia);
        await radio.play(london);

        expect(radio.scope, StationScope.all);
        expect(radio.selected, london);
      },
    );

    test('genres follow the scope, most common first', () async {
      await create(
        online: [
          onlineStation('a', genre: 'rock'),
          onlineStation('b', genre: 'rock'),
          onlineStation('c', genre: 'other'),
        ],
      );
      expect(radio.genres, ['rock', 'pop', 'jazz', 'other']);
      await radio.setScope(StationScope.english);
      expect(radio.genres, ['jazz']);
    });
  });

  group('availability from this network', () {
    test('every stream is checked and broken ones are hidden', () async {
      await create(broken: {moscow.streamUrl, london.streamUrl});

      expect(probe.checked, hasLength(4));
      expect(radio.isAvailable(moscow), isFalse);
      expect(radio.visibleStations, [minsk, belarusian]);

      await radio.setHideUnavailable(false);
      expect(radio.visibleStations, [minsk, london, belarusian, moscow]);
      expect(settings.values['hide_unavailable'], 'false');
    });

    test(
      'when nothing opens at all, the device is offline: nothing is hidden',
      () async {
        await create(
          broken: {
            minsk.streamUrl,
            london.streamUrl,
            belarusian.streamUrl,
            moscow.streamUrl,
          },
        );

        expect(radio.visibleStations, hasLength(4));
        expect(settings.values.containsKey('stream_health_v1'), isFalse);
      },
    );

    test('results are remembered for a day', () async {
      await create(broken: {moscow.streamUrl});
      radio.dispose();

      await create(broken: {moscow.streamUrl});
      expect(probe.checked, isEmpty, reason: 'fresh results are reused');
      expect(radio.isAvailable(moscow), isFalse);
    });

    test('next skips stations that failed', () async {
      await create(broken: {london.streamUrl});
      await radio.setHideUnavailable(false);

      await radio.next();
      expect(radio.selected, belarusian);
    });

    test('a stream that fails while playing is marked unavailable', () async {
      await create(online: []);
      player.failNextPlay = Exception('403 geo-blocked');
      await radio.play(london);
      await pumpEventQueue();

      expect(radio.status, PlaybackStatus.error);
      expect(radio.isAvailable(london), isFalse);
    });
  });

  group('self-healing featured stations', () {
    test('a dead featured stream is replaced from the catalogue', () async {
      final fresh = onlineStation('minsk-new', name: 'Minsk FM');
      await create(replacements: {minsk.id: fresh});
      player.failNextPlay = Exception('404');

      await radio.play(minsk);
      await pumpEventQueue();

      expect(catalog.replacementRequests, [minsk.id]);
      expect(player.played, [minsk.streamUrl, fresh.streamUrl]);
      expect(radio.status, PlaybackStatus.loading);
      expect(
        radio.current!.id,
        minsk.id,
        reason: 'it is still the featured station',
      );
      expect(radio.isAvailable(radio.current!), isTrue);

      player.emitPhase(PlayerPhase.playing);
      expect(radio.status, PlaybackStatus.playing);
    });

    test(
      'without a replacement the error is shown, and the lookup happens once',
      () async {
        await create();
        player.failNextPlay = Exception('404');
        await radio.play(minsk);
        await pumpEventQueue();

        expect(radio.status, PlaybackStatus.error);
        expect(radio.failedStation, minsk);

        player.failNextPlay = Exception('404');
        await radio.play(minsk);
        await pumpEventQueue();
        expect(catalog.replacementRequests, [minsk.id]);
      },
    );
  });
}
