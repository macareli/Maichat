# Screenshots

The README uses eight dark-theme captures in `docs/screenshots/readme/`:
`01-mobile.png` through `08-gallery.png`. Regenerate them with:

```sh
flutter test test/screenshots/readme_dark.dart --update-goldens
```

`readme_dark.dart` pumps the real phone and tablet screens with a dark Material
3 Expressive theme, fictional chats and draft content, a local demo catalogue,
and generated stand-in art. It asserts dark brightness before each capture.
No provider requests are sent. The side-thread capture uses a saved completed
exchange. The recipe precaches rendered image providers and then advances the
test clock through the image fade. Waiting for decoding alone leaves
`SmoothImage` at zero opacity, so a gallery can have captions but blank tiles. The header is the supplied `docs/assets/picsart_header.png`, copied
without image manipulation. Local SVG action links use solid fills and no blur.

The original seven screenshot fixtures remain in `docs/screenshots/`, named
`01-chat.png` … `07-preview.png`. Their generation details follow.

## Regenerating them

```bash
flutter test test/screenshots/generate.dart --update-goldens
```

Seven shots, about fifteen seconds. Worth doing only when the UI in one of them
actually changed: every regeneration rewrites all seven files, and that is about
2 MB of new blobs in the history each time.

`test/screenshots/` holds the generator:

| File | What it is |
| --- | --- |
| `generate.dart` | The shot list — one `testWidgets` per picture. |
| `shot.dart` | Fonts, the phone-shaped surface, the app's real theme, `shoot()`. |
| `demo_world.dart` | The `AppState` every shot is taken in: cast, chat, ledger, gallery. |
| `demo_catalogue.dart` | A `DiscoverSource` that answers from memory, for the Discover shot. |
| `png.dart` | A PNG encoder and the gradient stand-in art. |

None of those files end in `_test.dart`, which is deliberate: `flutter test`
collects only `*_test.dart`, so the suite never runs them and **CI never diffs
these pixels**. Goldens disagree across machines over font hinting and
antialiasing; a README picture is not worth a red build.

## What a generated shot is and isn't

It is the real screen: the real widgets, under a real `AppState`, dressed in the
app's own `MaiChatApp.themeFor`. The words in the demo chat, the cast, the spend
history and the pictures are invented; nothing else is.

It is **not** a photograph of a phone. Four differences worth knowing before
deciding a shot is good enough:

- **The palette is the default violet seed.** A real device on Android 12+ takes
  its colours from the wallpaper, and no two users see the same screenshot.
- **No status bar, no gesture bar.** The view padding is set so the app *lays
  out* as if they were there (72 physical pixels at the top, 36 at the bottom),
  but nothing draws in that space.
- **The art is arithmetic.** `png.dart` writes gradients, so no card's
  third-party portrait is required for the generated illustrations.
- **The Discover feed is a stand-in.** `demo_catalogue.dart` invents the
  listings rather than reproducing a real site's, which is why the source is
  called "Demo catalogue" instead of one of the eight real names.

## Rendering constraints

- **Fonts.** A widget test has no system fonts, so every glyph draws as the
  `Ahem` test font's filled box. `loadShotFonts` registers Roboto and MaterialIcons out of the SDK
  cache, found by climbing out of `Platform.resolvedExecutable` rather than by a
  hardcoded path. It also registers DejaVu as a *fallback family* when the
  machine has it, because Roboto has no `↓` and Discover writes a download count
  with one; a phone falls back to Noto, a test host falls back to nothing.
- **Shadows.** `testWidgets` sets `debugDisableShadows`, which turns every
  elevation into a hard black outline — right for a golden diff, wrong for a
  README illustration. `usePhone` clears the flag and `shoot` puts it back, because the
  binding fails a test that leaves a painting flag changed.
- **Pictures need real time.** An avatar decodes on the engine's own thread,
  which the fake clock inside `testWidgets` never advances, so `pumpAndSettle`
  returns with every avatar still an empty circle. `settleShots` pumps a dozen
  `runAsync` delays to let the codec finish.
- **Don't send a message.** `state.send(...)` never returns under the fake
  clock (see AGENTS.md); `seedChat` writes the turns onto the conversation
  directly.

## Replacing one with a real photograph

Take the shot on a phone, crop off the status bar if you like, save it over the
file with the same name. Keep them all portrait and roughly the same aspect
ratio (the generated ones are 1080×2340) or the README grid goes ragged.
