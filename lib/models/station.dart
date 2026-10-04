import 'dart:ui' show Color;

/// Text in several languages, e.g. `{"en": "Jazz", "ru": "Джаз"}`.
class LocalizedText {
  const LocalizedText(this.values);

  /// Accepts either a plain string (same text in every language) or a map
  /// from language code to text.
  factory LocalizedText.fromJson(Object? json, String field) {
    if (json is String && json.trim().isNotEmpty) {
      return LocalizedText({'en': json.trim()});
    }
    if (json is Map<String, Object?> && json.isNotEmpty) {
      final values = <String, String>{};
      for (final entry in json.entries) {
        final value = entry.value;
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('Station field "$field.${entry.key}" is empty');
        }
        values[entry.key.toLowerCase()] = value.trim();
      }
      return LocalizedText(values);
    }
    throw FormatException('Station field "$field" is missing or empty');
  }

  final Map<String, String> values;

  /// Text for [languageCode], falling back to English, then to any language.
  String of(String languageCode) =>
      values[languageCode] ?? values['en'] ?? values.values.first;

  Map<String, String> toJson() => values;

  @override
  String toString() => of('en');
}

/// A radio station from `assets/stations.json`.
class Station {
  const Station({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.genre,
    required this.language,
    required this.color,
    required this.streamUrl,
    this.frequency,
    this.location,
    this.countryCode,
    List<String> languages = const [],
    this.logoUrl,
    this.isFeatured = true,
  }) : _languages = languages; // ignore: prefer_initializing_formals

  factory Station.fromJson(Map<String, Object?> json) {
    String required(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Station field "$key" is missing or empty', json);
      }
      return value.trim();
    }

    final location = json['location'];
    final streamUrl = required('streamUrl');
    final uri = Uri.tryParse(streamUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw FormatException('Station stream URL is not http(s): $streamUrl');
    }

    final countryCode = (json['country'] as String?)?.trim().toUpperCase();
    final languages = (json['languages'] as List<Object?>?)
        ?.whereType<String>()
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toList();
    final logo = (json['logo'] as String?)?.trim();

    return Station(
      id: required('id'),
      name: required('name'),
      tagline: LocalizedText.fromJson(json['tagline'], 'tagline'),
      description: LocalizedText.fromJson(json['description'], 'description'),
      genre: required('genre').toLowerCase(),
      language: required('language').toLowerCase(),
      color: parseColor(required('color')),
      streamUrl: streamUrl,
      frequency: (json['frequency'] as String?)?.trim(),
      location: location == null
          ? null
          : LocalizedText.fromJson(location, 'location'),
      countryCode: countryCode == null || countryCode.isEmpty
          ? null
          : countryCode,
      languages: languages ?? const [],
      logoUrl: logo == null || logo.isEmpty ? null : logo,
      isFeatured: json['featured'] as bool? ?? true,
    );
  }

  /// The same shape that [Station.fromJson] reads; used for the catalogue cache.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'frequency': frequency,
    'location': location?.toJson(),
    'tagline': tagline.toJson(),
    'description': description.toJson(),
    'genre': genre,
    'language': language,
    'languages': languages,
    'country': countryCode,
    'color': '0x${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
    'streamUrl': streamUrl,
    'logo': logoUrl,
    'featured': isFeatured,
  };

  Station copyWith({String? streamUrl}) => Station(
    id: id,
    name: name,
    tagline: tagline,
    description: description,
    genre: genre,
    language: language,
    color: color,
    streamUrl: streamUrl ?? this.streamUrl,
    frequency: frequency,
    location: location,
    countryCode: countryCode,
    languages: languages,
    logoUrl: logoUrl,
    isFeatured: isFeatured,
  );

  final String id;
  final String name;

  /// FM frequency in MHz, e.g. "96.2". Internet-only stations have none.
  final String? frequency;
  final LocalizedText? location;
  final LocalizedText tagline;
  final LocalizedText description;
  final String genre;

  /// ISO 639-1 code of the main language the station broadcasts in.
  final String language;

  final List<String> _languages;

  /// Every language the station broadcasts in, [language] first.
  List<String> get languages =>
      _languages.isNotEmpty || language.isEmpty ? _languages : [language];

  /// ISO 3166-1 alpha-2 code of the station's country, e.g. "BY".
  final String? countryCode;

  /// Station logo from the online catalogue, when there is one.
  final String? logoUrl;

  /// True for the bundled, hand-picked stations; false for stations from the
  /// online catalogue.
  final bool isFeatured;
  final Color color;
  final String streamUrl;

  /// "96.2 FM" for broadcast stations, otherwise the station name.
  String get displayFrequency => frequency == null ? name : '$frequency FM';

  /// Parses "0xFFRRGGBB", "#RRGGBB" or "#AARRGGBB".
  static Color parseColor(String value) {
    var hex = value.trim().toLowerCase();
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    } else if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }
    if (hex.length == 6) hex = 'ff$hex';
    final parsed = hex.length == 8 ? int.tryParse(hex, radix: 16) : null;
    if (parsed == null) throw FormatException('Invalid color: $value');
    return Color(parsed);
  }

  @override
  bool operator ==(Object other) => other is Station && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Station($id, $name)';
}
