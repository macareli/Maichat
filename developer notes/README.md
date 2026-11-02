# Developer notes

Technical notes complement the project guide in [AGENTS.md](../AGENTS.md).
Read the relevant notes before changing an affected area. Check implementation
references against current code and keep these contracts and constraints current.

- [floating-image-lag-fix.md](floating-image-lag-fix.md) — rendering and
  persistence rules for floating pictures, backgrounds, and chat scrolling.
- [prompt-wire-and-storage.md](prompt-wire-and-storage.md) — the leading system
  message rule, file-backed pictures, startup repair, and rendering costs.
- [discover-source-contracts.md](discover-source-contracts.md) — third-party
  catalogue contracts, challenge handling, and verification limits.
- [chat-portability-formats.md](chat-portability-formats.md) — cross-app chat
  format contracts and compatibility tests.
- [google-drive-oauth.md](google-drive-oauth.md) — OAuth client setup, scope
  handling, streamed backups, and account checks.
- [feature-notes-and-test-traps.md](feature-notes-and-test-traps.md) — feature
  invariants and Flutter testing constraints.
- [screenshots.md](screenshots.md) — reproducible README images and their
  rendering constraints.

- [home-v2-plan.md](home-v2-plan.md) — Home launcher widgets, layout, and
  persistence behavior.
- [chat-tool-calling-research.md](chat-tool-calling-research.md) — tool-calling
  protocols and reuse research.
- [chat-tool-calling-plan.md](chat-tool-calling-plan.md) — tool configuration,
  integration behavior, and validation.
- [chat-ui-panes.md](chat-ui-panes.md) — chat panes, saved side threads,
  per-thread settings, request budgeting, and exports.
