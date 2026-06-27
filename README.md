# AirAware 🌫️

**A beautiful, global air-quality companion that tells you — in plain language — whether it's safe to be outside right now, personalized to how sensitive you are.**

Most air-quality apps just show a number ("AQI 156") that means nothing to a normal person. AirAware answers the real question — *"Can I go outside, and is it safe for me?"* — only alerts you when it actually matters, and wraps it all in an immersive, animated UI that reacts to the air itself.

Built with Flutter (Android + iOS from one codebase). **Zero cost** — uses only the free [Open-Meteo](https://open-meteo.com) APIs (no API key, no signup).

---

## ✨ Features

### Core
- **Live AQI** for your GPS location, with worldwide **city search**.
- **Plain-language verdict** for every air-quality band (e.g. *"Avoid outdoor exercise. Keep windows closed."*).
- **"I'm sensitive" mode** — escalated wording and a lower alert threshold for people with asthma, heart/lung conditions, the elderly, or young children.
- **Glass pollutant cards** — PM2.5, PM10, Ozone, NO₂.
- **Smart alerts** — an in-app banner when AQI crosses your threshold, plus a background daily check that notifies you when the air turns bad.
- **Offline-friendly** — caches the last reading and shows it with an "offline" note when you lose connection.

### Forecast & Insights
- **24-hour AQI curve** and a **multi-day outlook** (animated, recolored by band).
- **Dominant-pollutant insight** — *"Driven by PM2.5"* with a one-line health note, derived from the API's per-pollutant sub-indices.
- **"Cleanest air" coach** — finds the lowest-pollution window in the next 24 hours (e.g. *"Cleanest air 8–10 PM · AQI 73"*).

### Convenience
- **Multiple saved locations** — switch between home / work / family with one tap.
- **Morning & evening reports** — a daily 7 AM and 6 PM summary with today's outlook and the best time to be outside.
- **Android home-screen widget** — current AQI, city and category in the live band color; tap to open.

### Design — *"the screen breathes with the air"*
- A full-screen **living gradient** that slowly drifts and morphs to the current AQI band.
- A **breathing AQI orb** (`CustomPainter`) that counts up on load and pulses faster as the air worsens.
- A **pollution particle field** whose density scales with PM2.5.
- **Glassmorphism** cards, staggered entrance animations, smooth tweened recoloring, and tactile haptics.
- Full **reduce-motion** support (honors the OS setting and an in-app switch).

---

## 🛠 Tech stack

- **Flutter** (Dart 3+, Material 3), dark-glass aesthetic
- **APIs:** Open-Meteo [Air Quality](https://open-meteo.com/en/docs/air-quality-api) + [Geocoding](https://open-meteo.com/en/docs/geocoding-api) (no key)
- **Packages:** `http`, `geolocator`, `shared_preferences`, `flutter_local_notifications`, `workmanager`, `timezone`, `home_widget`, `google_fonts`, `flutter_staggered_animations`, `animations`
- **Visuals:** `CustomPainter` (orb, particles, forecast curve), `BackdropFilter` (glass), `AnimationController` / `TweenAnimationBuilder`

## 🏗 Architecture

```
lib/
  main.dart
  models/        air_quality, forecast, place, user_prefs
  services/      air_quality, geocoding, location, notification,
                 background (workmanager), storage, widget
  screens/       home, search, settings
  widgets/       aqi_orb, particle_field, living_background,
                 forecast_section, glass_card
  utils/         aqi (bands → color/label/verdict), insights
android/app/src/main/kotlin/.../AqiWidgetProvider.kt   # home-screen widget
```

## 🚀 Getting started

```bash
flutter pub get
flutter run        # debug
flutter build apk --release --target-platform android-arm64   # ~18 MB release
```

No API keys or configuration required.

## 📋 Notes

- The release build is currently signed with the Flutter **debug keystore** — fine for sideloading; a release keystore is needed before publishing to the Play Store.
- iOS targets the same Flutter codebase; the home-screen widget is implemented for Android (an iOS WidgetKit extension would be a natural next step).

## 🙏 Credits

Air-quality and geocoding data by [Open-Meteo](https://open-meteo.com) (CAMS / ECMWF), free for non-commercial use.

## 📄 License

MIT — see [LICENSE](LICENSE).
