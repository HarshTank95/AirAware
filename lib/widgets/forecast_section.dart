import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/forecast.dart';
import 'glass_card.dart';

/// Forecast block for Home: a 24-hour AQI curve + a 7-day outlook row.
class ForecastSection extends StatelessWidget {
  final List<HourlyAqi> upcoming; // next ~24h, time-ordered
  final List<DailyAqi> daily; // up to 7 days
  final Color accent;
  final bool animate;

  const ForecastSection({
    super.key,
    required this.upcoming,
    required this.daily,
    required this.accent,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (upcoming.length >= 2) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Next 24 hours'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  child: _HourlyCurve(
                    points: upcoming.take(24).toList(),
                    accent: accent,
                    animate: animate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (daily.isNotEmpty)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('${daily.length}-day outlook'),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    // Fit chips evenly across the available width.
                    final w = (c.maxWidth / daily.length).clamp(38.0, 80.0);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: daily
                          .map((d) => SizedBox(
                                width: w,
                                child: _DayChip(day: d),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      );
}

class _DayChip extends StatelessWidget {
  final DailyAqi day;
  const _DayChip({required this.day});

  static const _weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = day.date.year == now.year &&
        day.date.month == now.month &&
        day.date.day == now.day;
    return Column(
      children: [
        Text(
          isToday ? 'Today' : _weekdays[day.date.weekday],
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: Colors.white.withValues(alpha: isToday ? 0.95 : 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: day.band.color.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: day.band.color.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            day.peakAqi.toString(),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _HourlyCurve extends StatelessWidget {
  final List<HourlyAqi> points;
  final Color accent;
  final bool animate;

  const _HourlyCurve({
    required this.points,
    required this.accent,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: animate ? const Duration(milliseconds: 1100) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        painter: _CurvePainter(points: points, accent: accent, progress: t),
        size: Size.infinite,
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final List<HourlyAqi> points;
  final Color accent;
  final double progress;

  _CurvePainter({
    required this.points,
    required this.accent,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    const labelH = 18.0;
    final chartH = size.height - labelH;
    final maxAqi = points.map((p) => p.usAqi).reduce((a, b) => a > b ? a : b);
    final ceil = (maxAqi < 100 ? 100 : maxAqi) * 1.15;
    final dx = size.width / (points.length - 1);

    double yFor(int aqi) => chartH - (aqi / ceil) * chartH;

    // Build the line path.
    final line = Path();
    final pts = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final o = Offset(i * dx, yFor(points[i].usAqi));
      pts.add(o);
      if (i == 0) {
        line.moveTo(o.dx, o.dy);
      } else {
        // Smooth with a simple midpoint quadratic.
        final prev = pts[i - 1];
        final mid = Offset((prev.dx + o.dx) / 2, (prev.dy + o.dy) / 2);
        line.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
    }

    // Reveal left-to-right with progress via a clip.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    // Filled area under the line.
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, chartH)
      ..lineTo(pts.first.dx, chartH)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.45),
            accent.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );

    // "Now" marker at the start.
    canvas.drawCircle(pts.first, 4, Paint()..color = Colors.white);
    canvas.restore();

    // Hour labels every 6h (drawn unclipped).
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < points.length; i += 6) {
      final hour = points[i].time.hour.toString().padLeft(2, '0');
      tp.text = TextSpan(
        text: i == 0 ? 'now' : '${hour}h',
        style: GoogleFonts.manrope(
          fontSize: 10,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      );
      tp.layout();
      final x = (i * dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, chartH + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.points != points;
}
