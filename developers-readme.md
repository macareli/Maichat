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

The README uses dark-theme captures of the real app screens, with fictional
demo content and generated stand-in art. Regenerate the eight README images:

```sh
flutter test test/screenshots/readme_dark.dart --update-goldens
```

The header is the supplied artwork in `docs/assets/picsart_header.png`.
The three local SVG action buttons use solid Material-style fills and shapes,
with no blur or animation. Each is a 280 × 56 link target, on its own row so
it remains usable on a narrow GitHub mobile page.

The separate original fixture set can still be regenerated with:

```sh
flutter test test/screenshots/generate.dart --update-goldens
```

See [screenshot notes](developer%20notes/screenshots.md) for font loading,
image decoding and the limits of headless captures.

## Notes

- [Developer notes index](developer%20notes/README.md)
- [Feature and test constraints](developer%20notes/feature-notes-and-test-traps.md)
- [Public repository guide](AGENTS.md)
