import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_prefs.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/living_background.dart';

/// What Settings hands back to Home on pop.
class SettingsResult {
  final UserPrefs prefs;
  final bool changeLocation;
  const SettingsResult(this.prefs, {this.changeLocation = false});
}

class SettingsScreen extends StatefulWidget {
  final UserPrefs initial;
  final String? currentPlaceLabel;
  final StorageService storage;

  const SettingsScreen({
    super.key,
    required this.initial,
    required this.currentPlaceLabel,
    required this.storage,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserPrefs _prefs;
  bool _thresholdSetByUser = false;

  @override
  void initState() {
    super.initState();
    _prefs = widget.initial;
    widget.storage.thresholdSetByUser().then((v) {
      if (mounted) setState(() => _thresholdSetByUser = v);
    });
  }

  Future<void> _save() => widget.storage.savePrefs(_prefs);

  void _setSensitive(bool value) {
    setState(() {
      // Re-apply the implied default threshold unless the user overrode it.
      final threshold = _thresholdSetByUser
          ? _prefs.alertThreshold
          : UserPrefs.defaultThresholdFor(value);
      _prefs = _prefs.copyWith(sensitive: value, alertThreshold: threshold);
    });
    HapticFeedback.lightImpact();
    _save();
  }

  Future<void> _setAlerts(bool value) async {
    setState(() => _prefs = _prefs.copyWith(alertsEnabled: value));
    HapticFeedback.lightImpact();
    await _save();
    if (value) {
      await NotificationService.instance.requestPermission();
    }
  }

  Future<void> _setReports(bool value) async {
    setState(() => _prefs = _prefs.copyWith(reportsEnabled: value));
    HapticFeedback.lightImpact();
    await _save();
    if (value) {
      await NotificationService.instance.requestPermission();
    }
  }

  void _setReduceMotion(bool value) {
    setState(() => _prefs = _prefs.copyWith(reduceMotion: value));
    HapticFeedback.lightImpact();
    _save();
  }

  void _setThreshold(double value) {
    setState(() => _prefs = _prefs.copyWith(alertThreshold: value.round()));
  }

  Future<void> _commitThreshold() async {
    _thresholdSetByUser = true;
    await widget.storage.setThresholdSetByUser(true);
    await _save();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4CAF50);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(SettingsResult(_prefs));
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E14),
        body: LivingBackground(
          accent: accent,
          animate: !_prefs.reduceMotion,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop(SettingsResult(_prefs)),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Text(
                      'Settings',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Sensitivity
                GlassCard(
                  child: _switchTile(
                    title: "I'm sensitive",
                    subtitle:
                        'Asthma, heart or lung condition, elderly, or young '
                        'children. Escalates verdicts and lowers your default '
                        'alert level.',
                    value: _prefs.sensitive,
                    onChanged: _setSensitive,
                  ),
                ),
                const SizedBox(height: 12),

                // Threshold
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alert me above AQI',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You\'ll be warned when air quality crosses this level.',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _prefs.alertThreshold.toDouble(),
                              min: 25,
                              max: 300,
                              divisions: 55,
                              activeColor: accent,
                              label: _prefs.alertThreshold.toString(),
                              onChanged: _setThreshold,
                              onChangeEnd: (_) => _commitThreshold(),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              _prefs.alertThreshold.toString(),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.sora(
                                fontSize: 20,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Daily alerts
                GlassCard(
                  child: _switchTile(
                    title: 'Daily air-quality alerts',
                    subtitle:
                        'Check in the background and notify you when the air '
                        'turns bad (best-effort on iOS).',
                    value: _prefs.alertsEnabled,
                    onChanged: (v) => _setAlerts(v),
                  ),
                ),
                const SizedBox(height: 12),

                // Morning & evening reports
                GlassCard(
                  child: _switchTile(
                    title: 'Morning & evening reports',
                    subtitle:
                        'A daily summary at 7 AM and 6 PM with today\'s outlook '
                        'and the cleanest time to be outside.',
                    value: _prefs.reportsEnabled,
                    onChanged: (v) => _setReports(v),
                  ),
                ),
                const SizedBox(height: 12),

                // Reduce motion
                GlassCard(
                  child: _switchTile(
                    title: 'Reduce motion',
                    subtitle:
                        'Turn off the living background, breathing orb and '
                        'particles for a clean, static look.',
                    value: _prefs.reduceMotion,
                    onChanged: _setReduceMotion,
                  ),
                ),
                const SizedBox(height: 12),

                // Change location
                GlassCard(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context)
                        .pop(SettingsResult(_prefs, changeLocation: true));
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, color: Colors.white70),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Change location',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              widget.currentPlaceLabel ?? 'Not set',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
