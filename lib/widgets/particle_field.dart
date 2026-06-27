import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Drifting pollution particles whose density, opacity and speed scale with
/// PM2.5 (§8.2). Hand-rolled with CustomPainter for performance. Pauses when
/// [animate] is false (reduce-motion / backgrounded).
class ParticleField extends StatefulWidget {
  /// PM2.5 in µg/m³ (null → treated as clean).
  final double? pm25;
  final Color accent;
  final bool animate;

  const ParticleField({
    super.key,
    required this.pm25,
    required this.accent,
    required this.animate,
  });

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late List<_Particle> _particles;
  final _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _rebuildParticles();
    if (widget.animate) _c.repeat();
  }

  void _rebuildParticles() {
    // Map PM2.5 (0..~250) to a particle count (12..160).
    final pm = (widget.pm25 ?? 0).clamp(0, 250).toDouble();
    final count = (12 + pm / 250 * 148).round();
    _particles = List.generate(count, (_) => _Particle.random(_rng));
  }

  @override
  void didUpdateWidget(covariant ParticleField old) {
    super.didUpdateWidget(old);
    if (old.pm25 != widget.pm25) _rebuildParticles();
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
    final pm = (widget.pm25 ?? 0).clamp(0, 250).toDouble();
    // Murkier air → higher base opacity & speed.
    final density = 0.15 + pm / 250 * 0.55;
    final speed = 0.4 + pm / 250 * 1.2;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              t: _c.value,
              accent: widget.accent,
              density: density,
              speed: speed,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  final double x; // 0..1
  final double y; // 0..1
  final double r; // radius px
  final double phase;
  final double drift; // horizontal sway amount

  const _Particle(this.x, this.y, this.r, this.phase, this.drift);

  factory _Particle.random(math.Random rng) => _Particle(
        rng.nextDouble(),
        rng.nextDouble(),
        1.2 + rng.nextDouble() * 2.8,
        rng.nextDouble(),
        0.02 + rng.nextDouble() * 0.06,
      );
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final Color accent;
  final double density;
  final double speed;

  _ParticlePainter({
    required this.particles,
    required this.t,
    required this.accent,
    required this.density,
    required this.speed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      // Rise slowly upward, wrapping; sway sideways with a sine.
      final progress = (p.y - t * speed) % 1.0;
      final yy = progress * size.height;
      final sway = math.sin((t + p.phase) * 2 * math.pi) * p.drift;
      final xx = ((p.x + sway) % 1.0) * size.width;

      paint.color = Color.lerp(Colors.white, accent, 0.5)!
          .withValues(alpha: density * (0.5 + 0.5 * p.phase));
      canvas.drawCircle(Offset(xx, yy), p.r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.density != density ||
      old.particles != particles;
}
