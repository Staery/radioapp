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
