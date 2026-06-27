import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen living gradient that slowly drifts forever and morphs toward
/// the AQI band [accent] (§8.2). Recolors smoothly via an implicit tween on
/// the accent; the drift is driven by a looping controller.
///
/// Set [animate] false (reduce-motion) for a clean static gradient.
class LivingBackground extends StatefulWidget {
  final Color accent;
  final bool animate;
  final Widget child;

  const LivingBackground({
    super.key,
    required this.accent,
    required this.animate,
    required this.child,
  });

  @override
  State<LivingBackground> createState() => _LivingBackgroundState();
}

class _LivingBackgroundState extends State<LivingBackground>
    with SingleTickerProviderStateMixin {
  static const Color _base = Color(0xFF0A0E14);

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant LivingBackground old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tween the accent itself so band changes recolor smoothly (§8.2).
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: widget.accent),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, accent, _) {
        final a = accent ?? widget.accent;
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = _c.value; // 0..1
              // Drift the gradient endpoints around in a slow circle.
              final dx = 0.6 * _wave(t);
              final dy = 0.6 * _wave(t + 0.33);
              final begin = Alignment(-1 + dx, -1 + dy);
              final end = Alignment(1 - dx, 1 - dy);

              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: begin,
                    end: end,
                    colors: [
                      _base,
                      Color.lerp(_base, a, 0.22)!,
                      Color.lerp(_base, a, 0.42)!,
                      _base,
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
                child: child,
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }

  /// Smooth 0..1 oscillation.
  double _wave(double t) {
    final x = (t % 1.0) * 2 * math.pi;
    return 0.5 * (1 + math.sin(x));
  }
}
