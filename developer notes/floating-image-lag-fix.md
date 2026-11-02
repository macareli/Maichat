# Floating-image and chat rendering constraints

Floating-picture drag, pinch, resize, rotation, and placement share rendering
costs with the chat beneath them. Profile the chat build and paint work as well
as picture transforms when diagnosing stutter.

## Rendering and persistence rules

1. `_ChatBackground` in `lib/screens/chat_screen.dart` uses `Image(opacity:)`.
   Keep alpha at image paint level: a surrounding `Opacity` widget can create a
   full-screen offscreen save layer.
2. Floating-picture geometry is transient. `Conversation.toJson` excludes
   `floatingImages`, `settleFloatingImage` updates in-memory geometry, and
   add/remove operations notify through `_mutateFloats` without saving the whole
   conversation store. Floats survive navigation and forks but not app shutdown.
3. `MessageHtml` in `lib/widgets/message_html.dart` limits expensive
   `flutter_html` builds per frame with `_HtmlFrameBudget`. Its persistent frame
   callback resets the budget without an idle timer; deferred messages build in
   later frames, while a single streaming message stays within the budget.
4. Frame-budget diagnostics must use the actual display refresh rate. A fixed
   16 ms threshold misses dropped frames on displays faster than 60 Hz.
5. The manipulation picture keeps rounded corners using `ClipRRect`, without a
   shadow or close button. Verify the target renderer's cost before replacing
   this path with a heavier overlay technology.

## Profiling

`lib/services/jank_logger.dart` and Settings → Appearance → Record jank logs
record over-budget frames and streaming, picture-drag, and chat-open events.
`MessageBubble` and `MessageHtml` provide build and parse counters. Use traces
to distinguish UI build/layout work from paint or GPU costs. Physical device
checks are required for perceived smoothness and touch behavior.

Do not add a disk save to picture placement, replace image alpha with a
full-screen `Opacity`, or remove the per-frame HTML budget without measuring
and addressing the resulting frame costs.
