import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/station.dart';
import '../../state/radio_controller.dart';
import '../theme.dart';
import '../widgets/equalizer.dart';
import '../l10n.dart';

/// Searchable list of every station.
class StationsSheet extends StatefulWidget {
  const StationsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<RadioController>(),
      child: const StationsSheet(),
    ),
  );

  @override
  State<StationsSheet> createState() => _StationsSheetState();
}

class _StationsSheetState extends State<StationsSheet> {
  String _query = '';

  bool _matches(Station s) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final l10n = context.l10n;
    return [
      s.name,
      s.genre,
      genreLabel(l10n, s.genre),
      s.frequency ?? '',
      ...s.tagline.values.values,
      ...?s.location?.values.values,
    ].any((field) => field.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final radio = context.watch<RadioController>();
    final stations = radio.stations.where(_matches).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.allStations,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  context.l10n.stationCount(radio.stations.length),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: context.l10n.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: stations.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.nothingFound,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    itemCount: stations.length,
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      return _StationTile(
                        station: station,
                        favorite: radio.isFavorite(station),
                        playing: radio.isCurrent(station),
                        onTap: () {
                          Navigator.of(context).pop();
                          radio.play(station);
                        },
                        onFavorite: () => radio.toggleFavorite(station),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.station,
    required this.favorite,
    required this.playing,
    required this.onTap,
    required this.onFavorite,
  });

  final Station station;
  final bool favorite;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      tileColor: playing ? station.color.withValues(alpha: 0.14) : null,
      leading: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              station.color,
              Color.lerp(station.color, Colors.black, 0.5)!,
            ],
          ),
        ),
        child: playing
            ? const Equalizer(active: true, size: 18)
            : station.frequency != null
            ? Text(
                station.frequency!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.white,
                ),
              )
            : Icon(genreIcon(station.genre), color: Colors.white, size: 22),
      ),
      title: Text(
        station.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${genreLabel(context.l10n, station.genre)} · '
        '${station.tagline.of(context.languageCode)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      trailing: IconButton(
        tooltip: favorite
            ? context.l10n.removeFavorite
            : context.l10n.addFavorite,
        onPressed: onFavorite,
        icon: Icon(
          favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: favorite ? const Color(0xFFF472B6) : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
