import 'station.dart';

/// Which stations to show: all of them, the bundled selection, one country
/// or one broadcast language.
class StationScope {
  const StationScope._(this.key);

  static const all = StationScope._('all');
  static const featured = StationScope._('featured');
  static const belarus = StationScope._('country:BY');
  static const russia = StationScope._('country:RU');
  static const russian = StationScope._('language:ru');
  static const belarusian = StationScope._('language:be');
  static const english = StationScope._('language:en');

  /// The options offered in the app, in display order.
  static const values = [
    all,
    featured,
    belarus,
    russia,
    russian,
    belarusian,
    english,
  ];

  /// Stable id used for saving the choice.
  final String key;

  static StationScope fromKey(String? key) =>
      values.firstWhere((scope) => scope.key == key, orElse: () => all);

  bool matches(Station station) {
    if (this == all) return true;
    if (this == featured) return station.isFeatured;
    final [kind, code] = key.split(':');
    return kind == 'country'
        ? station.countryCode == code
        : station.languages.contains(code);
  }

  @override
  String toString() => 'StationScope($key)';
}
