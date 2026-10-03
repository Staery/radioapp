import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:radioapp/data/favorites_store.dart';
import 'package:radioapp/player/radio_player.dart';
import 'package:radioapp/state/radio_controller.dart';
import 'package:radioapp/voice/voice_command.dart';

import 'fakes.dart';

void main() {
  late FakeRadioPlayer player;
  late InMemoryFavoritesStore favorites;
  late RadioController radio;

  final a = station('a', genre: 'rock', frequency: '92.8');
  final b = station('b', genre: 'jazz');
  final c = station('c', genre: 'rock');

  Future<RadioController> create({Set<String>? favoriteIds}) async {
    player = FakeRadioPlayer();
    favorites = InMemoryFavoritesStore(favoriteIds);
    radio = RadioController(
      repository: FakeRepository([a, b, c]),
      player: player,
      favorites: favorites,
    );
    await radio.load();
    return radio;
  }

  tearDown(() => radio.dispose());

  group('loading', () {
    test('selects the first station and keeps known favourites only', () async {
      await create(favoriteIds: {'b', 'gone'});

      expect(radio.isLoaded, isTrue);
      expect(radio.selected, a);
      expect(radio.isFavorite(b), isTrue);
      expect(radio.genres, ['rock', 'jazz']);
    });

    test('reports a load error instead of throwing', () async {
      radio = RadioController(
        repository: FakeRepository(
          const [],
          error: const FormatException('bad json'),
        ),
        player: FakeRadioPlayer(),
        favorites: InMemoryFavoritesStore(),
      );
      await radio.load();

      expect(radio.isLoaded, isTrue);
      expect(radio.loadError, contains('bad json'));
    });
  });

  group('playback', () {
    test('play sets loading, then follows player phases', () async {
      await create();
      await radio.play();

      expect(player.played, [a.streamUrl]);
      expect(radio.status, PlaybackStatus.loading);
      expect(radio.current, a);

      player.emitPhase(PlayerPhase.playing);
      expect(radio.status, PlaybackStatus.playing);
      expect(radio.isCurrent(a), isTrue);

      player.emitTitle('Artist - Song');
      expect(radio.trackTitle, 'Artist - Song');
    });

    test(
      'an idle phase while connecting does not cancel the spinner',
      () async {
        await create();
        await radio.play();
        player.emitPhase(PlayerPhase.idle);

        expect(radio.status, PlaybackStatus.loading);
      },
    );

    test(
      'toggle stops the playing station and plays a newly selected one',
      () async {
        await create();
        await radio.toggle();
        player.emitPhase(PlayerPhase.playing);

        await radio.toggle();
        expect(radio.status, PlaybackStatus.idle);
        expect(player.stopCount, 1);

        await radio.play();
        player.emitPhase(PlayerPhase.playing);
        radio.select(1);
        await radio.toggle();
        expect(player.played.last, b.streamUrl);
      },
    );

    test('a failing stream shows an error message', () async {
      await create();
      player.failNextPlay = Exception('404');
      await radio.play();

      expect(radio.status, PlaybackStatus.error);
      expect(radio.failedStation, a);
      player.emitPhase(PlayerPhase.idle);
      expect(
        radio.status,
        PlaybackStatus.error,
        reason: 'idle must not hide the error',
      );
    });

    test('errors after playback started are reported too', () async {
      await create();
      await radio.play();
      player.emitPhase(PlayerPhase.playing);
      player.emitError(Exception('connection reset'));

      expect(radio.status, PlaybackStatus.error);
    });

    test(
      'a failure of an older request is ignored after switching stations',
      () async {
        await create();
        final slow = Completer<void>();
        player.pendingPlay = slow;
        final first = radio.play(a);
        player.pendingPlay = null;
        await radio.play(b);

        slow.completeError(Exception('timeout'));
        await first;
        expect(radio.current, b);
        expect(radio.status, PlaybackStatus.loading);
      },
    );

    test('playing a station hidden by the filter clears the filter', () async {
      await create();
      radio.setFilter('jazz');
      await radio.play(a);

      expect(radio.filter, isNull);
      expect(radio.selected, a);
    });

    test('volume is clamped', () async {
      await create();
      await radio.setVolume(1.7);

      expect(radio.volume, 1);
      expect(player.volume, 1);
    });
  });

  group('navigation', () {
    test('next and previous wrap around and only select while idle', () async {
      await create();
      await radio.previous();
      expect(radio.selected, c);
      await radio.next();
      expect(radio.selected, a);
      expect(player.played, isEmpty);
    });

    test('next keeps playing when something is playing', () async {
      await create();
      await radio.play();
      player.emitPhase(PlayerPhase.playing);
      await radio.next();

      expect(player.played.last, b.streamUrl);
    });

    test('navigation stays inside the current filter', () async {
      await create();
      radio.setFilter('rock');
      expect(radio.visibleStations, [a, c]);
      await radio.next();
      expect(radio.selected, c);
      await radio.next();
      expect(radio.selected, a);
    });

    test('select ignores out-of-range indexes', () async {
      await create();
      radio.select(10);
      expect(radio.selected, a);
    });
  });

  group('filters and favourites', () {
    test('changing the filter keeps a visible selection', () async {
      await create();
      radio.select(2);
      radio.setFilter('rock');
      expect(radio.selected, c);
      expect(radio.selectedIndex, 1);

      radio.setFilter('jazz');
      expect(radio.selected, b);
    });

    test('favourites are saved and can be used as a filter', () async {
      await create();
      await radio.toggleFavorite(c);

      expect(favorites.ids, {'c'});
      radio.setFilter(favoritesFilter);
      expect(radio.visibleStations, [c]);

      await radio.toggleFavorite(c);
      expect(favorites.ids, isEmpty);
      expect(radio.visibleStations, isEmpty);
    });
  });

  group('voice commands', () {
    test('next and previous always start playback', () async {
      await create();
      final reply = await radio.execute(const NextCommand());

      expect(player.played, [b.streamUrl]);
      expect(reply.kind, VoiceReplyKind.playing);
      expect(reply.station, b);
    });

    test(
      'asking for a genre again moves to the next station of that genre',
      () async {
        await create();
        await radio.execute(const PlayGenreCommand('rock'));
        expect(radio.current, a);
        await radio.execute(const PlayGenreCommand('rock'));
        expect(radio.current, c);
        await radio.execute(const PlayGenreCommand('rock'));
        expect(radio.current, a);
      },
    );

    test('station, stop, favourite and unknown commands', () async {
      await create();
      await radio.execute(PlayStationCommand(b));
      expect(radio.current, b);

      final added = await radio.execute(const FavoriteCommand());
      expect(added.kind, VoiceReplyKind.favoriteAdded);
      expect(radio.isFavorite(b), isTrue);

      expect(
        (await radio.execute(const StopCommand())).kind,
        VoiceReplyKind.stopped,
      );
      expect(radio.status, PlaybackStatus.idle);

      final unknown = await radio.execute(const UnknownCommand('hello'));
      expect(unknown.kind, VoiceReplyKind.unknown);
      expect(unknown.phrase, 'hello');
      final silence = await radio.execute(const UnknownCommand(' '));
      expect(silence.kind, VoiceReplyKind.notHeard);
    });
  });

  testWidgets('sleep timer stops playback when it fires', (tester) async {
    await create();
    await radio.play();
    player.emitPhase(PlayerPhase.playing);

    radio.setSleepTimer(const Duration(minutes: 15));
    expect(radio.sleepAt, isNotNull);

    await tester.pump(const Duration(minutes: 14));
    expect(radio.status, PlaybackStatus.playing);

    await tester.pump(const Duration(minutes: 1, seconds: 1));
    expect(radio.status, PlaybackStatus.idle);
    expect(radio.sleepAt, isNull);
    expect(player.stopCount, 1);
  });

  testWidgets('a stream that never starts times out', (tester) async {
    await create();
    player.pendingPlay = Completer<void>();
    unawaited(radio.play());

    await tester.pump(const Duration(seconds: 19));
    expect(radio.status, PlaybackStatus.loading);

    await tester.pump(const Duration(seconds: 2));
    expect(radio.status, PlaybackStatus.error);
    expect(radio.failedStation, a);
    expect(player.stopCount, 1);
  });

  testWidgets('no timeout once the stream plays', (tester) async {
    await create();
    await radio.play();
    player.emitPhase(PlayerPhase.playing);

    await tester.pump(const Duration(minutes: 1));
    expect(radio.status, PlaybackStatus.playing);
  });

  testWidgets('sleep timer can be cancelled', (tester) async {
    await create();
    radio.setSleepTimer(const Duration(minutes: 1));
    radio.setSleepTimer(null);

    await tester.pump(const Duration(minutes: 2));
    expect(player.stopCount, 0);
  });

  test('dispose releases the player', () async {
    await create();
    radio.dispose();
    expect(player.disposed, isTrue);
    radio = RadioController(
      repository: FakeRepository([a]),
      player: FakeRadioPlayer(),
      favorites: InMemoryFavoritesStore(),
    );
  });
}
