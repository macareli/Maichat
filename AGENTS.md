# MaiChat — project guide

MaiChat is a Flutter mobile AI chat client (Android application ID
`io.github.macareli.maichat`) with multi-provider chat, characters, presets with
a macro engine, lorebooks, an in-app catalogue browser ("Discover"), chat
import/export, and deep per-chat customisation. Primary target is **Android**
(sideloaded APK). There is **no iOS build** and the Linux desktop build exists
only for headless smoke-testing.

Read this guide and `developer notes/README.md` before changing the project.
Read the relevant feature notes before nontrivial changes, and verify file and
symbol references against the current code. Keep technical guidance current.
Do not add AI authors or coauthors, attribution footers, or session links to
commits or pull request descriptions.

## Public repository privacy

Privacy is a permanent publication requirement. Keep private source identities,
usernames, emails, repository links, local paths and source commit IDs out of
public code, fixtures, documentation, screenshots, artifacts and commit metadata.
Transfer changes as code-only patches and create independent commits under the
public repository identity. Never merge private history or add source references
or cherry-pick trailers. Before each publication, audit the complete staged tree,
new commit metadata and reachable public history for identifying references.
Preserve this requirement in future project guidance and handoffs.

## Build & verify (works in a fresh container/Codespace)

- `flutter pub get`, then `flutter analyze` must be **clean** and `flutter test`
  must pass for code changes. Use Flutter **3.44.9**, matching CI and the
  devcontainer. For documentation or configuration changes, run the checks
  appropriate to those files. Report the checks actually completed.
- The devcontainer builds from a digest-pinned Android/JDK image and installs
  the official Flutter 3.44.9 tag at a checked revision. Update the Dockerfile,
  setup version check, and CI together when changing the toolchain.
- Linux smoke test runs headless under `xvfb-run` (e.g. build `--release` for
  linux and launch briefly). Use it to eyeball UI changes.
- **README screenshots** are generated, never hand-collected:
  `flutter test test/screenshots/generate.dart --update-goldens` pumps the real
  screens at 1080×2340 and writes `docs/screenshots/`. Those files are *not*
  `_test.dart`, so the suite never runs them and CI never diffs the pixels. See
  `developer notes/screenshots.md` for the traps (test fonts render as black
  boxes, `debugDisableShadows` draws shadows as hard outlines, image decode needs
  `runAsync`) and for how a real phone photo is swapped in over a generated file.
- Android release APK: `flutter build apk --release` produces a universal APK.

### Build requirements

- **Gradle heap:** keep `android/gradle.properties` resource limits compatible
  with the build host. `org.gradle.jvmargs=-Xmx1536m` and
  `org.gradle.daemon=false` support constrained hosts; oversized heaps can cause
  the operating system to kill a build without a useful Gradle error.
- **INTERNET permission:** Flutter only injects it into the *debug* manifest.
  It is added explicitly in `android/app/src/main/AndroidManifest.xml` for
  release, or every network request fails on device. Leave it in.
- **AGP-9 Kotlin-plugin workaround:** under this project's AGP, several native
  plugins don't get the Kotlin plugin applied and fail with "cannot find symbol
  <Plugin>". `android/build.gradle.kts` has a `subprojects { ... }` hook that
  applies `org.jetbrains.kotlin.android` to the affected modules. When you add a
  plugin that ships native Android code (file_picker, url_launcher_android,
  path_provider_android, webview_flutter_android are already listed), **add it to
  that hook** or the release APK won't build. Prefer pure-Dart deps to avoid this.
- Dependencies are **pinned exactly (no `^`)** on purpose.

## Build artifacts and version consistency

- CI (`.github/workflows/build-apk.yml`) analyzes and tests pushes to `main`
  and `beta`, and pull requests to `main`; pushes, version tags, and manual
  dispatch can build APKs.
  A `v*` tag requires all four signing secrets: `KEYSTORE_BASE64`,
  `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, and `KEY_ALIAS`. Missing signing on a
  version tag, or incomplete supplied signing configuration, fails the build.
  Branch and manual builds without a keystore can use debug signing.
  Keep signing files out of version control.
- `kAppVersion` in `lib/app_info.dart` **must track `pubspec.yaml`**. Drift here
  caused an "update available" prompt that never went away (the updater compares
  the latest GitHub tag to `kAppVersion`). `test/app_version_test.dart` fails on
  drift — keep it that way.
- In-place Android upgrades require a matching application ID and signing key.
  Builds signed with different keys cannot replace one another in place.
- Beta builds use `--dart-define=MAICHAT_BETA=true` for both Dart behavior and
  the Android package `io.github.macareli.maichat.beta`; the namespace remains
  `io.github.macareli.maichat`. The beta updater compares CI build numbers
  from the rolling `beta-latest` prerelease. Main builds use normal releases;
  both update channels stay within `macareli/Maichat`.

## Change and verification practices

- Implement the requested scope and keep the result reviewable. Repository
  guidance does not authorize remote publication or unrelated release actions.
- For layout-dependent behavior, cover the relevant combinations of text
  placement, name placement, avatar visibility, and action-bar placement.
  Regression tests should demonstrate the reported failure when practical.
- For prompt behavior, assert the actual outgoing request. The
  `test/wire_payload_test.dart` suite runs real `AppState` and `ChatClient`
  against a loopback `HttpServer`; View prompt also exposes the raw request.
- Report analyzer, test, build, and device checks separately. Widget tests and
  headless Linux rendering do not establish physical touch behavior or GPU
  smoothness.

### Widget tests and real file I/O

A `testWidgets` body runs inside a fake-async zone that **never pumps real
`dart:io` futures**, so anything that writes a picture (`storePicture`,
`storeAttachment`, `addGalleryImages`, `AvatarStore.write`) hangs forever if it is
plainly awaited — the symptom is a test that sits there until `pumpAndSettle`
times out ten minutes later, with no assertion failure. Wrap those calls in
`tester.runAsync(...)`, or wait for a chain of them with a loop of
`runAsync(Future.delayed(...))` + `pump()` (see
`test/image_gen_ui_test.dart`'s `settleRealWork`). Plain `test()` bodies are
unaffected. Two related traps in the same tests: a progress spinner means
`pumpAndSettle` never settles, and a drag started at the left edge of the chat is
eaten by the drawer's edge-swipe region.

Real HTTP client tests must use files of plain `test()` cases. A `testWidgets`
case installs HTTP overrides for that file and can turn loopback requests into
400 responses even in neighboring plain tests.

**Never
`await state.send(...)` inside a `testWidgets` body before pumping** — a reply's
paint-cadence timer only fires when the fake clock is advanced by a `pump`, so the
await never returns and the test hangs for its full timeout with no failure; seed
`state.active.messages` directly instead (as `test/turn_actions_ui_test.dart`
does). And **a long press on a message's text never reaches the bubble's action
sheet**: the body is a `SelectableText.rich`, whose own long-press recognizer wins
the arena and opens the text-selection toolbar (which also has a "Copy", so a test
looking for one is easily fooled). Drive that sheet's actions through the action
bar or the overflow menu.

## Critical invariants — do not regress these

- **Exactly one leading `system` message on the wire.** The request must contain
  a single `system` message at position 0; any preset block that lands after the
  conversation starts (depth/absolute injections, trailing `<task>`/`<output_format>`)
  goes out as a `user` turn. Enforced in `PromptBuilder._oneSystemBlock` +
  `mergeSameRole`. Reason: some OpenAI→other gateways map `role:system` into a
  single `system_instruction` and the **last** system message overwrites earlier
  ones — multiple system messages silently drop the character sheet, and the model
  then claims it has no character definition.
- **Pictures are files, never base64 in SharedPreferences.** Avatars/backgrounds
  live in the `AvatarStore` directory; `Character.avatar` holds an `http(s)` URL,
  a `local:<file>` ref, or legacy base64 only until the startup migration moves
  it. Base64 blobs inside prefs previously grew the store until Android's native
  prefs parser OOM'd *before Dart ran* — an unopenable app. `lib/services/prefs_repair.dart`
  is the escape hatch. There is **no avatar size cap** by design. This holds for
  message attachments too (`MessageImage.ref`): base64 only ever exists on the
  copy handed to the wire, and `_sweepAvatars`' keep-list must name every message
  attachment or the sweep deletes a picture that is in the transcript. The same
  trap caught the interface's own pictures (a participant bar, a look's
  background), which is why `ChatInterface.pictureRefs` exists: one place naming
  what a look refers to, read by the keep-list *and* by a look's export. A picture
  the sweep deleted cannot be in a backup either, since a backup ships the
  pictures directory as it finds it. An **export** file may hold base64 — that
  rule is about the store, not about files leaving the app.
- **Per-chat overrides resolve in exactly one place each.** Read a thread's style
  via `AppState.interfaceFor(conversation)`, a character *inside a thread* via
  `AppState.characterFor(conversation, id)` and its scenario via
  `AppState.scenarioFor(conversation, character)` — assembly, restart,
  impersonation, the message list and the exporter all go through them.
  `Conversation.copyAs` keeps fork/renumber from dropping a new per-chat field.
- **`AppState.init()` must always finish** (timeout + catch, surfaces `loadError`,
  goes read-only on failure). A throw here = permanent startup spinner.
- **Keep heavy startup work after Home's first frame.** Real launch enables
  `backgroundWarmUp`; tokenizer initialization runs through
  `AppTokenizer.warmUp` in a root-zone isolate, while picture sweeping and due
  backups wait for `_deferredStartupWork`. Counts use the approximate heuristic
  while warming. Tests leave the flag off because widget fake-async does not
  deliver isolate replies. `TokenizerKind.none` skips warmup and releases BPE
  vocabularies. `_ThemeCache` reuses themes while appearance is unchanged.
- **The thread is a `reverse: true` list, and that has consequences.** Its newest
  turn is anchored to the bottom and every older message is positioned relative to
  it, so a turn that grows moves the whole conversation above it. Two rules follow:
  a streaming reply repaints on a cadence (`AppState._streamPaintMs`) rather than
  per delta, and while the reader is scrolled away mid-stream the newest turn is
  drawn frozen at the text it had (`_ChatScreenState._frozenTail`). Never `jumpTo`
  the thread while a gesture is live — `jumpTo` goes through `goIdle`, which
  cancels the drag or fling outright (`_scrollToEnd` guards on
  `userScrollDirection`). At offset 0 nothing needs scrolling at all: the bottom
  anchor already follows a growing reply.
- **A view preference never rides in the `conversations` blob.** That entry holds
  every message of every chat, so re-encoding it to record one boolean is tens of
  milliseconds of JSON on the UI thread. Memory-block folds live in their own
  `summaryFolds` entry and are laid back over the summaries on load
  (`AppState._applySummaryFolds`); `browseLayout` does the same via `viewPrefs`.
  Where a write to that blob is unavoidable but the frame matters — selecting a
  swipe — it goes through `_saveConversationsSoon()` instead.
- **`ChatScreen.build` reads `MediaQuery.viewPaddingOf`, never `paddingOf`.**
  `padding` is `viewPadding` minus the keyboard's insets, so it changes on every
  frame of the keyboard's animation: depending on it rebuilt the whole chat —
  thread, composer, drawer — when the keyboard only needed to relayout it, which is
  what made tapping into the message box feel grainy. `test/chat_keyboard_test.dart`
  fails if it comes back.
- **The keyboard never resizes the chat.** `ChatScreen`'s Scaffold sets
  `resizeToAvoidBottomInset: false` and `_KeyboardShift` slides the thread and the
  composer up instead. Not rebuilding was only half the cost: a shrinking viewport
  *lays the message list out again*, and a re-laid-out list is a re-painted one —
  a screenful of markdown, HTML and `SelectableText` on each of the fifteen-odd
  frames the keyboard takes to rise, which cost the same at six turns as at ninety.
  Sliding is a transform-layer offset: no layout, no paint, and the scroll position
  is never touched. The thread is bottom-anchored (`reverse: true`), so the result
  on screen is identical. Two things follow: the column's padding comes from
  `viewPadding` (stable) rather than a `SafeArea` reading `padding`, and a snackbar
  has to be floated clear of the keyboard by hand (`_toast`), because the Scaffold
  no longer knows the keyboard is there.
- **A creator field is a fixed-height box, never `minLines`→`maxLines`.**
  `CreatorField` sizes its box with `creatorBoxHeight` and lets `expands: true`
  scroll the words inside it. A growing box moved everything below it as it was
  typed into, and the caret then had to be scrolled back into view, which is what
  made the page bob under the cursor. For the same reason the long fields do **not**
  call `CreatorDraft.touch()` on every keystroke: what has to follow the words
  follows the controller (the app-bar title, a fold's preview, the scenario chips).

## Architecture map (where things live)

- **State/persistence:** `AppState` (provider `ChangeNotifier`) + `Storage`
  (`shared_preferences`, keyed blobs: `providers`, `presets`, `characters`,
  `discover`, `macroGlobals`, `tokenizer`, …). Note the app's own `Provider`
  model clashes with the `provider` package — UI files do
  `import 'package:provider/provider.dart' hide Provider;`.
- **Providers & networking:** `models/provider.dart` (`ProviderKind`
  openai/anthropic/gemini; multi-key with `keyStrategy` rotation), `ChatClient`
  (`streamChat` yields `ChatDelta{text,reasoning}`; branches per kind for SSE,
  headers, thinking/reasoning wire, non-streaming).
- **Generation pipeline:** `models/preset.dart` + `models/prompt_block.dart`
  (SillyTavern-style blocks/order), `services/macro_engine.dart` (full ST macro
  superset), `services/prompt_builder.dart` (assembles blocks→messages, budgeting,
  absolute-depth injection), `services/tokenizer.dart` (real BPE via
  `tiktoken_tokenizer_gpt4o_o1`), `services/model_context.dart`. `AppState._assemble`
  is the single path real sends and the prompt inspectors share.
- **Characters:** `models/character.dart` (ST v1/v2/v3 + Agnai superset, macro
  resolution), `services/character_codec.dart` (parses flat/spec cards, PNG
  `chara`/`ccv3` chunks, `.charx` ZIP carving), `services/character_sources.dart`
  (import plugins), screens under `lib/screens/` + `widgets/character_avatar.dart`.
- **Creator v2:** `screens/character_creator/*` — one `CreatorDraft` (every
  controller, handed down through a provider so a swiped-away tab loses nothing)
  under six tabs, with the portrait as a scrollable `NestedScrollView` header. The
  shared parts are in `creator_controls.dart`: `CreatorField` (a fixed-height box,
  a token count, and the three things you can do to a field —
  `CreatorFieldActions`), `CreatorFold` (a greeting or a scenario, named **once**,
  by the fold, which carries the field's tools while it is open), and
  `CreatorTabBody`. That last one pairs a `SliverOverlapInjector` with the
  `SliverOverlapAbsorber` around the pinned tab bar; without the pair the top of
  every tab hides under the bar as soon as the portrait is scrolled off.
- **Lorebooks:** `models/lorebook.dart`, `services/lorebook_codec.dart` (ST world
  info / card `character_book` / Agnai memory books — one export file all read),
  `services/world_info.dart` (activation scan). `lib/screens/library/`.
- **Scenarios:** `models/scenario.dart` (Agnai's shape: text plus
  `overwriteCharacterScenario`; Agnai's triggered `entries`/`states` ride in
  `extensions` and deliberately do not fire), `services/scenario_codec.dart`
  (Agnai / character card / MaiChat / plain prose in, MaiChat + Agnai out),
  `screens/library/scenarios_screen.dart` + `scenario_edit_screen.dart`,
  `widgets/scenario_picker_sheet.dart` (the browse → preview → edit-in-place →
  "library or here only?" → Proceed sheet, used by the character sheet's scenario
  fold and by chat settings). A scenario arrives by one of three routes and they
  are ranked in `AppState.scenarioFor` alone: the chat's own text, the library
  scenario `Conversation.scenarioId` names, then `Character.activeScenario`.
- **Regex (find/replace rules):** `models/regex_rule.dart` (SillyTavern-faithful
  JSON so a rule round-trips with ST), `services/regex_engine.dart` (the port of
  ST's Regex extension engine — pattern compile + LRU cache, `$1`/`$<name>`/
  `{{match}}` substitution, the three ephemerality modes), `services/regex_codec.dart`
  (import single/array/`regex_scripts`-wrapped JSON, export ST-compatible),
  the `regexRules` store entry, and `screens/library/regex_screen.dart` +
  `regex_edit_screen.dart` (a Library card, with a live test panel). A single
  **global** list — no per-character/preset scopes in v1. Applied at four points,
  all through `AppState`: `send()` (permanent user-input rules rewrite the stored
  turn), `_generate()` finalize (permanent AI-output/reasoning rules rewrite the
  reply), `_assemble()` (prompt-only rules transform the outgoing `history` copy;
  depth = distance from newest), and `MessageBubble.displayTransform` (display-only
  rules, supplied by `chat_screen` from `AppState.regexDisplayTransform`; the
  `regexDisplaySignature` rides in the per-bubble cache key so editing a cosmetic
  rule refreshes the thread). Backups pick it up for free — the store is dumped
  key by key. `RegexEngine.hasWork` short-circuits every site when no rule applies.
- **Browse layout:** cards-vs-rows for Characters / Lorebooks / Scenarios is a
  *persisted* preference (`models/view_prefs.dart`, the `viewPrefs` store entry,
  `AppState.browseLayout`/`setBrowseLayout`) — no screen holds it in a field.
- **Discover (in-app catalogue browser):** `models/discover.dart`,
  `services/discover/*` (per-site sources: Chub, JannyAI, CharacterTavern, Risu
  realm, Botbooru, Pygmalion, Wyvern, DataCat — each with its own API quirks),
  `screens/discover/*`. A feed is a live remote view held by
  `discover_controller.dart`, deliberately *not* in `AppState`.
  `discover_item_screen.dart` is the **character sheet drawn from a listing**: it
  builds the same slivers out of `screens/character_sheet_parts.dart`
  (`TagBand`, `SheetDivider`, `NotesBlock`, `DefinitionFolds`) plus its own
  natural-ratio portrait, so a catalogue entry gets the card's images, HTML and
  CSS exactly as a local character does. Its two differences: a flat "From the
  catalogue" block between the tags and the notes, and `DefinitionFolds(
  interactive: false)` — the scenario picker writes onto a *stored* character and
  this one is not saved yet.
- **Chat portability:** `services/chat_codec.dart` (imports ST `.jsonl`, Agnai,
  ooba, CAI, Risu, Kobold, plain logs; native export is one file ST+Agnai+MaiChat
  all read). `test/chat_codec_test.dart` has a "what the other apps accept" group.
- **Backups (Settings ▸ Backups):** `models/backup.dart` (schedule, destination,
  `BackupPrefs`, `BackupRecord`, counts, stats), `services/backup_codec.dart`,
  `services/backup_store.dart` (the app's own `backups/` folder),
  `services/drive_client.dart`, `services/foreign_backup.dart`,
  `screens/backups/*`. A backup is a zip of `maichat-backup.json` +
  `pictures/` + `vectors/`, and the manifest holds **the store itself**, entry by
  entry, decoded — copied verbatim rather than rebuilt from the models, which is
  why a restore lands per-chat overrides and any field added later without this
  code knowing about them. `kBackupExcludedKeys` keeps `backupPrefs`/`backups`
  out of a backup, so restoring an old snapshot cannot disconnect Drive or erase
  the history that is being read from. A restore writes files first, then the
  store (`replace` removes anything the archive does not mention; merge
  reconciles lists by id and leaves settings alone), then `reloadFromStore()`;
  keys blanked out of a keyless backup fall back to the live ones
  (`preserveSecrets`). Every export goes through `AppState.exportBackup`, which
  is also what the schedule calls — there is no background worker, so
  `runDueBackup()` runs from `init()` when one is owed, and only the in-app and
  Drive destinations can run without a save dialog.
- **A backup is never held in memory whole**, and that is the invariant the whole
  feature is built around: the first version read the picked file with
  `withData: true` and inflated every picture into a map, which on a real gallery
  is hundreds of megabytes and killed the process — a crash with no Dart error to
  show for it. So: the picker is called **without `withData`** and everything
  works from the path it returns; an export is written to a temp file with
  `writeBackupFile` (pictures *stored*, not deflated — they are already
  compressed) and then moved into place or streamed to Drive
  (`DriveClient.uploadFile` builds the multipart body from a file stream, and
  `downloadToFile` streams the other way); a restore opens `BackupArchive` from
  the path, which inflates only the manifest, and `extractFiles` writes one entry
  at a time. `looksLikeOurBackupFile` is how the import screen tells one of ours
  from somebody else's without reading it twice.
- **Foreign imports** are a different mechanism (`services/foreign_backup.dart`):
  the archive is opened from disk, every entry is routed through the codec that
  already reads it, and pictures go straight into the pictures directory through
  an injected `PictureStore` sink as they are read (so nothing accumulates, and a
  picture used in a message *and* in the gallery is one file). The SillyTavern
  layout is taken from its own repo, not guessed: `USER_DIRECTORY_TEMPLATE` in
  `src/constants.js` for the folders, and `chats.js` for the fact that a chat
  lives in `chats/<card file name>/` (from `avatar_url` minus `.png`) — which is
  the *only* record of whose chat it is, so the cards are read first and indexed
  by file name. `settings.json` carries the personas (`power_user.personas`, keyed
  by avatar file, with `persona_descriptions` and `default_persona`) and the tag
  names (`tags` + `tag_map`); `groups/*.json` + `group chats/*.jsonl` are the two
  halves of a group chat; a turn's pictures are `extra.media[].url` (plus legacy
  `extra.image`/`image_swipes`) pointing into `user/images`, and those paths are
  rewritten to `local:` refs *before* `ChatCodec` parses the transcript, which is
  what puts a generated picture back on the turn that made it. Everything with no
  home here (themes, quick replies, extensions, wallpapers, `secrets.json`) is
  counted in `ForeignBackup.skipped` and reported — including `instruct/` and
  `context/`, which frame a *text*-completion prompt (literal sequences and a
  Handlebars story string) and would import as markup; `sysprompt/` does come
  across, as a preset whose Main Prompt and Post-History blocks are its
  `content`/`post_history`. Both readers report through `BackupProgress`, which
  is what the import screen's bar and the restore dialog's bar draw. `test/backup_sillytavern_test.dart`
  builds that layout file by file, with a real world-info fixture and a real
  chat-completion preset out of SillyTavern's own `default/content`.
  Drive is OAuth with a "Desktop app" client, PKCE, and a loopback listener —
  deliberately no custom scheme, so no native plugin and no AGP-9 hook. The
  client the app ships with lives in `kBundledDriveClientId`/`Secret`, injected
  by CI from the `DRIVE_CLIENT_ID`/`DRIVE_CLIENT_SECRET` repo secrets and empty
  in a fork (or a local build), which is what makes connecting one tap; an installed app's client secret is not a confidential credential and the
  only scope asked for is `drive.file`, so the pair grants nothing on its own.
  `DriveClient.clientIdFor` prefers a client the user pasted under Advanced, and
  the grant never records which client made it.
- **Gallery:** `models/gallery_image.dart` (a record + the sort/zoom enums),
  `models/floating_image.dart`, `services/gallery_group.dart` (the pure
  date-bucketing and sorting the screens draw), `screens/gallery/*` (one
  `GalleryScreen` in three modes, the viewer, the upload/edit/picker sheets, the
  pinch ladder), `widgets/avatar_swipe_sheet.dart`,
  `widgets/floating_images_layer.dart`. Pictures are files like every other
  image; a character's extra avatars live in `Character.avatars` and are resolved
  only through `AppState.avatarPoolFor`/`avatarRefFor`. Pictures picked off the
  device come in as `GalleryUpload`s — a **path** and the name it is being given —
  through `AppState.addGalleryPictures`, which reads and writes one at a time;
  the picker is called without `withData` for the same reason a backup is never
  held whole. Each gets its own title (`showGalleryNamingSheet`); the old shared
  title with a number stuck on the end is gone. `addGalleryImages` is still the
  in-memory door, for bytes that already exist (a generated picture).
- **Chat Interface settings:** a **hub of spokes**, not one long page.
  `screens/settings/chat_interface_settings_page.dart` is the hub (it keeps that
  name and path so every caller is untouched); each spoke is a file under
  `screens/settings/chat_interface/` — layout, avatars, names, colours, text,
  message actions, and a group-chat-bar page that only appears while group chats
  are on. `controls.dart` holds the shared row widgets and `spoke.dart` the frame
  (`ChatUiBuilder` resolves app-wide-vs-draft; `SpokeScaffold` gives every page
  the preview eye and an optional per-spoke reset). Every spoke takes the same
  `SettingAnchor? highlight` and `ChatUiScope? scope` the hub does, so search
  deep-links onto a short page and the per-chat route serves a draft. Two things
  that were never interface settings — `responseHintEnabled`/`responseHintDepth`
  and `groupChatsEnabled` — are edited in `settings/chat_behaviour_page.dart`
  instead; the fields still live on `ChatInterface` and are still read app-wide,
  so nothing migrated.
- **Saved looks (interface presets):** `models/interface_preset.dart` (an
  `InterfacePreset` is a name plus a whole `ChatInterface`;
  `kBuiltInInterfacePresets` ships four, told apart by a `builtin:` id and not
  deletable), the `interfacePresets` store entry, `AppState`'s
  save/apply/rename/delete, `widgets/interface_preset_sheet.dart` (the sheet, from
  the square at a chat's top-right *and* the Chat Interface app bar), and
  `services/interface_preset_io.dart` (one self-contained JSON per look, with its
  pictures base64'd in). A look carries **appearance only**:
  `ChatInterface.lookOnly` strips the Chat behaviour switches and `applyLook`
  lays a look over whatever they currently are, so switching to Document cannot
  switch off group chats. Applying from inside a chat asks once — every chat, or
  this one — and routes to `updateChatInterface` or
  `saveChatInterfaceOverride`; there is no third writer.
- **Chat UI:** `screens/chat_screen.dart`, `widgets/message_bubble.dart`
  (swipes/variants, per-message action bar, name placement, attachments),
  `widgets/thinking_block.dart`, per-chat settings screen,
  `screens/prompt_view_screen.dart` (View prompt inspector). Deleting a turn
  always asks first, and a turn with replies after it offers both deletes —
  `_ChatScreenState._deleteMessage` is the one dialog behind every route to it
  (the inline symbol, the overflow menu, the long-press sheet), over
  `AppState.deleteMessage` / `deleteMessagesFrom`. A turn's alternatives are a
  **ring**: the ‹ 1/2 › arrows wrap at both ends, and a sideways drag across the
  turn steps through them (left = next). Editing happens **in the turn itself** —
  `MessageBubble(editing:)` makes the words editable where they sit and swaps the
  action bar for ✕/✓; the avatar, name, pictures and layout do not move. Both of
  those have sharp edges worth reading before touching them (gesture-arena order,
  field height, deferred save): `developer notes/feature-notes-and-test-traps.md`.
- **Response hint:** a line of steering typed beside a chat and injected into
  every send until it is erased (Agnai's own hint, plus a depth). Switched on
  app-wide in Chat Interface (`ChatInterface.responseHintEnabled` /
  `responseHintDepth`, read from the app-wide interface like `groupChatsEnabled`,
  never from a per-chat copy); the text is per chat in its own `responseHints`
  store entry, resolved only through `AppState.activeResponseHint`. It reaches
  the wire as a depth injection with the *lowest* injection order, so it lands
  last at its depth — closest to the reply it is steering — wrapped by
  `PromptBuilder.wrapResponseHint` and re-tagged to a `user` turn by
  `_oneSystemBlock` like every other in-chat block. The no-preset path in
  `AppState._assemble` places it by hand, because there is no builder there to do
  it. The composer keeps the text in its own controller and only writes it to the
  store on close/send/leaving the chat — a prefs write per keystroke is a file
  rewrite per keystroke.
- **Pictures in a chat (sending):** `models/message_image.dart` — a turn's
  `ChatMessage.images` hold a `local:`/URL ref plus a mime; the base64 only exists
  on the copy `AppState._wireImages` builds, capped at `kMaxWireImages` newest.
  Each dialect carries an attachment differently and the four shapes live together
  in `ChatClient`'s "attachments" block (`anthropicTurn`, `geminiParts`,
  `_responsesImage`, `ChatMessage.openAiContent`); `requestPreview` elides the
  payload. The composer's tray (`_AttachBar` in `chat_screen.dart`) opens off the
  operations strip and offers gallery-or-device, then previews what will be sent.
  `test/image_wire_test.dart` asserts the outgoing bytes per dialect.
- **Image studio (generation):** `models/image_gen.dart` (`ImageGenConfig` — its
  own endpoint and key, deliberately *not* the chat provider, which is what makes
  "every chat can generate a picture" true), `services/image_client.dart` (OpenAI
  `/images/generations`, multipart `/images/edits` when there are reference
  pictures, and Gemini `:generateContent` asking for an image modality; failures
  are `ChatApiException` with the chat client's own wording),
  `screens/image_gen/image_gen_sheet.dart` (a 75%-height sheet with its settings
  page swapped in *inside* the sheet) + `image_gen_settings.dart`. Everything it
  makes is filed in the gallery under the chat's character by
  `AppState.generateImages`; "Send to chat" goes through `postImageToChat`. Reached
  from the drawer footer, the composer's operations strip, and
  `MessageAction.imagine`.
- **Chat tools:** `models/chat_tool.dart` defines portable configurations,
  variant-owned run records and pure tracker projection; `services/chat_tools/`
  owns schemas, bounded Recipe JSON execution and dice. `state/chat_tools_state.dart`
  coordinates normal chat generation through `AgentClient`, retaining the
  selected provider, model, preset, budget and stream cadence. Tool calling
  starts disabled; per-chat configurations are full overrides. Execute only
  complete calls from a successfully completed response: EOF, truncation and
  cancellation cannot run partial operations. Preserve opaque dialect metadata,
  complete call/result exchanges during trimming, and local-effect preconditions.
  Swipes, forks, deletes and restarts project saved results rather than running
  handlers again. Generated pictures belong to the producing variant, including
  inactive alternatives in retention. Redacted actual requests feed View prompt;
  reopening reconstructs requests from records without executing tools. See
  `developer notes/chat-tool-calling-plan.md` and actual-wire integration tests.
- **Saved side conversations (`/btw`):** `models/btw_conversation.dart`,
  `state/btw_state.dart`, and `widgets/btw_thread_controller.dart` persist threads
  in `btwThreads`, separately from roleplay messages, summaries and story context.
  Each main chat loads its own threads; restored partial replies are stopped.
  Provider/model, system prompt and tools can be overridden per thread. Budget
  the final side prompt with completed successful exchanges, preserving the
  single-leading-system rule and protected in-chat instructions. Side requests
  have independent cancellation and usage accounting; deleting a thread or chat
  cancels both answer and title requests. Serialize thread, preference and usage
  writes. Restore fences old callbacks, cancels jobs and drains pending writes
  before loading the archive; an idle queue must not block `flushPendingSaves`.
  Preserve these rules when a controller is disposed mid-restore. Thread exports
  are scoped to one thread. The shared Chat/Playground panes use retained
  transforms during drag, exclude covered surfaces from focus/semantics/taps,
  and keep 48 dp controls available with short keyboards or large text. See
  `developer notes/chat-ui-panes.md` for motion and settings contracts.
- **Character Studio:** `models/studio.dart` owns a draft `StudioWorkspace`,
  transcript, sub-agents, plan and spend. `StudioSession.edit` snapshots changes
  synchronously; hand edits and rewinds advance revisions checked by
  `models/studio_revisions.dart`, so stale writes fail rather than overwrite
  newer work. `services/studio/studio_store.dart` writes one JSON file per
  session, outside preferences; `StudioStore.pictureRefs` keeps session images
  during sweeping. Session files are not automatically part of snapshot backups.
  `studio_controller.dart` and `agent_runner.dart` own isolated runs; compaction
  preserves complete tool exchanges, every call receives a result even on Stop,
  and the final step declares tools with calls disabled. Interrupted sessions
  repair orphaned calls before Resume; process-death recovery is not a native
  background service. Sub-agents have bounded parallelism and no recursive
  delegation. `AgentClient` supports all four dialects, complete arguments,
  reused call indexes and required opaque provider metadata.
  The Playground embeds the real `ChatScreen` through `ChatScreenHost` and
  `state/chat_host.dart`, with session-owned chats outside
  `AppState.conversations`. Saves and forks stay with the host, including replies
  arriving after detachment. Resolved draft copies follow `draftVersion`; chat
  edits cannot silently mutate library cards. Presets are independent workspace
  copies, snapshotted and revisioned; apply upserts them without changing the app
  default. Studio prompt sizing and playtests use real chat assembly, and its
  context inspector must match actual outgoing requests. AppState's Studio client
  and usage path never take ownership of ordinary chat's `_streaming` flag.
- **Home launcher:** `models/home_layout.dart` owns grid geometry and repairs
  imported layouts. `screens/home_screen.dart` edits a draft and writes
  `homeLayout` on Done; notes live separately in `homeNotes`. Widget specs in
  `screens/home/home_spec.dart` and `home_widgets.dart` resolve content against
  available tile dimensions and text scale; `HomeShrink` bounds width and cannot
  contain a vertical `Expanded`. Retain pages and tile children during swipes,
  isolate painting, and select value-comparable state through `homeWatch`.
  Only visible pages tick. Timers and controller listeners must also honor
  `TickerMode`; disabling animation tickers alone does not stop them. Cost
  selectors use ledger identity and revision instead of aggregating history
  on each notification. A hold opens the anchored menu and moving carries the
  tile in an overlay; tapping in edit mode selects and exposes resize handles.
  Resize grips claim pointer-down, retain recognizers throughout previews and
  hold page scrolling until that pointer releases or cancels. Keep a draggable
  center on dense grids, preserve pointer ownership, and clear transient state
  on exit. Gesture frames update the overlay without rebuilding Home/pages.
  Selection outlines follow the tile's own shape. Record-valued animation
  cleanup uses equality or generations, not `identical`. See
  `developer notes/home-v2-plan.md` and Home interaction/activity/size tests.
- **Expressive theme:** `Appearance.expressive` and `palette` select the
  Material 3 Expressive shapes, typography, controls and transitions through
  `MaiChatApp._expressive`. Do not give button themes a resolved
  `textStyle` with `inherit: false`; interpolation against defaults can throw.
- **Branches / Chat Graph:** a branch is a whole `Conversation` linked to its
  source by `Conversation.parentId` + `forkIndex` (set only by
  `AppState.forkConversation`). `services/chat_graph.dart` is the pure view over
  that: `buildFamilyTree`/`flattenGraph` for `screens/chat_graph_screen.dart`,
  and `collapseForks` → `ChatTreeEntry`, which is why a tree is **one row** in
  the Chats/Home lists (named after its root, previewing its freshest branch).
  A missing parent degrades to a root — no cascade delete, no dangling tree.

## Checks requiring a device or external service

- **Touch and rendering performance:** validate the gallery pinch ladder,
  floating-picture drag/resize/rotation, and chat scrolling during streaming on
  a physical device. Include Home carry/resize/page gestures and the chat/side
  pane keyboard transitions. Widget tests establish offsets and extents, not
  perceived smoothness.
- **Image endpoints:** loopback tests cover supported protocol shapes. Test a
  configured endpoint to establish its accepted quality/size values and whether
  it returns image URLs or base64 data.
- **Saving pictures:** `FilePicker.saveFile` opens the system save dialog and
  writes to the chosen location. It does not insert a picture directly into
  Android MediaStore; that would require native platform integration.
- **Google Drive backups:** `test/drive_client_test.dart` covers consent, PKCE,
  token exchange, upload, listing, download, and delete against a loopback
  server. Check browser return to `http://127.0.0.1:<port>` and Drive API
  availability with the configured OAuth project and account on a device.
- **Discover:** Chub can apply geographic restrictions to datacenter IPs and
  JannyAI can present Cloudflare challenges. Loopback tests establish client
  contracts, while live service access and challenge replay need separate
  verification. Inspect a failure response before attributing it to the client.

## Portable development environment

The devcontainer pins Flutter 3.44.9 and prepares Android dependencies without
restoring account data or installing an assistant CLI. Prefer loopback wire
tests, `flutter analyze`, `flutter test`, and a Linux smoke build under `xvfb`
for reproducible checks. Device testing remains necessary for touch behavior,
platform integration, and rendering performance.
