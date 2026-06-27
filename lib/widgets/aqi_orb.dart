import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The signature breathing AQI gauge (§8.2):
/// - an arc showing the AQI fraction of a 0..500 scale,
/// - a glowing center with the big number + category,
/// - count-up from 0 on load (TweenAnimationBuilder),
/// - a looping "breathe" pulse whose speed scales with the band.
class AqiOrb extends StatefulWidget {
  final int aqi;
  final Color accent;
  final String category;
  final bool animate;
  final double size;

  const AqiOrb({
    super.key,
    required this.aqi,
    required this.accent,
    required this.category,
    required this.animate,
    this.size = 260,
  });

  @override
  State<AqiOrb> createState() => _AqiOrbState();
}

class _AqiOrbState extends State<AqiOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: _breathDuration(widget.aqi),
    );
    if (widget.animate) _breath.repeat(reverse: true);
  }

  // Calm/slow when clean (~5s), agitated/fast when hazardous (~1.6s).
  Duration _breathDuration(int aqi) {
    final f = (aqi.clamp(0, 350)) / 350.0;
    final ms = (5000 - f * 3400).round();
    return Duration(milliseconds: ms);
  }

  @override
  void didUpdateWidget(covariant AqiOrb old) {
    super.didUpdateWidget(old);
    if (old.aqi != widget.aqi) {
      _breath.duration = _breathDuration(widget.aqi);
      if (widget.animate) _breath.repeat(reverse: true);
    }
    if (widget.animate && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!widget.animate && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0.5;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        // Count the value + arc up from 0 on first build / when AQI changes.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.aqi.toDouble()),
          duration: widget.animate
              ? const Duration(milliseconds: 1400)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          builder: (context, animatedAqi, _) {
            return AnimatedBuilder(
              animation: _breath,
              builder: (context, child) {
                final breathT = widget.animate
                    ? Curves.easeInOut.transform(_breath.value)
                    : 0.5;
                final scale = 0.97 + breathT * 0.06;
                final glow = 0.35 + breathT * 0.35;

                return Transform.scale(
                  scale: scale,
                  child: CustomPaint(
                    painter: _OrbPainter(
                      aqi: animatedAqi,
                      accent: widget.accent,
                      glow: glow,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            animatedAqi.round().toString(),
                            style: GoogleFonts.sora(
                              fontSize: widget.size * 0.30,
                              fontWeight: FontWeight.w200,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'US AQI',
                            style: GoogleFonts.manrope(
                              fontSize: widget.size * 0.055,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              widget.category,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: widget.size * 0.06,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double aqi;
  final Color accent;
  final double glow;

  _OrbPainter({required this.aqi, required this.accent, required this.glow});

  static const double _scaleMax = 500; // arc spans AQI 0..500
  static const double _startAngle = math.pi * 0.75; // bottom-left
  static const double _sweepTotal = math.pi * 1.5; // 270° gauge

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Outer glow halo.
    final haloPaint = Paint()
      ..color = accent.withValues(alpha: glow * 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 40 * glow + 10);
    canvas.drawCircle(center, radius * 0.78, haloPaint);

    // Inner radial fill.
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(accent, Colors.black, 0.35)!.withValues(alpha: 0.55),
          Colors.black.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.82, fillPaint);

    // Track arc.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawArc(rect, _startAngle, _sweepTotal, false, track);

    // Value arc.
    final frac = (aqi / _scaleMax).clamp(0.0, 1.0);
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepTotal,
        colors: [
          accent.withValues(alpha: 0.4),
          accent,
        ],
      ).createShader(rect);
    canvas.drawArc(rect, _startAngle, _sweepTotal * frac, false, valuePaint);

    // Glowing tip at the end of the value arc.
    final tipAngle = _startAngle + _sweepTotal * frac;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      9,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(tip, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.aqi != aqi || old.accent != accent || old.glow != glow;
}
