import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages the app is translated into.
const supportedLanguages = ['en', 'ru', 'be'];

/// Persists the chosen language code; null means "follow the system".
abstract interface class LocaleStore {
  Future<String?> load();
  Future<void> save(String? languageCode);
}

class SharedPreferencesLocaleStore implements LocaleStore {
  static const _key = 'language_code';

  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> save(String? languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (languageCode == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, languageCode);
    }
  }
}

class InMemoryLocaleStore implements LocaleStore {
  InMemoryLocaleStore([this.languageCode]);

  String? languageCode;

  @override
  Future<String?> load() async => languageCode;

  @override
  Future<void> save(String? languageCode) async =>
      this.languageCode = languageCode;
}

/// The app language chosen by the user, or null to follow the system.
class LocaleController extends ChangeNotifier {
  LocaleController(this._store);

  final LocaleStore _store;
  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> load() async {
    final code = await _store.load();
    _locale = supportedLanguages.contains(code) ? Locale(code!) : null;
    notifyListeners();
  }

  Future<void> setLanguage(String? languageCode) async {
    if (languageCode != null && !supportedLanguages.contains(languageCode)) {
      throw ArgumentError.value(languageCode, 'languageCode', 'Not supported');
    }
    _locale = languageCode == null ? null : Locale(languageCode);
    notifyListeners();
    await _store.save(languageCode);
  }
}
