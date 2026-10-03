import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/favorites_store.dart';
import '../data/station_repository.dart';
import '../models/station.dart';
import '../player/radio_player.dart';
import '../voice/voice_command.dart';

/// What the user sees in the player panel.
enum PlaybackStatus { idle, loading, playing, error }

/// Result of a voice command. The UI turns it into localized text.
enum VoiceReplyKind {
  playing,
  playingGenre,
  stopped,
  favoriteAdded,
  favoriteRemoved,
  nothingSelected,
  notHeard,
  unknown,
}

class VoiceReply {
  const VoiceReply(this.kind, {this.station, this.genre, this.phrase});

  final VoiceReplyKind kind;
  final Station? station;
  final String? genre;
  final String? phrase;
}

/// Special filter value that shows only favourite stations.
const favoritesFilter = 'favorites';

/// App state: the station list, the selected station, playback, favourites,
/// filters and the sleep timer. Widgets only read it and call its methods.
class RadioController extends ChangeNotifier {
  RadioController({
    required this._repository,
    required this._player,
    required FavoritesStore favorites,
    this.connectTimeout = const Duration(seconds: 20),
  }) : _favoritesStore = favorites {
    _subscriptions
      ..add(_player.phases.listen(_onPhase))
      ..add(
        _player.trackTitles.listen((title) {
          _trackTitle = title;
          notifyListeners();
        }),
      )
      ..add(_player.errors.listen((error) => _fail(error)));
  }

  final StationRepository _repository;
  final RadioPlayer _player;
  final FavoritesStore _favoritesStore;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// A stream that has not started playing after this long is reported as
  /// unavailable. Some backends never report a failed connection.
  final Duration connectTimeout;
  Timer? _connectTimer;

  List<Station> _stations = const [];
  Set<String> _favorites = {};
  String? _filter;
  Station? _selected;
  Station? _current;
  PlaybackStatus _status = PlaybackStatus.idle;
  String? _trackTitle;
  Station? _failedStation;
  String? _loadError;
  bool _loaded = false;
  int _request = 0;
  Timer? _sleepTimer;
  DateTime? _sleepAt;
  double _volume = 1;
  bool _disposed = false;

  bool get isLoaded => _loaded;
  String? get loadError => _loadError;
  List<Station> get stations => _stations;

  /// Stations that pass the current filter, in catalogue order.
  List<Station> get visibleStations {
    final filter = _filter;
    if (filter == null) return _stations;
    if (filter == favoritesFilter) {
      return _stations.where((s) => _favorites.contains(s.id)).toList();
    }
    return _stations.where((s) => s.genre == filter).toList();
  }

  /// Genres present in the catalogue, in order of first appearance.
  List<String> get genres => _stations.map((s) => s.genre).toSet().toList();

  String? get filter => _filter;
  Station? get selected => _selected;

  /// Index of [selected] in [visibleStations], or 0.
  int get selectedIndex {
    final selected = _selected;
    if (selected == null) return 0;
    final index = visibleStations.indexOf(selected);
    return index < 0 ? 0 : index;
  }

  /// The station that is playing or connecting.
  Station? get current => _current;
  PlaybackStatus get status => _status;
  bool get isActive =>
      _status == PlaybackStatus.playing || _status == PlaybackStatus.loading;
  String? get trackTitle => _trackTitle;

  /// The station whose stream failed, while [status] is error.
  Station? get failedStation =>
      _status == PlaybackStatus.error ? _failedStation : null;
  double get volume => _volume;
  DateTime? get sleepAt => _sleepAt;

  bool isFavorite(Station station) => _favorites.contains(station.id);
  bool isCurrent(Station station) => isActive && _current == station;

  Future<void> load() async {
    try {
      final results = await Future.wait([
        _repository.loadStations(),
        _favoritesStore.load(),
      ]);
      _stations = results[0] as List<Station>;
      _favorites = {...results[1] as Set<String>}
        ..retainWhere((id) => _stations.any((s) => s.id == id));
      _selected = _stations.isEmpty ? null : _stations.first;
      _loadError = null;
    } catch (error) {
      _loadError = '$error';
    }
    _loaded = true;
    _notify();
  }

  /// Selects the station at [index] in [visibleStations] without playing it.
  void select(int index) {
    final visible = visibleStations;
    if (index < 0 || index >= visible.length || visible[index] == _selected) {
      return;
    }
    _selected = visible[index];
    _notify();
  }

  /// Shows only [genre] (or favourites, or everything when null). The
  /// selection stays when the station is still visible.
  void setFilter(String? genre) {
    if (_filter == genre) return;
    _filter = genre;
    final visible = visibleStations;
    if (visible.isNotEmpty && !visible.contains(_selected)) {
      _selected = visible.first;
    }
    _notify();
  }

  /// Plays [station], or the selected station when null.
  Future<void> play([Station? station]) async {
    final target = station ?? _selected;
    if (target == null) return;
    if (!visibleStations.contains(target)) _filter = null;
    _selected = target;
    _current = target;
    _status = PlaybackStatus.loading;
    _failedStation = null;
    _trackTitle = null;
    final request = ++_request;
    _connectTimer?.cancel();
    _connectTimer = Timer(connectTimeout, () {
      if (request == _request && _status == PlaybackStatus.loading) {
        _fail(TimeoutException('No audio after $connectTimeout'));
        unawaited(_player.stop());
      }
    });
    _notify();
    try {
      await _player.play(target.streamUrl);
    } catch (error) {
      if (request == _request) _fail(error);
    }
  }

  Future<void> stop() async {
    _request++;
    _connectTimer?.cancel();
    _status = PlaybackStatus.idle;
    _trackTitle = null;
    _notify();
    await _player.stop();
  }

  /// Play/stop button: stops the active station or plays the selected one.
  Future<void> toggle() => isActive && _current == _selected ? stop() : play();

  /// Moves the selection forward with wrap-around. Keeps playing when
  /// something is already playing.
  Future<void> next() => _step(1);

  Future<void> previous() => _step(-1);

  Future<void> _step(int delta, {bool forcePlay = false}) async {
    final visible = visibleStations;
    if (visible.isEmpty) return;
    final index = (selectedIndex + delta) % visible.length;
    final target = visible[index < 0 ? index + visible.length : index];
    if (forcePlay || isActive) {
      await play(target);
    } else {
      _selected = target;
      _notify();
    }
  }

  Future<void> toggleFavorite([Station? station]) async {
    final target = station ?? _selected;
    if (target == null) return;
    if (!_favorites.remove(target.id)) _favorites.add(target.id);
    if (_filter == favoritesFilter && !_favorites.contains(target.id)) {
      final visible = visibleStations;
      _selected = visible.isEmpty ? _selected : visible.first;
    }
    _notify();
    await _favoritesStore.save(_favorites);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, 1).toDouble();
    _notify();
    await _player.setVolume(_volume);
  }

  /// Stops playback after [duration]; null cancels the timer.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAt = null;
    if (duration != null) {
      _sleepAt = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        _sleepTimer = null;
        _sleepAt = null;
        unawaited(stop());
      });
    }
    _notify();
  }

  /// Runs a voice command and describes what happened. Playback is started
  /// but not awaited, so the reply appears while the stream connects.
  Future<VoiceReply> execute(VoiceCommand command) async {
    switch (command) {
      case PlayCommand():
        unawaited(play());
        return VoiceReply(VoiceReplyKind.playing, station: _selected);
      case StopCommand():
        await stop();
        return const VoiceReply(VoiceReplyKind.stopped);
      case NextCommand():
        unawaited(_step(1, forcePlay: true));
        return VoiceReply(VoiceReplyKind.playing, station: _selected);
      case PreviousCommand():
        unawaited(_step(-1, forcePlay: true));
        return VoiceReply(VoiceReplyKind.playing, station: _selected);
      case PlayStationCommand(:final station):
        unawaited(play(station));
        return VoiceReply(VoiceReplyKind.playing, station: station);
      case PlayGenreCommand(:final genre):
        final matching = _stations.where((s) => s.genre == genre).toList();
        if (matching.isEmpty) return const VoiceReply(VoiceReplyKind.notHeard);
        // Ask for the same genre again to move on to its next station.
        final current = _current;
        final position = current == null ? -1 : matching.indexOf(current);
        final station = matching[(position + 1) % matching.length];
        unawaited(play(station));
        return VoiceReply(
          VoiceReplyKind.playingGenre,
          station: station,
          genre: genre,
        );
      case FavoriteCommand():
        final station = _selected;
        if (station == null) {
          return const VoiceReply(VoiceReplyKind.nothingSelected);
        }
        await toggleFavorite(station);
        return VoiceReply(
          isFavorite(station)
              ? VoiceReplyKind.favoriteAdded
              : VoiceReplyKind.favoriteRemoved,
          station: station,
        );
      case UnknownCommand(:final phrase):
        return phrase.trim().isEmpty
            ? const VoiceReply(VoiceReplyKind.notHeard)
            : VoiceReply(VoiceReplyKind.unknown, phrase: phrase.trim());
    }
  }

  void _onPhase(PlayerPhase phase) {
    if (_status == PlaybackStatus.error && phase == PlayerPhase.idle) return;
    final status = switch (phase) {
      PlayerPhase.idle =>
        _status == PlaybackStatus.loading
            ? PlaybackStatus.loading
            : PlaybackStatus.idle,
      PlayerPhase.loading => PlaybackStatus.loading,
      PlayerPhase.playing => PlaybackStatus.playing,
    };
    if (status == PlaybackStatus.playing) _connectTimer?.cancel();
    if (status == _status) return;
    _status = status;
    _notify();
  }

  void _fail(Object error) {
    _status = PlaybackStatus.error;
    _trackTitle = null;
    _failedStation = _current;
    if (kDebugMode) debugPrint('Playback error: $error');
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    _connectTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}
