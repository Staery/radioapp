import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';
import 'radio_browser.dart';

/// Stations from an online directory, on top of the bundled ones.
abstract interface class OnlineCatalog {
  /// Loads the catalogue. Uses a fresh cache when there is one, unless
  /// [refresh] is true. Throws when nothing could be loaded at all.
  Future<List<Station>> load({bool refresh = false});

  /// Looks for a working stream of [station] after its own stream failed.
  Future<Station?> findReplacement(Station station);
}

/// Saves the downloaded catalogue so the app starts fast and works offline.
abstract interface class CatalogCache {
  Future<({DateTime savedAt, List<Station> stations})?> read();
  Future<void> write(List<Station> stations, DateTime savedAt);
}

class SharedPreferencesCatalogCache implements CatalogCache {
  static const _key = 'online_catalog_v1';

  @override
  Future<({DateTime savedAt, List<Station> stations})?> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return (
        savedAt: DateTime.parse(json['savedAt']! as String),
        stations: [
          for (final item in json['stations']! as List<Object?>)
            Station.fromJson(item! as Map<String, Object?>),
        ],
      );
    } on Object {
      return null; // A damaged cache is simply downloaded again.
    }
  }

  @override
  Future<void> write(List<Station> stations, DateTime savedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'savedAt': savedAt.toIso8601String(),
        'stations': [for (final station in stations) station.toJson()],
      }),
    );
  }
}

class InMemoryCatalogCache implements CatalogCache {
  ({DateTime savedAt, List<Station> stations})? value;

  @override
  Future<({DateTime savedAt, List<Station> stations})?> read() async => value;

  @override
  Future<void> write(List<Station> stations, DateTime savedAt) async =>
      value = (savedAt: savedAt, stations: List.of(stations));
}

/// Belarusian, Russian-language, Belarusian-language and the most popular
/// world stations from Radio Browser, refreshed twice a day.
class RadioBrowserCatalog implements OnlineCatalog {
  RadioBrowserCatalog({
    required this._client,
    required this._cache,
    DateTime Function()? now,
    this.maxAge = const Duration(hours: 12),
  }) : _now = now ?? DateTime.now;

  final RadioBrowserClient _client;
  final CatalogCache _cache;
  final DateTime Function() _now;
  final Duration maxAge;

  @override
  Future<List<Station>> load({bool refresh = false}) async {
    final cached = await _cache.read();
    if (!refresh &&
        cached != null &&
        _now().difference(cached.savedAt) < maxAge) {
      return cached.stations;
    }

    final queries = <Future<List<Station>>>[
      // Radio Browser checks streams from servers outside Belarus, so streams
      // that only work from Belarus look broken there. Keep them all; the app
      // checks availability from the listener's own network.
      _client.search(countryCode: 'BY', limit: 150, hideBroken: false),
      _client.search(language: 'belarusian', limit: 60),
      _client.search(countryCode: 'RU', limit: 120),
      _client.search(language: 'russian', limit: 120),
      _client.topVoted(limit: 120),
    ];
    final results = await Future.wait(
      queries.map(
        (query) => query
            .then<List<Station>?>((value) => value)
            .catchError((Object _) => null),
      ),
    );

    if (results.every((result) => result == null)) {
      if (cached != null) {
        return cached.stations; // Offline: stale is better than nothing.
      }
      throw const RadioBrowserException('The online catalogue is unavailable');
    }

    final stations = dedupe([for (final result in results) ...?result]);
    await _cache.write(stations, _now());
    return stations;
  }

  @override
  Future<Station?> findReplacement(Station station) async {
    try {
      final candidates = await _client.search(
        name: station.name,
        countryCode: station.countryCode,
        limit: 5,
      );
      final wanted = _key(station.name);
      for (final candidate in candidates) {
        if (_key(candidate.name) == wanted &&
            candidate.streamUrl != station.streamUrl) {
          return candidate;
        }
      }
    } on Object {
      // No replacement: the caller reports the original error.
    }
    return null;
  }

  /// Removes duplicates: the same station is often listed several times with
  /// different stream mirrors.
  static List<Station> dedupe(Iterable<Station> stations) {
    final seenIds = <String>{};
    final seenNames = <String>{};
    final seenUrls = <String>{};
    return [
      for (final station in stations)
        if (seenIds.add(station.id) &&
            seenUrls.add(station.streamUrl) &&
            seenNames.add('${_key(station.name)}|${station.countryCode}'))
          station,
    ];
  }

  static String _key(String name) => name.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    '',
  );
}
