import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/station.dart';

/// Client for the free Radio Browser directory (https://www.radio-browser.info).
///
/// Radio Browser checks every stream once a day; `hidebroken=true` leaves out
/// stations whose last check failed, so the app only gets working streams.
class RadioBrowserClient {
  RadioBrowserClient({
    http.Client? client,
    List<String>? servers,
    Random? random,
  }) : _client = client ?? http.Client(),
       _servers = List.of(servers ?? defaultServers)
         ..shuffle(random ?? Random());

  /// Public mirrors. Requests go to a random one first and fail over to the rest.
  static const defaultServers = [
    'de1.api.radio-browser.info',
    'de2.api.radio-browser.info',
    'fi1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
  ];

  static const _timeout = Duration(seconds: 12);
  static const _userAgent =
      'RadioApp/1.0 (+https://github.com/Staery/radioapp)';

  final http.Client _client;
  final List<String> _servers;

  /// Stations by country code ("BY") and/or language name ("russian"),
  /// most voted first.
  Future<List<Station>> search({
    String? countryCode,
    String? language,
    String? name,
    int limit = 100,
    bool hideBroken = true,
  }) async {
    final rows = await _get('/json/stations/search', {
      'countrycode': ?countryCode,
      'language': ?language,
      'name': ?name,
      'hidebroken': '$hideBroken',
      'order': 'votes',
      'reverse': 'true',
      'limit': '$limit',
    });
    return parseStations(rows);
  }

  /// The most voted stations worldwide.
  Future<List<Station>> topVoted({int limit = 80}) => search(limit: limit);

  Future<List<Object?>> _get(String path, Map<String, String> query) async {
    Object? lastError;
    for (final server in _servers) {
      try {
        final response = await _client
            .get(
              Uri.https(server, path, query),
              headers: kIsWeb ? const {} : const {'User-Agent': _userAgent},
            )
            .timeout(_timeout);
        if (response.statusCode != 200) {
          lastError = http.ClientException(
            'HTTP ${response.statusCode}',
            response.request?.url,
          );
          continue;
        }
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is List<Object?>) return body;
        lastError = const FormatException('Expected a JSON list');
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw RadioBrowserException('All Radio Browser servers failed: $lastError');
  }

  /// Turns Radio Browser rows into stations and drops unusable ones.
  static List<Station> parseStations(List<Object?> rows) => [
    for (final row in rows)
      if (row is Map<String, Object?>) ?stationFromJson(row),
  ];

  /// Maps one Radio Browser station; returns null when it has no usable stream.
  static Station? stationFromJson(Map<String, Object?> json) {
    String text(String key) => (json[key] as String? ?? '').trim();

    final uuid = text('stationuuid');
    final name = text('name').replaceAll(RegExp(r'\s+'), ' ');
    var url = text('url_resolved');
    if (url.isEmpty) url = text('url');
    final uri = Uri.tryParse(url);
    if (uuid.isEmpty ||
        name.isEmpty ||
        uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    // Browsers block plain-http audio on an https page.
    if (kIsWeb && uri.isScheme('http')) return null;

    final tags = text('tags')
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final languages = _languageCodes(text('languagecodes'), text('language'));
    final countryCode = text('countrycode').toUpperCase();
    final country = text('country');
    final codec = text('codec');
    final bitrate = (json['bitrate'] as num?)?.toInt() ?? 0;
    final logo = text('favicon');

    final tagline = tags.isEmpty
        ? (country.isEmpty ? 'Internet radio' : country)
        : tags.take(3).join(' · ');
    final quality = [
      if (codec.isNotEmpty && codec.toUpperCase() != 'UNKNOWN') codec,
      if (bitrate > 0) '$bitrate kbps',
    ].join(' ');

    return Station(
      id: 'rb:$uuid',
      name: name,
      frequency: frequencyFromName(name),
      tagline: LocalizedText({'en': tagline}),
      description: LocalizedText({
        'en': [
          if (tags.isNotEmpty) tags.take(6).join(', '),
          if (quality.isNotEmpty) quality,
        ].join(' · ').ifEmpty(name),
      }),
      location: countryCode.isEmpty && country.isEmpty
          ? null
          : localizedCountry(countryCode, country),
      genre: genreFromTags(tags),
      language: languages.isEmpty ? '' : languages.first,
      languages: languages,
      countryCode: countryCode.isEmpty ? null : countryCode,
      color: colorFor(uuid),
      streamUrl: url,
      logoUrl: Uri.tryParse(logo)?.isScheme('https') ?? false ? logo : null,
      isFeatured: false,
    );
  }

  /// "Radio Mir 104.2 FM" → "104.2".
  static String? frequencyFromName(String name) {
    final match = RegExp(
      r'\b(8[7-9]|9\d|10[0-8])[.,](\d)\s*(?:FM|ФМ)?\b',
      caseSensitive: false,
    ).firstMatch(name);
    return match == null ? null : '${match[1]}.${match[2]}';
  }

  /// Maps free-form tags onto the genres the app knows.
  static String genreFromTags(List<String> tags) {
    final text = ' ${tags.join(' ').toLowerCase()} ';
    bool any(List<String> words) => words.any(text.contains);
    if (any(['news', 'talk', 'information', 'новост', 'навін', 'информ'])) {
      return 'news';
    }
    if (any([
      'classical',
      'classic music',
      'opera',
      'symphon',
      'baroque',
      'классическ',
      'класічн',
    ])) {
      return 'classical';
    }
    if (any(['jazz', 'blues', 'swing', 'джаз'])) return 'jazz';
    if (any(['chanson', 'шансон'])) return 'chanson';
    if (any(['comedy', 'humor', 'humour', 'юмор', 'гумар'])) return 'humor';
    if (any([
      'chill',
      'ambient',
      'lounge',
      'relax',
      'downtempo',
      'easy listening',
    ])) {
      return 'chill';
    }
    if (any(['hip hop', 'hip-hop', 'hiphop', 'rap', 'r&b', 'rnb'])) {
      return 'hiphop';
    }
    if (any([
      'electro',
      'dance',
      'house',
      'techno',
      'trance',
      'edm',
      'club',
      'drum and bass',
      'dnb',
    ])) {
      return 'electronic';
    }
    if (any(['indie', 'alternative'])) return 'indie';
    if (any(['rock', 'metal', 'punk', 'рок'])) return 'rock';
    if (any([
      'oldies',
      'retro',
      ' 60s',
      ' 70s',
      ' 80s',
      ' 90s',
      'ретро',
      'рэтра',
      'disco',
    ])) {
      return 'retro';
    }
    if (any(['pop', 'hits', 'top 40', 'top40', 'chart', 'эстрад', 'хит'])) {
      return 'pop';
    }
    return 'other';
  }

  static const _languageNames = {
    'russian': 'ru',
    'belarusian': 'be',
    'english': 'en',
    'ukrainian': 'uk',
    'polish': 'pl',
    'german': 'de',
    'french': 'fr',
    'spanish': 'es',
    'italian': 'it',
    'lithuanian': 'lt',
    'latvian': 'lv',
    'kazakh': 'kk',
    'czech': 'cs',
    'dutch': 'nl',
    'portuguese': 'pt',
  };

  static List<String> _languageCodes(String codes, String names) {
    final result = <String>[
      for (final code in codes.split(','))
        if (code.trim().length == 2) code.trim().toLowerCase(),
    ];
    for (final name in names.toLowerCase().split(',')) {
      final code = _languageNames[name.trim()];
      if (code != null && !result.contains(code)) result.add(code);
    }
    return result;
  }

  static const _countryNames = {
    'BY': ('Belarus', 'Беларусь', 'Беларусь'),
    'RU': ('Russia', 'Россия', 'Расія'),
    'UA': ('Ukraine', 'Украина', 'Украіна'),
    'PL': ('Poland', 'Польша', 'Польшча'),
    'LT': ('Lithuania', 'Литва', 'Літва'),
    'LV': ('Latvia', 'Латвия', 'Латвія'),
    'KZ': ('Kazakhstan', 'Казахстан', 'Казахстан'),
    'US': ('United States', 'США', 'ЗША'),
    'GB': ('United Kingdom', 'Великобритания', 'Вялікабрытанія'),
    'DE': ('Germany', 'Германия', 'Германія'),
    'FR': ('France', 'Франция', 'Францыя'),
    'CH': ('Switzerland', 'Швейцария', 'Швейцарыя'),
    'IT': ('Italy', 'Италия', 'Італія'),
    'ES': ('Spain', 'Испания', 'Іспанія'),
    'NL': ('Netherlands', 'Нидерланды', 'Нідэрланды'),
    'CA': ('Canada', 'Канада', 'Канада'),
  };

  static LocalizedText localizedCountry(String code, String fallback) {
    final names = _countryNames[code];
    if (names == null) {
      return LocalizedText({'en': fallback.isEmpty ? code : fallback});
    }
    return LocalizedText({'en': names.$1, 'ru': names.$2, 'be': names.$3});
  }

  static const _palette = [
    0xFF8B5CF6,
    0xFFEC4899,
    0xFF0EA5E9,
    0xFF10B981,
    0xFFF97316,
    0xFFEF4444,
    0xFF6366F1,
    0xFF14B8A6,
    0xFFF59E0B,
    0xFF84CC16,
    0xFFD946EF,
    0xFF06B6D4,
  ];

  /// A stable colour per station, so a station keeps its colour between runs.
  static Color colorFor(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return Color(_palette[hash % _palette.length]);
  }

  void close() => _client.close();
}

class RadioBrowserException implements Exception {
  const RadioBrowserException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
