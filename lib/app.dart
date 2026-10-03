import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/favorites_store.dart';
import 'data/station_repository.dart';
import 'l10n/app_localizations.dart';
import 'player/radio_player.dart';
import 'state/locale_controller.dart';
import 'state/radio_controller.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';
import 'voice/voice_input.dart';

/// Root widget. Dependencies are passed in so tests can use fakes.
class RadioApp extends StatelessWidget {
  const RadioApp({
    super.key,
    required this.repository,
    required this.player,
    required this.favorites,
    required this.voice,
    required this.localeStore,
  });

  final StationRepository repository;
  final RadioPlayer player;
  final FavoritesStore favorites;
  final VoiceInput voice;
  final LocaleStore localeStore;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RadioController(
            repository: repository,
            player: player,
            favorites: favorites,
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleController(localeStore)..load(),
        ),
        Provider<VoiceInput>.value(value: voice),
      ],
      child: Consumer<LocaleController>(
        builder: (context, locale, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          locale: locale.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomePage(),
        ),
      ),
    );
  }
}

/// Picks the first system language the app supports, otherwise English.
Locale resolveLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return const Locale('en');
}
