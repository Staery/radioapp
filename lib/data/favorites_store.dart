import 'package:shared_preferences/shared_preferences.dart';

/// Persists the ids of favourite stations.
abstract interface class FavoritesStore {
  Future<Set<String>> load();
  Future<void> save(Set<String> ids);
}

class SharedPreferencesFavoritesStore implements FavoritesStore {
  static const _key = 'favorite_station_ids';

  @override
  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  @override
  Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList()..sort());
  }
}

class InMemoryFavoritesStore implements FavoritesStore {
  InMemoryFavoritesStore([Set<String>? initial]) : ids = {...?initial};

  Set<String> ids;

  @override
  Future<Set<String>> load() async => {...ids};

  @override
  Future<void> save(Set<String> ids) async => this.ids = {...ids};
}

/// Small key-value settings, e.g. the chosen station scope.
abstract interface class SettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesSettingsStore implements SettingsStore {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class InMemorySettingsStore implements SettingsStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
