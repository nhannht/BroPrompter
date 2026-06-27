# BroPrompter HIG Guidelines

Behavioral rules for BroPrompter, distilled from Apple's Human Interface
Guidelines (HIG) and scoped to what this app actually does: a macOS teleprompter
that previews the camera, scrolls a script, and records audio or video.

This is the **how and when** companion to `DESIGN.md` (the **what** - tokens and
components). DESIGN.md tells you which control to use; this file tells you how to
behave with it.

- Distilled, not copied. Apple's HIG text is copyrighted; this is a working
  summary with links. Read the linked pages for the full guidance.
- Verified against the HIG, June 2026. See Sources at the end.
- Each section maps to the BROP phase it affects.

```
DESIGN.md  -> visual contract  (colors, type, components -> SwiftUI)
GUIDELINES.md -> behavior contract (permissions, a11y, full screen, macOS norms)
```

---

## 1. Privacy and permissions  (feeds BROP-2 / P0)

The single most important behavior in this app. BroPrompter needs camera and
microphone access, and macOS gates both behind the user's consent.

### 1.1 Principles

- Be transparent about what you access and why. Request access only for what the
  current feature needs.
- Request in context, never at launch. Ask for the camera when the user opens
  the camera-preview teleprompter; ask for the mic when they start an
  audio/video recording. Do not prompt on first run before any feature is used.
- Explain before the system prompt. Show your own pre-prompt screen that states
  the benefit in plain language, then trigger the system dialog. A clear
  explanation raises grant rates significantly.
- Degrade gracefully on denial. If the user denies the camera, the
  text-only teleprompter and audio recording must still work. If they deny the
  mic, video-without-audio or text-only must still work. Never dead-end.
- Offer a recovery path. After a denial, explain what is unavailable and link to
  System Settings > Privacy and Security so they can change their mind. You
  cannot re-prompt once denied; only the user can re-enable in Settings.

### 1.2 Required Info.plist strings

The system shows these usage strings in its permission dialog. Write them in the
user's terms, naming the benefit.

- `NSCameraUsageDescription` - for example, "BroPrompter shows the camera behind your
  script so you can read while looking at the lens, and records video takes."
- `NSMicrophoneUsageDescription` - for example, "BroPrompter records your voice for
  audio and video takes."

Missing strings cause an immediate crash on first access. This belongs in P0.

### 1.3 Permission flow

```
User opens camera teleprompter / taps Record
        │
        ▼
  Check AVCaptureDevice.authorizationStatus(for:)
        │
   ┌────┴───────────────┬───────────────────┬──────────────────┐
   ▼                    ▼                   ▼                  ▼
.notDetermined     .authorized        .denied            .restricted
   │                    │                   │                  │
   ▼                    ▼                   ▼                  ▼
Show pre-prompt     Proceed          Show "needs access"   Explain managed
explainer screen                     state + button to     device, no path
   │                                 open System Settings   to enable
   ▼
requestAccess(for:) -> system dialog
   │
   ├─ granted  -> proceed
   └─ denied   -> graceful degrade + Settings path
```

SwiftUI / AVFoundation skeleton:

```swift
switch AVCaptureDevice.authorizationStatus(for: .video) {
case .notDetermined:
    // show your own explainer first, then:
    let granted = await AVCaptureDevice.requestAccess(for: .video)
case .authorized:
    break // proceed
case .denied, .restricted:
    // disable the feature, show a Settings deep link
    // NSWorkspace.shared.open(URL(string:
    //   "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
default:
    break
}
```

- Do: pair each request with the matching pre-prompt copy.
- Don't: request camera and mic together at launch "to get it over with."

---

## 2. Camera and recording UX  (feeds BROP-5 / P3, BROP-6 / P4)

### 2.1 System privacy indicators are not yours to control

While the camera is active, macOS shows a green dot near the menu bar; while the
mic is active, an orange dot. These are system-owned and cannot be hidden or
restyled. Do not draw fake indicators or try to obscure the real ones. Design
your own recording state to live with them, not replace them.

### 2.2 Your in-app recording state

- Make the recording state unmistakable. Use a clear control that changes
  between idle and recording, a visible elapsed-time counter, and an audio level
  meter when the mic is live. (See DESIGN.md: `record.circle`,
  `.glassProminent` tinted `.red`, `ProgressView` / `Gauge` meter.)
- Count the user in. A 3-2-1 countdown before recording starts is expected for
  on-camera reads; show it large and center.
- Confirm the result. After stopping, land the user on the new take with clear
  next actions (play, re-record, trim, share, delete).
- Protect the take. Warn before any action that discards an unsaved recording.

### 2.3 Reading while recording

The whole point is reading near the lens. Keep controls out of the reading path:
float the transport over the lower third, keep the focus line near the top where
the eyeline sits, and let the camera preview read through translucent chrome
(DESIGN.md: `Glass.clear` / `.ultraThinMaterial`).

---

## 3. Full-screen and presentation mode  (feeds BROP-4 / P2, BROP-9 / P7)

A teleprompter is used full screen. Follow macOS full-screen conventions.

- Enable full screen because it fits. Reading at distance is a genuinely
  immersive task, so full screen is appropriate here.
- Hide chrome, reveal on intent. Like QuickTime during playback, hide toolbars
  and controls during scrolling, and reveal them on pointer move or key press.
- Keep essential controls reachable. Play/pause, speed, and exit must always be
  one gesture or key away. Never trap the user.
- Let people enter Mission Control. Respect the system shortcuts and gestures;
  do not capture them.
- Let people choose when to exit. Do not auto-exit full screen when scrolling
  ends or when the app loses focus. Exit on the user's command (Esc or the
  standard control) only.

---

## 4. Accessibility  (cross-cutting; verify each phase)

A teleprompter is a reading tool, so legibility and motion settings are core
features, not extras.

- Contrast. Reading text must meet at least 4.5:1 against its background; large
  display text at least 3:1. The teleprompter text over a camera preview is the
  risk spot - add a scrim or shadow behind text so it always clears the bar over
  any video.
- Dynamic Type for chrome. Use the system text-style tokens so sidebar,
  settings, and labels scale with the user's preference without truncation
  (DESIGN.md section 3). The teleprompter reading size is separately
  user-controlled and should range wide (about 24 to 120 pt).
- Reduce Motion. Respect `accessibilityReduceMotion`. The auto-scroll is the
  app's main motion; when Reduce Motion is on, avoid extra animated flourishes
  and keep transitions plain. Do not turn off the scroll itself (it is the
  feature), but drop decorative motion around it.
- VoiceOver. Give every control a descriptive label (record, play, speed,
  font size, exit). Counters and meters need labels and live values.
- Full Keyboard Access. Every task must be possible from the keyboard alone:
  start/stop, play/pause, speed up/down, jump to top, font size. This pairs with
  the keyboard shortcuts in section 5.

---

## 5. macOS conventions  (feeds BROP-3 / P1, BROP-9 / P7)

Mac users expect Mac behavior. Meet the platform norms instead of inventing.

### 5.1 The menu bar

- Provide real menus. Users rely on the menu bar to learn what an app does and
  to find commands. Build them with SwiftUI `.commands { }` / `CommandMenu`.
- Use the standard menus and default order: the app menu, File, Edit, View,
  Window, Help, plus a teleprompter-specific menu (for example "Script" or
  "Playback") placed before Window.
- Mirror every important action in a menu, even when it also has a button. The
  menu is the discoverable home for commands.

### 5.2 Keyboard shortcuts

- Honor the standard shortcuts people already know: Cmd-N (new script),
  Cmd-S (save), Cmd-Z / Shift-Cmd-Z (undo/redo), Cmd-F (find), Cmd-W, Cmd-Q,
  Cmd-, (Settings).
- Add teleprompter shortcuts and surface them in the menus: Space (play/pause),
  Up/Down or +/- (speed), R (record), Cmd-Return (full screen), Esc (exit).
- Do not override a standard shortcut with a non-standard action.

### 5.3 Windows, sidebar, toolbar

- Use the standard structure: a `NavigationSplitView` with a script sidebar and
  a detail area, a standard title bar, and a toolbar for the primary actions
  (DESIGN.md section 7.6).
- Settings live in a Settings window opened with Cmd-, , not in an ad-hoc panel.
- Remember window state and the last-opened script across launches.

---

## 6. Per-phase checklist

| BROP phase | HIG obligations from this doc |
|---|---|
| P0 (BROP-2) | Usage strings; in-context, explained permission requests; graceful denial; Settings recovery path (section 1) |
| P1 (BROP-3) | Standard menus + shortcuts; sidebar/window conventions (section 5) |
| P2 (BROP-4) | Full-screen chrome hide/reveal; keep exit + transport reachable (section 3) |
| P3 (BROP-5) | Camera preview behavior; live with system green/orange dots (section 2) |
| P4 (BROP-6) | Clear recording state, countdown, level meter, confirm/protect take (section 2) |
| P5 (BROP-7) | VoiceOver labels; confirm-before-delete (sections 2, 4) |
| P7 (BROP-9) | Full Keyboard Access; Reduce Motion; Settings via Cmd-, ; contrast (sections 3-5) |
| All | Contrast, Dynamic Type for chrome, keyboard reachability (section 4) |

---

## 7. Sources

- Privacy - https://developer.apple.com/design/human-interface-guidelines/privacy
- Requesting authorization for media capture on macOS -
  https://developer.apple.com/documentation/bundleresources/requesting-authorization-for-media-capture-on-macos
- Accessibility -
  https://developer.apple.com/design/human-interface-guidelines/accessibility
- Going full screen -
  https://developer.apple.com/design/human-interface-guidelines/going-full-screen
- The menu bar -
  https://developer.apple.com/design/human-interface-guidelines/the-menu-bar
- Designing for macOS -
  https://developer.apple.com/design/human-interface-guidelines/designing-for-macos

Distilled and verified June 2026. When Apple updates the HIG, re-verify the
linked pages and update this file.
