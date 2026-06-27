import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/place.dart';
import '../services/geocoding_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/living_background.dart';

/// City search (§7). Returns the chosen [Place] via Navigator.pop.
class SearchScreen extends StatefulWidget {
  final GeocodingService service;
  final bool reduceMotion;

  const SearchScreen({
    super.key,
    required this.service,
    required this.reduceMotion,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<Place> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(value));
  }

  Future<void> _run(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.service.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed. Check your connection.';
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4CAF50);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: LivingBackground(
        accent: accent,
        animate: !widget.reduceMotion,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Text(
                      'Search a city',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  radius: 18,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    onSubmitted: _run,
                    textInputAction: TextInputAction.search,
                    style: GoogleFonts.manrope(color: Colors.white),
                    cursorColor: accent,
                    decoration: InputDecoration(
                      hintText: 'e.g. Surat, London, Tokyo…',
                      hintStyle: GoogleFonts.manrope(color: Colors.white38),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white54),
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _body(accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(Color accent) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: accent, strokeWidth: 3),
      );
    }
    if (_error != null) {
      return _message(_error!);
    }
    if (_searched && _results.isEmpty) {
      return _message('No cities found.');
    }
    if (_results.isEmpty) {
      return _message('Type a city name to begin.');
    }

    return AnimationLimiter(
      child: ListView.separated(
        itemCount: _results.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final place = _results[i];
          return AnimationConfiguration.staggeredList(
            position: i,
            duration: Duration(milliseconds: widget.reduceMotion ? 0 : 350),
            child: SlideAnimation(
              verticalOffset: 30,
              child: FadeInAnimation(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(place);
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.location_city, color: Colors.white70),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              [place.admin1, place.country]
                                  .where((e) =>
                                      e != null && e.trim().isNotEmpty)
                                  .join(', '),
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white38),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _message(String text) {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 15,
        ),
      ),
    );
  }
}
