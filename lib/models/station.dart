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
  });

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
    );
  }

  final String id;
  final String name;

  /// FM frequency in MHz, e.g. "96.2". Internet-only stations have none.
  final String? frequency;
  final LocalizedText? location;
  final LocalizedText tagline;
  final LocalizedText description;
  final String genre;

  /// ISO 639-1 code of the language the station broadcasts in.
  final String language;
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
