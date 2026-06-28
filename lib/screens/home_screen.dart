import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/air_quality.dart';
import '../models/forecast.dart';
import '../models/place.dart';
import '../models/user_prefs.dart';
import '../services/air_quality_service.dart';
import '../services/background_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../utils/aqi.dart';
import '../utils/insights.dart';
import '../widgets/aqi_orb.dart';
import '../widgets/forecast_section.dart';
import '../widgets/glass_card.dart';
import '../widgets/living_background.dart';
import '../widgets/particle_field.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'share_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _storage = StorageService();
  final _airService = AirQualityService();
  final _locationService = LocationService();

  UserPrefs _prefs = const UserPrefs();
  Place? _place;
  AirQuality? _reading;
  List<HourlyAqi> _hourly = const [];
  List<Place> _saved = const [];
  String _timezone = '';

  bool _loading = true;
  String? _error;
  bool _offline = false;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On-open / resume check (§5.4 guaranteed path).
    if (state == AppLifecycleState.resumed && _place != null) {
      _refresh(silent: true);
    }
  }

  bool get _reduceMotion =>
      _prefs.reduceMotion || MediaQuery.maybeOf(context)?.disableAnimations == true;

  Future<void> _bootstrap() async {
    _prefs = await _storage.loadPrefs();
    _saved = await _storage.loadSavedPlaces();

    final lastPlace = await _storage.loadLastPlace();
    if (lastPlace != null) {
      setState(() => _place = lastPlace);
      await _refresh();
    } else {
      await _resolveLocationThenFetch();
    }

    // Register the periodic check if alerts are on (request permission first).
    if (_prefs.alertsEnabled) {
      await NotificationService.instance.requestPermission();
      await BackgroundService.registerDailyCheck();
    }
  }

  /// GPS-first, fall back to search screen if denied/unavailable.
  Future<void> _resolveLocationThenFetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _locationService.getCurrent();
    if (result.status == LocationStatus.ok && result.place != null) {
      await _setPlace(result.place!, fetch: true);
    } else {
      // No location — try cached, else send the user to search.
      final cached = await _storage.loadCachedReading();
      if (cached != null) {
        final label = await _storage.loadCachedPlaceLabel() ?? 'Last location';
        final cachedHourly = await _storage.loadCachedHourly();
        setState(() {
          _reading = cached;
          _hourly = cachedHourly;
          _offline = true;
          _loading = false;
          _place = Place(name: label, latitude: 0, longitude: 0);
        });
      } else if (mounted) {
        setState(() => _loading = false);
        _openSearch();
      }
    }
  }

  Future<void> _setPlace(Place place, {bool fetch = true, bool save = false}) async {
    setState(() {
      _place = place;
      _bannerDismissed = false;
    });
    await _storage.saveLastPlace(place);
    if (save) {
      final updated = await _storage.addSavedPlace(place);
      if (mounted) setState(() => _saved = updated);
    }
    if (fetch) await _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    final place = _place;
    if (place == null) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final bundle = await _airService.fetchBundle(
        latitude: place.latitude,
        longitude: place.longitude,
      );
      await _storage.saveCachedReading(bundle.current, place.label);
      await _storage.saveCachedHourly(bundle.hourly);
      if (!mounted) return;
      setState(() {
        _reading = bundle.current;
        _hourly = bundle.hourly;
        _timezone = bundle.timezone;
        _offline = false;
        _loading = false;
        _error = null;
      });
      // Refresh the scheduled daily reports with the latest forecast.
      await _scheduleReportsIfEnabled();
      // Push the reading to the home-screen widget.
      await WidgetService.update(reading: bundle.current, placeName: place.name);
    } catch (_) {
      // Offline → show cached reading + forecast if we have them (§5.5).
      final cached = await _storage.loadCachedReading();
      final cachedHourly = await _storage.loadCachedHourly();
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _reading = cached;
          _hourly = cachedHourly;
          _offline = true;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = "Couldn't load air quality.";
        });
      }
    }
  }

  // ----- Navigation -----

  Future<void> _openSearch() async {
    final picked = await Navigator.of(context).push<Place>(
      _sharedAxisRoute(SearchScreen(
        service: GeocodingService(),
        reduceMotion: _reduceMotion,
      )),
    );
    if (picked != null) {
      HapticFeedback.lightImpact();
      await _setPlace(picked, fetch: true, save: true);
    }
  }

  /// Switch to the device's current GPS location.
  Future<void> _useCurrentLocation() async {
    final result = await _locationService.getCurrent();
    if (!mounted) return;
    if (result.status == LocationStatus.ok && result.place != null) {
      HapticFeedback.lightImpact();
      await _setPlace(result.place!, fetch: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location unavailable. Try a city search.')),
      );
    }
  }

  Future<void> _removeSavedPlace(Place place) async {
    final updated = await _storage.removeSavedPlace(place);
    if (mounted) setState(() => _saved = updated);
  }

  /// (Re)schedule the morning/evening summaries with the latest forecast, or
  /// cancel them if reports are off.
  Future<void> _scheduleReportsIfEnabled() async {
    final reading = _reading;
    final place = _place;
    if (!_prefs.reportsEnabled || reading == null || place == null) {
      await NotificationService.instance.cancelDailyReports();
      return;
    }
    final content = Insights.buildReports(
      placeLabel: place.name,
      current: reading,
      hourly: _hourly,
      sensitive: _prefs.sensitive,
    );
    await NotificationService.instance.scheduleDailyReports(
      tzName: _timezone,
      morningTitle: content.morningTitle,
      morningBody: content.morningBody,
      eveningTitle: content.eveningTitle,
      eveningBody: content.eveningBody,
    );
  }

  /// Bottom sheet to switch between saved locations / GPS / add a new city.
  Future<void> _openLocationSheet() async {
    HapticFeedback.lightImpact();
    final accent = _reading?.band.color ?? AqiBand.forValue(0).color;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF12161F).withValues(alpha: 0.92),
                    border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Your locations',
                              style: GoogleFonts.sora(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _sheetTile(
                          icon: Icons.my_location,
                          accent: accent,
                          title: 'Use my current location',
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            _useCurrentLocation();
                          },
                        ),
                        if (_saved.isNotEmpty)
                          const Divider(height: 1, color: Colors.white12),
                        ..._saved.map((place) {
                          final selected = _place != null &&
                              (_place!.latitude - place.latitude).abs() <
                                  0.005 &&
                              (_place!.longitude - place.longitude).abs() <
                                  0.005;
                          return _sheetTile(
                            icon: selected
                                ? Icons.radio_button_checked
                                : Icons.location_city,
                            accent: accent,
                            title: place.name,
                            subtitle: [place.admin1, place.country]
                                .where((e) =>
                                    e != null && e.trim().isNotEmpty)
                                .join(', '),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white38, size: 20),
                              onPressed: () async {
                                await _removeSavedPlace(place);
                                setSheetState(() {});
                              },
                            ),
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              _setPlace(place, fetch: true);
                            },
                          );
                        }),
                        const Divider(height: 1, color: Colors.white12),
                        _sheetTile(
                          icon: Icons.add,
                          accent: accent,
                          title: 'Add a city',
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            _openSearch();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required Color accent,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: accent),
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: (subtitle != null && subtitle.isNotEmpty)
          ? Text(
              subtitle,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            )
          : null,
      trailing: trailing,
    );
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<SettingsResult>(
      _sharedAxisRoute(SettingsScreen(
        initial: _prefs,
        currentPlaceLabel: _place?.label,
        storage: _storage,
      )),
    );
    if (result == null) return;

    setState(() => _prefs = result.prefs);
    // Sync background task with the alerts toggle.
    if (_prefs.alertsEnabled) {
      await BackgroundService.registerDailyCheck();
    } else {
      await BackgroundService.cancelDailyCheck();
    }
    // Sync the scheduled morning/evening reports.
    await _scheduleReportsIfEnabled();

    if (result.changeLocation) {
      await _openSearch();
    }
  }

  void _openShare() {
    final reading = _reading;
    final place = _place;
    if (reading == null || place == null) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      _sharedAxisRoute(ShareScreen(
        reading: reading,
        placeLabel: place.label,
        sensitive: _prefs.sensitive,
        reduceMotion: _reduceMotion,
      )),
    );
  }

  PageRoute<T> _sharedAxisRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: Duration(milliseconds: _reduceMotion ? 0 : 350),
      reverseTransitionDuration: Duration(milliseconds: _reduceMotion ? 0 : 300),
      pageBuilder: (context, anim, secAnim) => page,
      transitionsBuilder: (_, anim, secAnim, child) => SharedAxisTransition(
        animation: anim,
        secondaryAnimation: secAnim,
        transitionType: SharedAxisTransitionType.vertical,
        child: child,
      ),
    );
  }

  // ----- Build -----

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    final band = reading?.band ?? AqiBand.forValue(0);
    final accent = band.color;

    final showBanner = reading != null &&
        !_bannerDismissed &&
        reading.usAqi > _prefs.alertThreshold;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: LivingBackground(
        accent: accent,
        animate: !_reduceMotion,
        child: Stack(
          children: [
            // Pollution particle layer behind the glass.
            Positioned.fill(
              child: ParticleField(
                pm25: reading?.pm25,
                accent: accent,
                animate: !_reduceMotion,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Top bar stays visible at all times (search is always
                  // reachable, per spec §5.1).
                  _topBar(accent),
                  Expanded(
                    child: _body(reading, band, accent, showBanner),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AirAware',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: _openLocationSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _place?.label ?? 'Locating…',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Icon(Icons.expand_more,
                            size: 18, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _iconBtn(Icons.search, _openSearch),
          if (_reading != null) _iconBtn(Icons.ios_share, _openShare),
          _iconBtn(Icons.refresh, () {
            HapticFeedback.lightImpact();
            _refresh();
          }),
          _iconBtn(Icons.tune, _openSettings),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      splashRadius: 22,
    );
  }

  Widget _alertBanner(AirQuality reading, Color accent) {
    return GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Air quality alert',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'AQI ${reading.usAqi} is above your alert level of '
                    '${_prefs.alertThreshold}.',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _bannerDismissed = true),
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ],
        ),
    );
  }

  /// The area below the top bar: loading / error / scrollable content.
  Widget _body(
    AirQuality? reading,
    AqiBand band,
    Color accent,
    bool showBanner,
  ) {
    if (reading == null) {
      if (_loading) return _loadingState(accent);
      if (_error != null) return _errorState(accent);
      return _loadingState(accent);
    }

    final verdict = band.verdict(sensitive: _prefs.sensitive);

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await _refresh();
      },
      color: accent,
      backgroundColor: const Color(0xFF12161F),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: AnimationLimiter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    children: AnimationConfiguration.toStaggeredList(
                      duration: Duration(milliseconds: _reduceMotion ? 0 : 500),
                      childAnimationBuilder: (widget) => SlideAnimation(
                        verticalOffset: 40,
                        child: FadeInAnimation(child: widget),
                      ),
                      children: [
                        if (showBanner) ...[
                          _alertBanner(reading, accent),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        Center(
                          child: Hero(
                            tag: 'aqi-orb',
                            child: Material(
                              type: MaterialType.transparency,
                              child: AqiOrb(
                                aqi: reading.usAqi,
                                accent: accent,
                                category: band.category,
                                animate: !_reduceMotion,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _verdictCard(verdict, accent),
                        const SizedBox(height: 14),
                        if (_insightCard(reading, accent) case final c?) ...[
                          c,
                          const SizedBox(height: 14),
                        ],
                        _pollutantGrid(reading),
                        const SizedBox(height: 14),
                        if (_hourly.isNotEmpty) ...[
                          ForecastSection(
                            upcoming: AirBundle(current: reading, hourly: _hourly)
                                .upcoming(),
                            daily: AirBundle(current: reading, hourly: _hourly)
                                .dailyPeaks(),
                            accent: accent,
                            animate: !_reduceMotion,
                          ),
                          const SizedBox(height: 14),
                        ],
                        _footer(reading),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _verdictCard(String verdict, Color accent) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              verdict,
              style: GoogleFonts.manrope(
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dominant-pollutant + best-clean-window insight. Null when neither is
  /// available (e.g. offline with no sub-indices/forecast).
  Widget? _insightCard(AirQuality reading, Color accent) {
    final dominant = Insights.dominant(reading);
    final window = Insights.bestCleanWindow(
      AirBundle(current: reading, hourly: _hourly).upcoming(),
    );
    if (dominant == null && window == null) return null;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dominant != null) ...[
            Row(
              children: [
                Icon(Icons.insights, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  'Driven by ${dominant.label}',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              dominant.note,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.3,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (dominant != null && window != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                  height: 1, color: Colors.white.withValues(alpha: 0.12)),
            ),
          if (window != null)
            Row(
              children: [
                Icon(Icons.eco_outlined, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Cleanest air ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text:
                              '${_clockRange(window.start, window.end)} · AQI ${window.aqi}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _pollutantGrid(AirQuality reading) {
    final items = [
      _Pollutant('PM2.5', reading.pm25),
      _Pollutant('PM10', reading.pm10),
      _Pollutant('Ozone', reading.ozone),
      _Pollutant('NO₂', reading.no2),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.9,
      children: items.map(_statCard).toList(),
    );
  }

  Widget _statCard(_Pollutant p) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            p.label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (p.value == null)
                Text(
                  '—',
                  style: GoogleFonts.sora(
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                )
              else
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: p.value!),
                  duration: Duration(milliseconds: _reduceMotion ? 0 : 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) => Text(
                    v.toStringAsFixed(1),
                    style: GoogleFonts.sora(
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                'µg/m³',
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

  Widget _footer(AirQuality reading) {
    final updated = _formatTime(reading.time);
    return Column(
      children: [
        if (_offline)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Showing last update from $updated — you\'re offline',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            'Last updated $updated',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  Widget _loadingState(Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(color: accent, strokeWidth: 3),
          ),
          const SizedBox(height: 18),
          Text(
            'Reading the air…',
            style: GoogleFonts.manrope(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _errorState(Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.air, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () {
                HapticFeedback.lightImpact();
                _place == null ? _resolveLocationThenFetch() : _refresh();
              },
              child: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _openSearch,
              child: const Text('Search a city instead'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(String raw) {
    // raw like "2026-06-27T10:00"
    try {
      final dt = DateTime.parse(raw);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return raw.isEmpty ? 'now' : raw;
    }
  }

  /// "6–8 AM", "10 PM–12 AM", etc.
  static String _clockRange(DateTime start, DateTime end) =>
      '${_clock(start)}–${_clock(end)}';

  static String _clock(DateTime t) {
    final isPm = t.hour >= 12;
    var h = t.hour % 12;
    if (h == 0) h = 12;
    return '$h ${isPm ? 'PM' : 'AM'}';
  }
}

class _Pollutant {
  final String label;
  final double? value;
  const _Pollutant(this.label, this.value);
}
