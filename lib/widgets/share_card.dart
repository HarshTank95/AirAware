import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/air_quality.dart';
import 'aqi_orb.dart';

/// A self-contained, image-friendly card summarising the current air quality.
/// Rendered into a PNG for sharing (no glass/blur — those don't capture well).
class ShareCard extends StatelessWidget {
  final AirQuality reading;
  final String placeLabel;
  final bool sensitive;

  const ShareCard({
    super.key,
    required this.reading,
    required this.placeLabel,
    required this.sensitive,
  });

  @override
  Widget build(BuildContext context) {
    final band = reading.band;
    final accent = band.color;
    final verdict = band.verdict(sensitive: sensitive);
    const base = Color(0xFF0A0E14);
    final now = DateTime.now();

    return Container(
      width: 360,
      height: 540,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base,
            Color.lerp(base, accent, 0.32)!,
            base,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'AIRAWARE',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            placeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            _date(now),
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
          Center(
            child: AqiOrb(
              aqi: reading.usAqi,
              accent: accent,
              category: band.category,
              animate: false,
              size: 210,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              verdict,
              style: GoogleFonts.manrope(
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'US AQI · ${band.category}',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              Text(
                'data: Open-Meteo',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime t) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.day} ${months[t.month]} ${t.year} · $h:$m';
  }
}
