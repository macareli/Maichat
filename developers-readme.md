# Developer guide

Use Flutter **3.44.9**, JDK 17, and the Android SDK. The full project guide is
[AGENTS.md](AGENTS.md); read it before changing the app.

```sh
flutter pub get
flutter analyze
flutter test
```

## Build Android

```sh
flutter build apk --release
```

For a separate Beta install:

```sh
flutter build apk --release \
  --dart-define=MAICHAT_BETA=true \
  --dart-define=MAICHAT_BETA_BUILD=1
```

The build workflow sets the Beta build number automatically. Both update
channels belong to this repository. Android upgrades require the same package
ID and signing certificate; see the [build workflow](.github/workflows/build-apk.yml).

## README pictures

The README uses native screenshots captured while actually using the Android
app in dark mode. Browse live Discover sources and download/import genuine
pictures through the app before showing the Gallery. Do not substitute seeded
state, generated placeholder artwork, a demo catalogue, or widget-test fixtures.

```sh
adb exec-out screencap -p > docs/screenshots/readme/01-mobile.png
```

Follow the [native capture runbook](developer%20notes/screenshots.md), including
its data-preservation and privacy requirements. The supplied header remains
unchanged in `docs/assets/picsart_header.png` and fills the README width. The
three solid Material-style SVG actions use 90 × 76 targets on one inline row.

The original widget previews remain separate regression/development fixtures:

```sh
flutter test test/screenshots/generate.dart --update-goldens
```

They are not README product screenshots.

## Notes

- [Developer notes index](developer%20notes/README.md)
- [Feature and test constraints](developer%20notes/feature-notes-and-test-traps.md)
- [Public repository guide](AGENTS.md)
