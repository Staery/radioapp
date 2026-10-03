import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/station.dart';

/// Loads the station catalogue.
abstract interface class StationRepository {
  Future<List<Station>> loadStations();
}

/// Reads stations from a JSON asset bundled with the app.
class AssetStationRepository implements StationRepository {
  AssetStationRepository({
    AssetBundle? bundle,
    this.path = 'assets/stations.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String path;

  @override
  Future<List<Station>> loadStations() async =>
      parseStations(await _bundle.loadString(path));

  /// Parses the catalogue and rejects duplicate ids.
  static List<Station> parseStations(String source) {
    final root = jsonDecode(source);
    if (root is! Map<String, Object?> || root['stations'] is! List<Object?>) {
      throw const FormatException('Expected an object with a "stations" list');
    }
    final stations = [
      for (final item in root['stations']! as List<Object?>)
        Station.fromJson(item! as Map<String, Object?>),
    ];
    final ids = <String>{};
    for (final station in stations) {
      if (!ids.add(station.id)) {
        throw FormatException('Duplicate station id: ${station.id}');
      }
    }
    return List.unmodifiable(stations);
  }
}
