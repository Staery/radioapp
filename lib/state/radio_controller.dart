import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/favorites_store.dart';
import '../data/online_catalog.dart';
import '../data/stream_probe.dart';
import '../data/station_repository.dart';
import '../models/station.dart';
import '../models/station_scope.dart';
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

/// State of the online station catalogue.
enum CatalogStatus { off, loading, loaded, failed }

/// Special filter value that shows only favourite stations.
const favoritesFilter = 'favorites';

/// App state: the station list, the selected station, playback, favourites,
/// filters and the sleep timer. Widgets only read it and call its methods.
class RadioController extends ChangeNotifier {
  RadioController({
    required this._repository,
    required this._player,
    required FavoritesStore favorites,
    OnlineCatalog? catalog,
    StreamProbe? probe,
    SettingsStore? settings,
    this.connectTimeout = const Duration(seconds: 20),
    this.healthMaxAge = const Duration(hours: 24),
    this.probeConcurrency = 8,
    DateTime Function()? now,
  }) : _favoritesStore = favorites,
       _catalog = catalog, // ignore: prefer_initializing_formals
       _probe = probe, // ignore: prefer_initializing_formals
       _settings = settings ?? InMemorySettingsStore(),
       _now = now ?? DateTime.now {
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
  final OnlineCatalog? _catalog;
  final StreamProbe? _probe;
  final SettingsStore _settings;
  final DateTime Function() _now;

  /// How long an availability check from this device is trusted.
  final Duration healthMaxAge;

  /// How many streams are checked at the same time.
  final int probeConcurrency;

  static const _scopeKey = 'station_scope';
  static const _hideUnavailableKey = 'hide_unavailable';
  static const _healthKey = 'stream_health_v1';
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// A stream that has not started playing after this long is reported as
  /// unavailable. Some backends never report a failed connection.
  final Duration connectTimeout;
  Timer? _connectTimer;

  List<Station> _featured = const [];
  List<Station> _online = const [];
  List<Station> _stations = const [];
  CatalogStatus _catalogStatus = CatalogStatus.off;
  StationScope _scope = StationScope.all;
  bool _hideUnavailable = true;
  final _health = <String, ({StreamHealth health, DateTime checkedAt})>{};
  final _recovered = <String>{};
  bool _probing = false;
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

  /// Featured stations first, then stations from the online catalogue.
  List<Station> get stations => _stations;

  CatalogStatus get catalogStatus => _catalogStatus;
  StationScope get scope => _scope;
  bool get hideUnavailable => _hideUnavailable;
  bool get isCheckingStreams => _probing;

  /// False when the stream failed from this device (geo-blocked, offline…).
  bool isAvailable(Station station) =>
      _health[station.id]?.health != StreamHealth.failed;

  /// Stations in the chosen scope that can be played from here.
  List<Station> get scopedStations => [
    for (final station in _stations)
      if (_scope.matches(station) &&
          (!_hideUnavailable || isAvailable(station) || station == _selected))
        station,
  ];

  /// Stations that pass the scope and the genre or favourites filter.
  List<Station> get visibleStations {
    final scoped = scopedStations;
    final filter = _filter;
    if (filter == null) return scoped;
    if (filter == favoritesFilter) {
      return scoped.where((s) => _favorites.contains(s.id)).toList();
    }
    return scoped.where((s) => s.genre == filter).toList();
  }

  /// Number of stations in [scope], for the scope picker.
  int countIn(StationScope scope) => _stations
      .where((s) => scope.matches(s) && (!_hideUnavailable || isAvailable(s)))
      .length;

  /// Genres of the stations in the current scope, most common first.
  List<String> get genres {
    final counts = <String, int>{};
    for (final station in scopedStations) {
      counts[station.genre] = (counts[station.genre] ?? 0) + 1;
    }
    final result = counts.keys.where((g) => g != 'other').toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    if (counts.containsKey('other')) result.add('other');
    return result;
  }

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
        _settings.read(_scopeKey),
        _settings.read(_hideUnavailableKey),
        _settings.read(_healthKey),
      ]);
      _featured = results[0]! as List<Station>;
      _favorites = {...results[1]! as Set<String>};
      _scope = StationScope.fromKey(results[2] as String?);
      _hideUnavailable = results[3] != 'false';
      _readHealth(results[4] as String?);
      _rebuild();
      _selected = _firstVisible();
      _loadError = null;
    } catch (error) {
      _loadError = '$error';
    }
    _loaded = true;
    _notify();
    if (_loadError == null) {
      if (_catalog != null) {
        unawaited(refreshCatalog());
      } else {
        unawaited(_checkStreams());
      }
    }
  }

  /// Downloads (or reads from cache) the online catalogue and then checks
  /// which streams answer from this device.
  Future<void> refreshCatalog({bool force = false}) async {
    final catalog = _catalog;
    if (catalog == null || _catalogStatus == CatalogStatus.loading) return;
    _catalogStatus = CatalogStatus.loading;
    _notify();
    try {
      _online = await catalog.load(refresh: force);
      _catalogStatus = CatalogStatus.loaded;
    } catch (_) {
      _catalogStatus = CatalogStatus.failed;
    }
    _rebuild();
    _selected ??= _firstVisible();
    if (!isActive) _keepSelectionVisible();
    _notify();
    await _checkStreams();
  }

  /// Shows all stations, the featured ones, one country or one language.
  Future<void> setScope(StationScope scope) async {
    if (_scope == scope) return;
    _scope = scope;
    _keepSelectionVisible();
    _notify();
    await _settings.write(_scopeKey, scope.key);
  }

  /// Hides or shows stations whose stream failed from this device.
  Future<void> setHideUnavailable(bool hide) async {
    if (_hideUnavailable == hide) return;
    _hideUnavailable = hide;
    _keepSelectionVisible();
    _notify();
    await _settings.write(_hideUnavailableKey, '$hide');
  }

  /// Featured stations first; online stations that duplicate a featured one
  /// (same name and country) are left out.
  void _rebuild() {
    String key(Station s) =>
        '${s.name.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '')}|${s.countryCode}';
    final featuredKeys = {for (final s in _featured) key(s)};
    _stations = List.unmodifiable([
      ..._featured,
      for (final s in _online)
        if (!featuredKeys.contains(key(s))) s,
    ]);
  }

  Station? _firstVisible() {
    final visible = visibleStations;
    return visible.isEmpty
        ? (_stations.isEmpty ? null : _stations.first)
        : visible.first;
  }

  void _keepSelectionVisible() {
    final visible = visibleStations;
    if (visible.isNotEmpty && !visible.contains(_selected)) {
      _selected = visible.first;
    }
  }

  /// Opens every stream that has no recent result, a few at a time, and
  /// remembers which ones work from this network.
  Future<void> _checkStreams() async {
    final probe = _probe;
    if (probe == null || _probing) return;
    final now = _now();
    final queue = [
      for (final station in _stations)
        if (_health[station.id] == null ||
            now.difference(_health[station.id]!.checkedAt) > healthMaxAge)
          station,
    ];
    if (queue.isEmpty) return;
    _probing = true;
    _notify();
    var done = 0;
    final results = <String, StreamHealth>{};
    Future<void> worker() async {
      while (queue.isNotEmpty && !_disposed) {
        final station = queue.removeAt(0);
        final health = await probe.check(station.streamUrl);
        if (_disposed) return;
        results[station.id] = health;
        _health[station.id] = (health: health, checkedAt: _now());
        if (++done % 10 == 0) _notifyKeepingSelection();
      }
    }

    await Future.wait([for (var i = 0; i < probeConcurrency; i++) worker()]);
    if (_disposed) return;
    _probing = false;
    // Not a single stream opened: the device is offline or behind a strict
    // firewall. That says nothing about the stations, so forget this run.
    final anyOk = results.values.any((health) => health == StreamHealth.ok);
    if (!anyOk && results.length > 2) {
      results.keys.forEach(_health.remove);
      _notifyKeepingSelection();
      return;
    }
    _notifyKeepingSelection();
    await _saveHealth();
  }

  void _notifyKeepingSelection() {
    // The station that is playing never disappears from the carousel.
    if (!isActive) _keepSelectionVisible();
    _notify();
  }

  void _readHealth(String? raw) {
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      json.forEach((id, value) {
        final [ok, millis] = value! as List<Object?>;
        _health[id] = (
          health: ok == true ? StreamHealth.ok : StreamHealth.failed,
          checkedAt: DateTime.fromMillisecondsSinceEpoch(millis! as int),
        );
      });
    } on Object {
      _health.clear();
    }
  }

  Future<void> _saveHealth() => _settings.write(
    _healthKey,
    jsonEncode({
      for (final entry in _health.entries)
        entry.key: [
          entry.value.health == StreamHealth.ok,
          entry.value.checkedAt.millisecondsSinceEpoch,
        ],
    }),
  );

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
    _keepSelectionVisible();
    _notify();
  }

  /// Plays [station], or the selected station when null.
  Future<void> play([Station? station]) async {
    final target = station ?? _selected;
    if (target == null) return;
    if (!visibleStations.contains(target)) {
      _filter = null;
      if (!_scope.matches(target)) _scope = StationScope.all;
    }
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
    var index = selectedIndex;
    var target = visible[index];
    // Skip stations that are known not to work from here.
    for (var i = 0; i < visible.length; i++) {
      index = (index + delta) % visible.length;
      if (index < 0) index += visible.length;
      target = visible[index];
      if (isAvailable(target)) break;
    }
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
        final inScope = scopedStations.where(
          (s) => s.genre == genre && isAvailable(s),
        );
        final matching =
            (inScope.isNotEmpty
                    ? inScope
                    : _stations.where(
                        (s) => s.genre == genre && isAvailable(s),
                      ))
                .toList();
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
    final station = _current;
    if (kDebugMode) debugPrint('Playback error on ${station?.id}: $error');
    if (station != null) {
      _health[station.id] = (health: StreamHealth.failed, checkedAt: _now());
      unawaited(_saveHealth());
      // A featured station may have moved to a new stream address: look it up
      // in the online catalogue once before giving up.
      if (station.isFeatured &&
          _catalog != null &&
          _recovered.add(station.id)) {
        unawaited(_recover(station, _request));
        return;
      }
    }
    _status = PlaybackStatus.error;
    _trackTitle = null;
    _failedStation = station;
    _notify();
  }

  Future<void> _recover(Station station, int request) async {
    final replacement = await _catalog!.findReplacement(station);
    if (_disposed || request != _request) return; // The listener moved on.
    if (replacement == null) {
      _status = PlaybackStatus.error;
      _trackTitle = null;
      _failedStation = station;
      _notify();
      return;
    }
    final fixed = station.copyWith(streamUrl: replacement.streamUrl);
    _featured = [for (final s in _featured) s.id == station.id ? fixed : s];
    _health.remove(station.id);
    _rebuild();
    await play(fixed);
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
