import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radioapp/app.dart';
import 'package:radioapp/data/favorites_store.dart';
import 'package:radioapp/data/station_repository.dart';
import 'package:radioapp/player/radio_player.dart';
import 'package:radioapp/state/locale_controller.dart';

import 'fakes.dart';

void main() {
  late FakeRadioPlayer player;
  late InMemoryFavoritesStore favorites;
  late InMemoryLocaleStore localeStore;

  Future<void> pumpApp(
    WidgetTester tester, {
    FakeVoiceInput? voice,
    String? language,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    player = FakeRadioPlayer();
    favorites = InMemoryFavoritesStore();
    await tester.pumpWidget(
      RadioApp(
        repository: FakeRepository(
          AssetStationRepository.parseStations(
            File('assets/stations.json').readAsStringSync(),
          ),
        ),
        player: player,
        favorites: favorites,
        voice: voice ?? FakeVoiceInput(available: false),
        localeStore: localeStore = InMemoryLocaleStore(language),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the first station, genres and the player', (tester) async {
    await pumpApp(tester);

    expect(find.text('Radio'), findsOneWidget);
    expect(find.text('8 live stations · voice control'), findsOneWidget);
    expect(find.text('Humor FM'), findsOneWidget);
    expect(find.text('92.8'), findsOneWidget);
    expect(find.text('Tap play to listen'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Jazz'), findsOneWidget);
  });

  testWidgets('play connects and then shows the live status', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(player.played.single, 'http://live.humorfm.by:8000/veseloeradio');
    expect(find.text('Connecting to Humor FM…'), findsOneWidget);

    player.emitPhase(PlayerPhase.playing);
    player.emitTitle('Artist - Song');
    await tester.pump();
    expect(find.text('Live · Humor FM'), findsOneWidget);
    expect(find.text('Artist - Song'), findsOneWidget);
    expect(find.byTooltip('Stop'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(player.stopCount, 1);
  });

  testWidgets('a broken stream shows a snack bar', (tester) async {
    await pumpApp(tester);
    player.failNextPlay = Exception('404');

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Stream unavailable'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('next button moves the carousel', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Next station'));
    await tester.pumpAndSettle();
    expect(find.text('Legendy FM'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous station'));
    await tester.pumpAndSettle();
    expect(find.text('Humor FM'), findsOneWidget);
  });

  testWidgets('genre filter and favourites', (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Jazz'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Jazz'));
    await tester.pumpAndSettle();
    expect(find.text('Jazz24'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to favourites'));
    await tester.pumpAndSettle();
    expect(favorites.ids, {'jazz24'});

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Favourites'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Favourites'));
    await tester.pumpAndSettle();
    expect(find.text('Jazz24'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from favourites'));
    await tester.pumpAndSettle();
    expect(find.text('No favourites yet'), findsOneWidget);
  });

  testWidgets('station list can be searched and starts playback', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('All stations'));
    await tester.pumpAndSettle();
    expect(find.text('All stations'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'paradise');
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(ListTile, 'Radio Paradise');
    expect(tile, findsOneWidget);
    expect(find.widgetWithText(ListTile, 'KEXP'), findsNothing);

    await tester.tap(tile);
    await _settle(tester);
    expect(player.played.single, 'https://stream.radioparadise.com/mp3-128');
    expect(find.text('All stations'), findsNothing);
  });

  testWidgets('spoken command is executed', (tester) async {
    await pumpApp(tester, voice: FakeVoiceInput(phrase: 'включи джаз'));

    await tester.tap(find.textContaining('Say “play jazz”'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Jazz: Jazz24'), findsOneWidget);
    expect(
      player.played.single,
      'https://live.wostreaming.net/direct/ppm-jazz24mp3-ibc1',
    );

    await _settle(tester, seconds: 2);
    expect(
      find.text('Voice control'),
      findsNothing,
      reason: 'the sheet closes itself',
    );
  });

  testWidgets('typed command works when speech is unavailable', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.textContaining('Say “play jazz”'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not available'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'play 96.2');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(player.played.single, 'https://air.melodiiveka.by:8443/mv');
    await _settle(tester, seconds: 2);
  });

  testWidgets('sleep timer can be set from the header', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Sleep timer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bedtime_rounded), findsWidgets);
  });
  testWidgets('russian interface', (tester) async {
    await pumpApp(tester, language: 'ru');

    expect(find.text('Радио'), findsOneWidget);
    expect(find.text('8 станций · голосовое управление'), findsOneWidget);
    expect(find.text('Шутки и песни'), findsOneWidget);
    expect(find.text('Нажмите «Слушать»'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Избранное'), findsOneWidget);
  });

  testWidgets('belarusian interface', (tester) async {
    await pumpApp(tester, language: 'be');

    expect(find.text('Радыё'), findsOneWidget);
    expect(find.text('8 станцый · галасавое кіраванне'), findsOneWidget);
    expect(find.text('Жарты і песні'), findsOneWidget);
    expect(find.text('Мінск'), findsWidgets);
    expect(find.byTooltip('Слухаць'), findsOneWidget);
  });

  testWidgets('language can be switched and is remembered', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Беларуская'));
    await tester.pumpAndSettle();

    expect(find.text('Радыё'), findsOneWidget);
    expect(localeStore.languageCode, 'be');

    await tester.tap(find.byTooltip('Мова'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мова сістэмы'));
    await tester.pumpAndSettle();

    expect(find.text('Radio'), findsOneWidget);
    expect(localeStore.languageCode, isNull);
  });
  test('system language falls back to English', () {
    const supported = [Locale('be'), Locale('en'), Locale('ru')];
    expect(
      resolveLocale([const Locale('de', 'DE')], supported),
      const Locale('en'),
    );
    expect(resolveLocale(null, supported), const Locale('en'));
    expect(
      resolveLocale([const Locale('de'), const Locale('ru', 'RU')], supported),
      const Locale('ru'),
    );
    expect(
      resolveLocale([const Locale('be', 'BY')], supported),
      const Locale('be'),
    );
  });
}

/// Like pumpAndSettle, but works while a progress spinner keeps animating.
Future<void> _settle(WidgetTester tester, {int seconds = 1}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
