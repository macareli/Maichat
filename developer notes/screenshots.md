# Screenshots

## README captures: actual Android app use

README photos in `docs/screenshots/readme/` must be native screenshots from
actual app interactions. They must not use injected state, seeded demo worlds,
generated placeholder artwork, a demo catalogue, or widget-test rendering. Regression and
development previews are separate from product photos.

1. Use an installed Android app with a matching signing certificate. Do not
   uninstall, clear data, or overwrite existing user content to prepare a photo.
2. Switch the app to Dark mode through its navigation/settings controls.
3. Browse a live Discover source and download suitable cards/pictures through
   the app. Use newly created chats/workspaces where appropriate. Gallery photos
   must contain genuine downloaded pictures imported through its actual UI.
4. Open each screen through normal taps and scrolling. Wait for pictures and
   transitions to finish. Hide the keyboard unless it explains the feature.
5. Capture the unaltered screen:

   ```sh
   adb exec-out screencap -p > docs/screenshots/readme/01-mobile.png
   ```

6. Inspect every PNG for readable text, decoded pictures, dark UI and unintended
   private content. Choose a safe view instead of injecting or fabricating data.
7. Keep account identities, API keys, device identifiers, private package names,
   machine paths and source-repository details out of public capture notes.
   Record only the screen, public app version where applicable, display size and
   the real navigation/download workflow. Restore temporary display changes.

The eight filenames are `01-mobile`, `02-tablet`, `03-chat-tools`,
`04-agentic-studio`, `05-discover`, `06-home`, `07-library` and `08-gallery`
(with `.png`). `docs/screenshots/readme/CAPTURES.md` records their provenance.
The supplied header remains unchanged as `docs/assets/picsart_header.png`.
Its existing transparent padding is retained; README width is 100%. Action links
use solid SVG fills, no blur or animation, and share a compact inline row.

## Separate widget previews

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
antialiasing; these developer previews do not gate CI.

## Widget preview scope

These fixtures render production widgets with synthetic application state,
invented dialogue and generated stand-in art. They are useful for layout checks
and regression review. They are never substitutes for the README screenshots.

Their theme, fonts and view padding are controlled by the test binding. They
have no Android status/navigation bars, and the fixture Discover feed does not
contact a live catalogue. Native capture instructions above apply to every
README image.

## Rendering constraints

- **Fonts.** A widget test has no system fonts, so every glyph draws as the
  `Ahem` test font's filled box. `loadShotFonts` registers Roboto and MaterialIcons out of the SDK
  cache, found by climbing out of `Platform.resolvedExecutable` rather than by a
  hardcoded path. It also registers DejaVu as a *fallback family* when the
  machine has it, because Roboto has no `↓` and Discover writes a download count
  with one; a phone falls back to Noto, a test host falls back to nothing.
- **Shadows.** `testWidgets` sets `debugDisableShadows`, which turns every
  elevation into a hard black outline — right for a golden diff, wrong for a
  developer preview. `usePhone` clears the flag and `shoot` puts it back, because the
  binding fails a test that leaves a painting flag changed.
- **Pictures need real time.** An avatar decodes on the engine's own thread,
  which the fake clock inside `testWidgets` never advances, so `pumpAndSettle`
  returns with every avatar still an empty circle. `settleShots` pumps a dozen
  `runAsync` delays to let the codec finish.
- **Don't send a message.** `state.send(...)` never returns under the fake
  clock (see AGENTS.md); `seedChat` writes the turns onto the conversation
  directly.

## Maintaining product screenshots

Replace README images only with new native captures from actual app use.
Retain the screen-specific filename and its intended phone/tablet orientation,
and update `docs/screenshots/readme/CAPTURES.md` with the genuine workflow.
Do not run a fixture generator over the README image directory.
