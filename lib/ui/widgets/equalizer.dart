import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated bars that show a station is live. Static when [active] is false.
class Equalizer extends StatefulWidget {
  const Equalizer({
    super.key,
    required this.active,
    this.color = Colors.white,
    this.size = 16,
  });

  final bool active;
  final Color color;
  final double size;

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(Equalizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _BarsPainter(
            t: widget.active ? _controller.value : null,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.t, required this.color});

  /// Animation phase 0..1, or null for the resting state.
  final double? t;
  final Color color;

  static const _phases = [0.0, 0.35, 0.7, 0.15];
  static const _resting = [0.35, 0.6, 0.45, 0.3];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final count = _phases.length;
    final gap = size.width * 0.12;
    final barWidth = (size.width - gap * (count - 1)) / count;
    for (var i = 0; i < count; i++) {
      final level = t == null
          ? _resting[i]
          : 0.25 +
                0.75 *
                    (0.5 +
                        0.5 *
                            math.sin(
                              2 * math.pi * (t! * (1 + i * 0.3) + _phases[i]),
                            ));
      final height = size.height * level;
      final left = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          size.height - height,
          left + barWidth,
          size.height,
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.t != t || old.color != color;
}
