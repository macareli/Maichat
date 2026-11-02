# Chat tool calling — implementation plan, points 1–5

This records the upstream implementation scope from 2026-10-26, based on source
commit `1f46ea9`. Completed checkboxes describe that implementation; they do not
authorize publication or establish validation of the integration into
`macareli/Maichat`. Follow [AGENTS.md](../AGENTS.md) for current project guidance.
All dated test/build results below are **historical upstream validation**.
The initial implementation's ephemeral side answers were later superseded by
saved threads; see [chat-ui-panes.md](chat-ui-panes.md) for the current behavior.

## 1. Reuse harness transport without changing chat generation settings

- [x] Keep ordinary chat's selected provider, model, preset, character, prompt
  assembly, usage budgets and stream-paint cadence.
- [x] Reuse AgentClient's four dialect adapters; add an explicit successful
  completion contract so EOF, truncation and Stop cannot execute partial calls.
- [x] Carry normal generation parameters into tool requests, with dialect-aware
  filtering; preserve provider-required call metadata.
- [x] Verify actual loopback requests, streaming and whole responses.

## 2. Chat-owned execution and history

- [x] Add optional persisted run history to each message variant, retaining old
  records and selected-swipe behavior.
- [x] Run enabled tools sequentially inside one bounded/cancellable logical run;
  record errors as results and aggregate usage across requests.
- [x] Keep complete call/result exchanges together in history and context
  budgeting, and keep structured values out of prose regex/macro processing.
- [x] Record results before follow-ups; loading history never invokes a handler.
- [x] Show compact readable actions/results with inspectable details.

## 3. Tool library and Settings → Tool calls

- [x] Persist global defaults and per-chat overrides through one resolver.
- [x] Ship dice/random and tracker operations; gate image and management tools
  by actual configuration and calling context.
- [x] Provide create/edit/test/duplicate/delete, enablement and import/export.
- [x] Custom tools contain schema plus executable action source. Initial runtime:
  a portable JSON recipe language supporting references, operation calls,
  variables, arithmetic, conditions and returns with bounded execution. This
  avoids pretending a schema is an implementation; the editor labels the language.
- [x] Use the current Material 3 Expressive theme, accessible controls and
  explicit app-wide/this-chat scope. Test meaningful settings/editor flows.

## 4. Tracker and image ownership across history changes

- [x] Define typed tracker records with subject, label, unit, bounds and value;
  expose define/read/update, including set and numeric delta.
- [x] Journal before/after effects against reply variants; project selected
  history rather than rerunning actions on load/swipe/fork.
- [x] Detect stale dependent effects after an earlier alternative changes;
  keep transcript text and surface that regeneration is required.
- [x] Place stat results below replies or in a pinned chat panel, as configured.
- [x] Reuse Image Studio requests/gallery storage and attach generated file refs
  to the producing variant. Preserve files for inactive swipes, export and backup.
- [x] Stop covers pending actions; interrupted remote-image outcomes are not
  automatically retried.

## 5. Tool-capable `/btw`

- [x] Retain aside analysis outside the roleplay transcript with independent
  cancellation and the chat's own selected model/context.
- [x] Support tracker operations, tool-library inspection and tool authoring.
  A generated tool uses the same validated executable definition as settings;
  global/chat scope is explicit.
- [x] Add OOC correction operation with text, depth N and lifetime. N counts RP
  messages; expiry happens after a completed logical character reply, not a tool
  round. Preserve the existing response hint and one-leading-system wire rule.
- [x] Coordinate writes with an active main reply; preserve source context for
  forks and stale-effect detection.

Dynamic agentic lore policy, autonomous lore/summary editing, and delayed N
replies are later work. They are outside these five points.

## Acceptance and verification

Demonstrate tool-only and mixed responses, saved dice results, state after
swipe/regeneration/fork/delete/restart, custom recipe import/export and test,
scoped `/btw` authoring/OOC correction, and variant-owned generated images.
Cover malformed/disabled/unknown tools, incomplete responses, limits, Stop,
actual outgoing requests and persistence. Re-run Studio tests for shared-client
regressions. Finish with `flutter pub get`, clean `flutter analyze`, green full
`flutter test`, and a Linux/xvfb smoke check where supported. Report device and
live-endpoint limits explicitly. Monitor any started build to completion.


## Delivered implementation

The upstream implementation was completed from source commit `1f46ea9`.
The five points above were implemented. Upstream verification completed on
2026-10-26: clean analyzer, green full suite, generated UI previews and a
Linux release startup smoke check. The first full run passed the existing tests and exposed an
in-progress Stop-test/cleanup mismatch, subsequently corrected and checked in
focused tests. Do not cite that first run as a green full-suite result.

- `lib/models/chat_tool.dart`: portable definitions/configuration, per-variant
  run records, effects and pure state projection. `message.dart` and
  `conversation.dart` persist records, controls and per-chat overrides. A
  transient prompt-protection marker never enters saved chat data.
- `lib/services/chat_tools/`: shipped schemas, strict argument/schema and recipe
  validation, executable Recipe JSON, bounded arithmetic/control flow, and the
  dice service shared with existing roll macros.
- `lib/state/chat_tools_state.dart`: ordinary-chat orchestration, scoped tool
  operations, usage/budget/cancellation, complete-exchange context trimming,
  persisted results, tracker projection and `/btw` management. Runs carry a
  history anchor, endpoint/model provenance and local effect preconditions.
- `AgentClient` reuses normal chat sampling fields while retaining dialect
  call/result shapes and required opaque output blocks. Successful completion
  is required for tool-enabled chat; EOF/truncation do not execute actions or
  consume a next-reply correction. Tool-enabled rounds use one candidate.
- Settings → Tool calls is the global library; Chat settings → Tool calls is a
  full per-chat override with Follow app defaults. Built-ins can be inspected,
  tested and duplicated; custom recipes can be edited, deleted and exchanged as
  versioned MaiChat JSON files. Built-in implementation code is not exported as
  portable user code. ST slash-command closures are not imported as executable
  recipes.
- `/btw` analysis remains ephemeral and outside RP. Requested tracker/control
  changes and saved tool definitions persist. While a main reply is running,
  aside queries have read-only capabilities. Global/chat tool creation is
  explicit; the default requested authoring scope is this chat.
- Corrections have a depth and next-reply/persistent lifetime. Preset injections
  reserve context budget separately from the existing response hint. Timed-out
  or stopped work keeps a cancellation flag even after the run ends.
- Generated images use Image Studio configuration and gallery storage, with
  file refs on the producing variant. All alternatives are included in picture
  retention; image requests have separate transport ownership from Image Studio.
- Redacted actual request snapshots for the last eight runs are retained in
  memory for View prompt, including each round. After reopening, the inspector
  reconstructs requests from saved structured records; it does not recover old
  in-memory snapshots or invoke handlers.
- Tool calling starts disabled. The shipped catalog is visible before enabling;
  actual model/endpoint support is still required. Numeric tracker IDs are
  unique within a chat; subject/label/unit/bounds are configurable.

Generated previews use synthetic data and the actual screens/theme:
[settings](../docs/previews/chat-tool-calls.png) and
[chat results](../docs/previews/chat-tool-results.png).
Regenerate explicitly with:

```text
flutter test --no-pub test/screenshots/chat_tools_preview.dart --update-goldens
```
No screenshot generator runs in the default test suite.

Practical behavior notes: per-chat settings are full overrides, matching other
MaiChat settings. Recipes execute the enabled operations available in their
calling context; keep a recipe's dependencies enabled. The initial trackers are
numeric; separate subjects should have distinct IDs (for example `aria_health`
and `bandit_health`). These are implementation choices, not claims of a general
JavaScript runtime or a third-party extension API.


## Historical upstream verification — 2026-10-26

These source-machine results predate the target integration. They do not
establish that the integrated revision passes analysis, tests or builds.

- `flutter pub get`: succeeded; no dependency declarations/lockfile changes.
- `flutter analyze --no-pub`: **No issues found**.
- Focused wire/runtime/settings checks: **103 passed**.
- `flutter test --no-pub -j 2 --reporter expanded`: **3,568 passed**, terminal
  exit 0; final run completed in 8 minutes 28 seconds. No application source
  changes were made during this final run.
- Explicit generated-preview run: **2 passed**; both previews were visually
  inspected. Narrow slider labels were corrected and checked at 320/600 logical
  pixels with text scales 1.0/1.5.
- `flutter build linux --release --no-pub`: succeeded, terminal exit 0. Binary:
  `build/linux/arm64/release/bundle/maichat`.
- Linux release launched under `xvfb-run` with software rendering and isolated
  XDG data/config/cache directories. It stayed alive for 12 seconds, then its
  process group was intentionally stopped. This is a startup smoke check;
  rendered feature screens were inspected through generated widget previews.
- `git diff --check`: clean in the upstream verification pass.

Still unverified: Android/device touch and keyboard behavior, on-device
performance, and actual chat/image provider endpoints. The tested protocol
compatibility is loopback-fixture coverage across four dialects, not a claim
that every compatible host accepts every model/schema combination. Validate
the integrated revision separately and follow the current repository's build
and signing requirements.
