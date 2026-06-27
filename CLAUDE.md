# CLAUDE.md - BroPrompter

Native macOS teleprompter (SwiftUI) with camera preview, auto-scroll, and audio /
video recording. Tracked in YouTrack project **BROP** (epic BROP-1; phases
P0-P8 = BROP-2 through BROP-10).

## Read the reference docs before any work (MANDATORY)

Before writing or editing any code, design, or UI in this repo, read BOTH:

- `DESIGN.md` - the visual system. macOS 26 (Tahoe) tokens, the 71-component
  inventory, and each component mapped to its SwiftUI equivalent. Tells you WHAT
  to build with (colors, type, materials, Liquid Glass, metrics).
- `GUIDELINES.md` - the HIG behavior contract. Permissions, camera/recording UX,
  full-screen, accessibility, and macOS conventions. Tells you HOW and WHEN to
  use those components, per phase.

This is not optional and not "only for UI tasks." Permissions, accessibility,
menus, and shortcuts touch nearly every phase. Re-read the relevant section of
each doc at the start of every task before changing code.

- BAD: open a BROP task and start writing SwiftUI from memory of macOS norms.
- GOOD: read `DESIGN.md` + `GUIDELINES.md` (at minimum the sections the
  per-phase checklist in GUIDELINES.md section 6 maps to this BROP phase), then
  write code that cites the token / rule it follows.

## Track all work in YouTrack (MANDATORY)

All real work and every future / planned task for this project live in YouTrack
project **BROP**. Never leave plans, TODOs, or multi-step work only in chat, in
code comments, or in `DESIGN.md` / `GUIDELINES.md`. If it is worth doing, it is a
BROP issue first.

Triggers and required actions:

- Before starting any task: find its BROP issue, or create one if none exists,
  and set State to `In Progress`. Do not start coding or design on tracked work
  that has no open issue.
- As work progresses: update State on the issue, not in a batch at the end. Set
  `Fixed` when the work is done and `Verified` after you have proven it.
- When you or the user plan new work (a feature, phase, screen, refactor,
  follow-up, or the real-fix follow-up for a band-aid): create the BROP
  issue(s) in the SAME turn the plan is made. Future tasks are filed when
  planned, not when started.
- Always call `get_issue_fields_schema` for BROP before any create / update.
  BROP uses State {Submitted, Open, In Progress, ..., Fixed, Verified} and Type
  {Task, Feature, Bug, Epic, ...}. Passing a value the project lacks fails.

Issue structure (attach new issues under the right parent):

- Epic `BROP-1` = the v1 app.
- `BROP-2`..`BROP-10` = implementation phases P0-P8.
- `BROP-11` = Figma design prototype workstream; subtasks `BROP-12`..`BROP-16`
  = design phases D1-D5.
- New implementation work -> subtask under the relevant phase (or `BROP-1`).
  New design work -> subtask under `BROP-11`. Reserve the `P` prefix for
  implementation phases and `D` for design phases.

- BAD: agree on a 5-step plan in chat, start building, and never file the issues.
- GOOD: file the BROP issues for the plan first, set the active one
  `In Progress`, then build; flip State as each one completes.

Tooling: the YouTrack MCP tools (`mcp__youtrack__*`). The instance URL and token
live in the YouTrack MCP server config (untracked); read them from there and
never hardcode the domain in this repo.

## Working rules derived from the docs

- Semantic, never literal. Use system tokens (`Color.accentColor`, `.body`,
  `.regularMaterial`, `.controlSize`), never hardcoded hex / point sizes / RGBA.
  Source of truth: `DESIGN.md` sections 2-5.
- Permissions in context. Request camera / mic when the feature is used, behind
  a pre-prompt explainer, with graceful denial and a Settings recovery path.
  Source: `GUIDELINES.md` section 1. This lands in P0 (BROP-2).
- Accessibility is a feature here, not a polish step. Contrast over the camera
  preview, Dynamic Type for chrome, Reduce Motion, VoiceOver, Full Keyboard
  Access. Source: `GUIDELINES.md` section 4.
- Match macOS conventions: real menu bar, standard + teleprompter shortcuts,
  NavigationSplitView, Settings via Cmd-, . Source: `GUIDELINES.md` section 5.

## Tech stack

- SwiftUI first; drop to AppKit (`NSViewRepresentable`) only where SwiftUI lacks
  the control (true vibrant sidebar, custom cursors).
- Project generated with XcodeGen (`project.yml`). Build via CLI / Xcode, not by
  hand-editing the `.xcodeproj`.
- Min macOS 15; macOS 26 (Tahoe) for full Liquid Glass.
- Bundle identifier: `com.nhannht.BroPrompter` (branding namespace `nhannht`).
  iCloud container: `iCloud.com.nhannht.BroPrompter`. Use these for the app
  target, signing, and the CloudKit entitlement in P0 (BROP-2).

## Docs are linted

`DESIGN.md` and `GUIDELINES.md` are checked with Vale against Google's
developer-documentation style guide (target: 0 errors). When you edit a doc,
re-run the lint and keep it at 0 errors.
