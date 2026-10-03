import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/station.dart';
import '../theme.dart';
import 'equalizer.dart';
import '../l10n.dart';

/// Large card shown in the station carousel.
class StationCard extends StatelessWidget {
  const StationCard({
    super.key,
    required this.station,
    required this.isFavorite,
    required this.isPlaying,
    required this.onTap,
    required this.onFavorite,
  });

  final Station station;
  final bool isFavorite;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.languageCode;
    final color = station.color;
    final dark = Color.lerp(color, Colors.black, 0.55)!;

    return Semantics(
      button: true,
      label: '${station.name}, ${station.tagline.of(lang)}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, dark],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _WavesPainter())),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Pill(
                            icon: genreIcon(station.genre),
                            label: genreLabel(l10n, station.genre),
                          ),
                          const SizedBox(width: 8),
                          _Pill(label: station.language.toUpperCase()),
                          const Spacer(),
                          IconButton(
                            tooltip: isFavorite
                                ? l10n.removeFavorite
                                : l10n.addFavorite,
                            onPressed: onFavorite,
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(isFavorite),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _Dial(station: station),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              station.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (isPlaying) ...[
                            const SizedBox(width: 10),
                            const Equalizer(active: true, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        station.tagline.of(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      if (station.location != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.place_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                station.location!.of(lang),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big frequency ("96.2 FM") or the station initials for internet radio.
class _Dial extends StatelessWidget {
  const _Dial({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final frequency = station.frequency;
    if (frequency != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            frequency,
            style: const TextStyle(
              fontSize: 76,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -3,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'FM',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(
          Icons.public_rounded,
          size: 30,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 10),
        Text(
          context.l10n.online,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.9),
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Concentric arcs in the corner, like radio waves.
class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 1.02, size.height * 0.52);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 1; i <= 6; i++) {
      paint.color = Colors.white.withValues(alpha: 0.12 - i * 0.015);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 46.0 * i),
        math.pi * 0.55,
        math.pi * 0.9,
        false,
        paint,
      );
    }
    canvas.drawCircle(
      center,
      18,
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
