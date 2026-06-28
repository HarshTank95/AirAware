import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/air_quality.dart';
import '../widgets/living_background.dart';
import '../widgets/share_card.dart';

/// Previews a shareable air-quality card and exports it as a PNG via the
/// system share sheet.
class ShareScreen extends StatefulWidget {
  final AirQuality reading;
  final String placeLabel;
  final bool sensitive;
  final bool reduceMotion;

  const ShareScreen({
    super.key,
    required this.reading,
    required this.placeLabel,
    required this.sensitive,
    required this.reduceMotion,
  });

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('Could not render card.');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/airaware_card.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text:
              'Air quality in ${widget.placeLabel}: AQI ${widget.reading.usAqi} '
              '(${widget.reading.band.category}). — via AirAware',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't share: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.reading.band.color;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: LivingBackground(
        accent: accent,
        animate: !widget.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Expanded(
                child: Center(
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: ShareCard(
                      reading: widget.reading,
                      placeLabel: widget.placeLabel,
                      sensitive: widget.sensitive,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _share,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.ios_share),
                    label: Text(
                      _busy ? 'Preparing…' : 'Share air card',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
