import 'dart:async';

import 'package:radioapp/data/station_repository.dart';
import 'package:radioapp/models/station.dart';
import 'package:radioapp/player/radio_player.dart';
import 'package:radioapp/voice/voice_input.dart';

Station station(
  String id, {
  String genre = 'pop',
  String? frequency,
  String color = '0xFF8B5CF6',
}) => Station.fromJson({
  'id': id,
  'name': 'Station $id',
  'frequency': frequency,
  'tagline': 'Tagline $id',
  'description': 'Description $id',
  'genre': genre,
  'language': 'en',
  'color': color,
  'streamUrl': 'https://example.com/$id.mp3',
});

class FakeRepository implements StationRepository {
  FakeRepository(this.stations, {this.error});

  final List<Station> stations;
  final Object? error;

  @override
  Future<List<Station>> loadStations() async {
    if (error != null) throw error!;
    return stations;
  }
}

/// Records calls and lets tests push player phases, titles and errors.
class FakeRadioPlayer implements RadioPlayer {
  final _phases = StreamController<PlayerPhase>.broadcast(sync: true);
  final _titles = StreamController<String?>.broadcast(sync: true);
  final _errors = StreamController<Object>.broadcast(sync: true);

  final played = <String>[];
  int stopCount = 0;
  double? volume;
  bool disposed = false;

  /// When set, the next [play] call throws this.
  Object? failNextPlay;

  /// When set, [play] waits for this completer.
  Completer<void>? pendingPlay;

  void emitPhase(PlayerPhase phase) => _phases.add(phase);
  void emitTitle(String? title) => _titles.add(title);
  void emitError(Object error) => _errors.add(error);

  @override
  Stream<PlayerPhase> get phases => _phases.stream;

  @override
  Stream<String?> get trackTitles => _titles.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> play(String url) async {
    played.add(url);
    final error = failNextPlay;
    if (error != null) {
      failNextPlay = null;
      throw error;
    }
    await pendingPlay?.future;
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeVoiceInput implements VoiceInput {
  FakeVoiceInput({this.available = true, this.phrase});

  final bool available;

  /// Spoken phrase delivered as a final result when listening starts.
  final String? phrase;
  int listenCount = 0;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    String? localeId,
  }) async {
    listenCount++;
    final words = phrase;
    if (words != null) onResult(words, true);
  }

  @override
  Future<void> stop() async {}
}
