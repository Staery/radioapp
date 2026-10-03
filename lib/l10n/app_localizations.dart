import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_be.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('be'),
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Radio'**
  String get appTitle;

  /// No description provided for @headerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} live station} other{{count} live stations}} · voice control'**
  String headerSubtitle(int count);

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @sleepTimerOn.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer is on'**
  String get sleepTimerOn;

  /// No description provided for @allStations.
  ///
  /// In en, this message translates to:
  /// **'All stations'**
  String get allStations;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get languageSystem;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get removeFavorite;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @previousStation.
  ///
  /// In en, this message translates to:
  /// **'Previous station'**
  String get previousStation;

  /// No description provided for @nextStation.
  ///
  /// In en, this message translates to:
  /// **'Next station'**
  String get nextStation;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get filterFavorites;

  /// No description provided for @genreRock.
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get genreRock;

  /// No description provided for @genreJazz.
  ///
  /// In en, this message translates to:
  /// **'Jazz'**
  String get genreJazz;

  /// No description provided for @genrePop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get genrePop;

  /// No description provided for @genreRetro.
  ///
  /// In en, this message translates to:
  /// **'Retro'**
  String get genreRetro;

  /// No description provided for @genreHumor.
  ///
  /// In en, this message translates to:
  /// **'Humor'**
  String get genreHumor;

  /// No description provided for @genreIndie.
  ///
  /// In en, this message translates to:
  /// **'Indie'**
  String get genreIndie;

  /// No description provided for @genreChill.
  ///
  /// In en, this message translates to:
  /// **'Chill'**
  String get genreChill;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get online;

  /// No description provided for @noFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'No favourites yet'**
  String get noFavoritesTitle;

  /// No description provided for @noFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a station card, or say “add to favourites”.'**
  String get noFavoritesHint;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Tap play to listen'**
  String get statusIdle;

  /// No description provided for @statusLive.
  ///
  /// In en, this message translates to:
  /// **'Live · {station}'**
  String statusLive(String station);

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {station}…'**
  String statusConnecting(String station);

  /// No description provided for @statusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Stream unavailable'**
  String get statusUnavailable;

  /// No description provided for @streamError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play {station}. The stream may be offline, try another station.'**
  String streamError(String station);

  /// No description provided for @voiceButton.
  ///
  /// In en, this message translates to:
  /// **'Say “play jazz” or “next”'**
  String get voiceButton;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the station list: {error}'**
  String loadError(String error);

  /// No description provided for @stationCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} station} other{{count} stations}}'**
  String stationCount(int count);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, genre or frequency'**
  String get searchHint;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @sleepHintOff.
  ///
  /// In en, this message translates to:
  /// **'Playback stops automatically after the chosen time.'**
  String get sleepHintOff;

  /// No description provided for @sleepHintOn.
  ///
  /// In en, this message translates to:
  /// **'Playback stops at {time}.'**
  String sleepHintOn(String time);

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutes(int count);

  /// No description provided for @turnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get turnOff;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice control'**
  String get voiceTitle;

  /// No description provided for @voicePreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting the microphone ready…'**
  String get voicePreparing;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voiceListening;

  /// No description provided for @voiceTapMic.
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone and say a command'**
  String get voiceTapMic;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is not available here. Type a command instead.'**
  String get voiceUnavailable;

  /// No description provided for @voiceTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Or type a command'**
  String get voiceTypeHint;

  /// No description provided for @voiceExamples.
  ///
  /// In en, this message translates to:
  /// **'Play jazz|Next station|Play 96.2|Play Radio Paradise|Add to favourites|Stop'**
  String get voiceExamples;

  /// No description provided for @replyPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing {station}'**
  String replyPlaying(String station);

  /// No description provided for @replyPlayingGenre.
  ///
  /// In en, this message translates to:
  /// **'{genre}: {station}'**
  String replyPlayingGenre(String genre, String station);

  /// No description provided for @replyStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get replyStopped;

  /// No description provided for @replyFavoriteAdded.
  ///
  /// In en, this message translates to:
  /// **'{station} added to favourites'**
  String replyFavoriteAdded(String station);

  /// No description provided for @replyFavoriteRemoved.
  ///
  /// In en, this message translates to:
  /// **'{station} removed from favourites'**
  String replyFavoriteRemoved(String station);

  /// No description provided for @replyNothingSelected.
  ///
  /// In en, this message translates to:
  /// **'No station is selected'**
  String get replyNothingSelected;

  /// No description provided for @replyNotHeard.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t catch that'**
  String get replyNotHeard;

  /// No description provided for @replyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown command: “{phrase}”'**
  String replyUnknown(String phrase);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['be', 'en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'be':
      return AppLocalizationsBe();
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
