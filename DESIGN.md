# BroPrompter Design System

Design reference for BroPrompter, derived from the **macOS 26 (Tahoe) UI Kit**
by Apple Design Resources, subscribed to the project's Figma file.

- Figma file: `macOS 26 (Community)` (key `Kr2Zuxzng8LUxWFAlqkQs4`); the BroPrompter
  design is on its `BroPrompter - *` pages (00 Cover / 01 Atoms / 02 Components / 03 Screens)
- Source library: **macOS 26**, Apple Design Resources, community, updated 2026-02-25
- Library key: `lk-52492a50a550...a714f2d76ade248` (Figma library, 71 components)
- Target platform: macOS 15 minimum, macOS 26 (Tahoe) for full Liquid Glass
- Implementation: SwiftUI first, AppKit (`NSViewRepresentable`) only where needed

> Provenance note: the design lives in a local duplicate of the macOS 26 kit
> (key `Kr2Zuxzng8LUxWFAlqkQs4`), where every component, text style, and variable
> collection is local and bindable. The macOS 26 community library does not import
> through the Figma plugin API, so the build pivoted to this duplicate. The
> original kit-holder file (key `BKwJLaGsWFPBM7S15ZebfN`) holds only empty pages
> and is orphaned. This document records the component inventory plus the macOS
> semantic token system mapped to SwiftUI / AppKit APIs. See the "Provenance and
> how to refresh" section at the end.

---

## 1. Core principle: semantic, not literal

macOS design is **adaptive**. Colors, materials, and type resolve at runtime
based on appearance (light / dark), the user's accent color, vibrancy, and
Liquid Glass. Do not hardcode hex values, point sizes, or RGBA.

- BAD: `Color(red: 0.0, green: 0.48, blue: 1.0)` for the accent.
- GOOD: `Color.accentColor` (follows the user's System Settings accent).
- BAD: `.font(.system(size: 13))` for body text in chrome.
- GOOD: `.font(.body)` (system-resolved, supports Dynamic Type).

Use semantic tokens. The system handles dark mode, contrast, and Liquid Glass
legibility for you.

---

## 2. Color

All colors below are semantic and adapt to light / dark automatically. Prefer
the SwiftUI form; drop to AppKit `NSColor` (wrapped in `Color(nsColor:)`) for
macOS-only semantic colors that SwiftUI does not surface directly.

### 2.1 Accent

| Token | SwiftUI | AppKit | Notes |
|---|---|---|---|
| Accent | `Color.accentColor` / `.tint(...)` | `NSColor.controlAccentColor` | Follows user's System Settings accent. Do not override globally. |

### 2.2 Label hierarchy (text on content)

| Token | SwiftUI | AppKit |
|---|---|---|
| Primary label | `Color.primary` | `NSColor.labelColor` |
| Secondary label | `Color.secondary` | `NSColor.secondaryLabelColor` |
| Tertiary label | `Color(nsColor: .tertiaryLabelColor)` | `NSColor.tertiaryLabelColor` |
| Quaternary label | `Color(nsColor: .quaternaryLabelColor)` | `NSColor.quaternaryLabelColor` |
| Placeholder text | `Color(nsColor: .placeholderTextColor)` | `NSColor.placeholderTextColor` |

### 2.3 Controls and backgrounds

| Token | SwiftUI | AppKit |
|---|---|---|
| Window background | `Color(nsColor: .windowBackgroundColor)` | `NSColor.windowBackgroundColor` |
| Control background | `Color(nsColor: .controlBackgroundColor)` | `NSColor.controlBackgroundColor` |
| Under-page background | `Color(nsColor: .underPageBackgroundColor)` | `NSColor.underPageBackgroundColor` |
| Control text | `Color(nsColor: .controlTextColor)` | `NSColor.controlTextColor` |
| Selected content | `Color(nsColor: .selectedContentBackgroundColor)` | `NSColor.selectedContentBackgroundColor` |
| Separator | `Color(nsColor: .separatorColor)` | `NSColor.separatorColor` |
| Grid | `Color(nsColor: .gridColor)` | `NSColor.gridColor` |

### 2.4 System palette (status, charts, accents)

`systemBlue, systemGreen, systemRed, systemOrange, systemYellow, systemPink,`
`systemPurple, systemTeal, systemCyan, systemIndigo, systemBrown, systemMint,`
`systemGray`.

SwiftUI shorthands: `.blue .green .red .orange .yellow .pink .purple .teal`
`.cyan .indigo .brown .mint .gray`. AppKit: `NSColor.systemBlue`, etc.

Use these for semantic status only (recording = `.red`, success = `.green`),
never as brand color. Brand expression on macOS comes from the accent + content,
not from recoloring chrome.

---

## 3. Typography

System font is **SF Pro** (text/display optical sizes auto-selected).
`SF Mono` for monospaced (timecodes, counters). Use the text-style tokens; the
system resolves the macOS point size and supports Dynamic Type.

### 3.1 Text-style tokens

| Style | SwiftUI `Font` | macOS reference size / weight (system-resolved, do not hardcode) |
|---|---|---|
| Large Title | `.largeTitle` | 26 pt / Regular |
| Title 1 | `.title` | 22 pt / Regular |
| Title 2 | `.title2` | 17 pt / Regular |
| Title 3 | `.title3` | 15 pt / Regular |
| Headline | `.headline` | 13 pt / Bold |
| Body | `.body` | 13 pt / Regular |
| Callout | `.callout` | 12 pt / Regular |
| Subheadline | `.subheadline` | 11 pt / Regular |
| Footnote | `.footnote` | 10 pt / Regular |
| Caption 1 | `.caption` | 10 pt / Regular |
| Caption 2 | `.caption2` | 10 pt / Medium |

> macOS uses a denser ramp than iOS (iOS Body is 17 pt, macOS Body is 13 pt).
> The reference column is the documented macOS default and is system-resolved at
> runtime; bind to the token, not the number.

### 3.2 Monospaced and emphasis

- Monospaced digits (counters, timecodes): `.font(.body.monospacedDigit())`.
- Full monospaced (SF Mono): `.font(.system(.body, design: .monospaced))`.
- Weight: `.fontWeight(.semibold)`. Emphasis: `.bold()`, `.italic()`.

### 3.3 Teleprompter reading text (app-specific)

Teleprompter reading text isn't chrome type. It's a large, user-adjustable
display size for reading at distance.

- Use `Font.system(size:weight:design:)` with a user-bound size, typically
  **24 to 120 pt**, default around 48 pt.
- Provide a font-size control (slider / stepper) and persist per script.
- Line spacing generous: `.lineSpacing(size * 0.3)` as a starting point.
- Keep weight `.medium` or `.semibold` for legibility at distance.

---

## 4. Materials and Liquid Glass

Translucent surfaces. On macOS 26 (Tahoe) the system layers Liquid Glass on
controls, toolbars, and chrome. Materials adjust contrast to stay legible over
whatever is behind them.

### 4.1 Material levels (SwiftUI)

| Level | SwiftUI | Typical use |
|---|---|---|
| Ultra thin | `.ultraThinMaterial` | Overlays over vivid content (camera preview) |
| Thin | `.thinMaterial` | Light floating panels |
| Regular | `.regularMaterial` | Standard panel / popover background |
| Thick | `.thickMaterial` | Heavier separation |
| Bar | `.bar` | Toolbar / control-bar backing |

Usage: `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))`.

### 4.2 Named materials (AppKit, via `NSVisualEffectView`)

`.menu .popover .sidebar .headerView .sheet .windowBackground .hudWindow`
`.underWindowBackground .selection .toolTip .contentBackground`. Use
`NSVisualEffectView.Material` through an `NSViewRepresentable` when SwiftUI's
material set is not enough (for example, a true vibrant sidebar).

### 4.3 Liquid Glass APIs (macOS 26 / iOS 26)

Verified SwiftUI surface:

```swift
// Apply glass to any view (default: .regular, capsule shape)
Text("REC").glassEffect()
Text("REC").glassEffect(.regular, in: .capsule, isEnabled: true)

// Variants
Glass.regular   // adaptive, medium transparency
Glass.clear     // high transparency, for media-heavy backgrounds
Glass.identity  // no effect (use to conditionally disable)

// Tint + interactive (chainable)
.glassEffect(.regular.tint(.red).interactive())

// Group + morph multiple glass elements
GlassEffectContainer(spacing: 30) {
    Button("Play")  { }.glassEffect()
    Button("Pause") { }.glassEffect()
}
// Morph identity across a namespace
.glassEffect().glassEffectID("controls", in: namespace)

// Glass button styles
Button("Cancel") { }.buttonStyle(.glass)
Button("Record") { }.buttonStyle(.glassProminent).tint(.red)

// Concentric corners (nest radii so inner/outer stay visually concentric)
.glassEffect(.regular, in: .rect(cornerRadius: .containerConcentric))
```

Guidance:
- Over the camera preview use `Glass.clear` or `.ultraThinMaterial` so the
  video reads through.
- Group the transport controls in one `GlassEffectContainer`.
- Do not stack glass on glass; one glass layer per floating cluster.

---

## 5. Metrics and layout

Prefer tokens (`controlSize`, layout guides) over hardcoded numbers.

- Control sizing: `.controlSize(.mini | .small | .regular | .large | .extraLarge)`.
- Standard window title bar height: ~28 pt (reference; system-managed).
- Sidebar: default ~180-260 pt, minimum ~150 pt; use `NavigationSplitView`
  column-width modifiers rather than fixed frames.
- Corner radius: macOS 26 favors larger, concentric radii. For nested glass /
  rounded containers use `.containerConcentric` so inner corners stay concentric
  with the outer shape instead of a fixed number.
- Spacing: lean on default `Spacer`, `VStack`/`HStack` spacing, and
  `.padding()` defaults. Hardcode spacing only for the teleprompter canvas.

---

## 6. Iconography

- Use **SF Symbols** (install the SF Symbols app to browse). Render with
  `Image(systemName:)`.
- Match symbol weight to adjacent text: `.imageScale(.medium)`,
  `.symbolRenderingMode(.hierarchical)` or `.palette`.
- BroPrompter symbol shortlist: `play.fill`, `pause.fill`, `record.circle`,
  `stop.fill`, `gobackward`, `goforward`, `text.alignleft`,
  `textformat.size`, `camera`, `mic`, `mic.slash`, `gearshape`,
  `arrow.up.left.and.arrow.down.right` (fullscreen), `list.bullet`,
  `scissors` (trim), `square.and.arrow.up` (share).

---

## 7. Component inventory (macOS 26 library)

71 components in the library; 61 resolved by name and key through the Figma MCP
(below), grouped by function with the SwiftUI equivalent to build with. The
remaining ~10 are listed in 7.9 as known-but-unresolved (MCP keyword search went
dry on them; they exist in the kit's Assets panel).

### 7.1 Buttons and actions (12)

| Component | Build in SwiftUI with |
|---|---|
| Push Button | `Button` + `.buttonStyle(.borderedProminent / .bordered)` |
| Arrow Buttons | `Stepper` or custom `Button` pair |
| Pop-Up Button | `Picker` (menu style) |
| Pulldown Button | `Menu` |
| Pop-Up with Menu | `Picker` / `Menu` |
| Pulldown with Menu | `Menu` with primary action |
| Disclosure Button | `DisclosureGroup` / `.disclosureGroupStyle` |
| Window/Button | `Button` in toolbar context |
| Window/Pop-Up Button | toolbar `Picker` |
| Window/Pull Down Button | toolbar `Menu` |
| Window/Button Group | `ControlGroup` |
| Color Well | `ColorPicker` |

### 7.2 Selection and input (17)

| Component | Build in SwiftUI with |
|---|---|
| Checkboxes | `Toggle` + `.toggleStyle(.checkbox)` |
| Radio Button | `Picker` + `.pickerStyle(.radioGroup)` |
| Switch | `Toggle` + `.toggleStyle(.switch)` |
| Segmented Control | `Picker` + `.pickerStyle(.segmented)` |
| Window/Segmented Control | toolbar segmented `Picker` |
| Slider | `Slider` |
| Slider - Center-biased | `Slider` (center-zero binding) |
| Dial (Circular Slider) | custom (no native SwiftUI dial) |
| Stepper/Inside Field | `TextField` + `Stepper` |
| Stepper/Outside Field | `TextField` + `Stepper` |
| Stepper/No Field | `Stepper` |
| Text Field | `TextField` |
| Search Field | `.searchable(...)` or `TextField` + role |
| Window/Search | toolbar `.searchable` |
| Combo Box | custom (`TextField` + `Menu`) |
| Leading Accessories | field accessory slot |
| Trailing Accessories | field accessory slot (clear, unit, icon) |

### 7.3 Indicators (2)

| Component | Build in SwiftUI with |
|---|---|
| Determinate (progress) | `ProgressView(value:)` |
| Indeterminate (progress) | `ProgressView()` (spinner) |

### 7.4 Lists, tables, sidebar items (8)

| Component | Build in SwiftUI with |
|---|---|
| Item | `List` row / `Label` |
| Folder | `List` row with disclosure |
| Section Header | `Section { } header: { }` |
| Group Title | `Section` header text |
| List Item / Primary Column | `Table` column / `List` row |
| List Item / Secondary Column | `Table` secondary column |
| Column Header | `TableColumn` header |
| Example | sidebar example row |

### 7.5 Menus (4)

| Component | Build in SwiftUI with |
|---|---|
| Menu | `Menu` / `.contextMenu` |
| Menu Bar | `.commands { }` / `CommandMenu` |
| Separator | `Divider()` / `Menu` divider |
| Header | menu section header |

### 7.6 Windows and chrome (11)

| Component | Build in SwiftUI with |
|---|---|
| Window | `WindowGroup` / `Window` scene |
| Window Controls/Standard | system traffic lights (automatic) |
| Window Controls/Utility | utility-window controls |
| Standard Window/Title Bar | `.toolbar` + title |
| Window Title/Standard | `.navigationTitle` |
| Window Title/Utility | utility window title |
| Utility Panel | `.windowStyle` utility / inspector |
| Utility Panel/Title Bar | panel title bar |
| Utility Panel/Tabs | `TabView` in a panel |
| Scrollbar - Vertical | `ScrollView` (system scrollers) |
| Scrollbar - Horizontal | `ScrollView(.horizontal)` |

### 7.7 Overlays and notifications (4)

| Component | Build in SwiftUI with |
|---|---|
| Sheet | `.sheet(isPresented:)` |
| Alert | `.alert(...)` |
| Popover | `.popover(...)` |
| Notification | `UNUserNotificationCenter` (system) |

### 7.8 System and desktop (3)

| Component | Build in SwiftUI with |
|---|---|
| Desktop Template | design mock only (not app code) |
| Desktop Wallpaper | design mock only |
| Pointers (cursors) | `.pointerStyle(...)` / `NSCursor` |

### 7.9 Known in kit, not resolved via MCP (~10 of 71)

Present in the macOS 26 Assets panel but the MCP keyword search did not return
them. Build with the listed SwiftUI primitive when needed.

- Toolbar -> `.toolbar { ToolbarItem { } }`
- Tab View -> `TabView`
- Sidebar (container) -> `NavigationSplitView` sidebar column
- Date Picker -> `DatePicker`
- Level Indicator -> custom / `Gauge`
- Path Control -> custom breadcrumb
- Token Field -> custom token list
- Box / Group Box -> `GroupBox`
- Disclosure Triangle -> `DisclosureGroup`
- Tooltip / Help Tag -> `.help("...")`

To resolve these precisely, drag one instance of each onto the Figma canvas and
re-run extraction (see section 9).

---

## 8. Applying the system to BroPrompter

```
+--------------------------------------------------------------+
|  Standard title bar  [ traffic lights ]      [ toolbar ... ]  |  <- .toolbar
+----------------+---------------------------------------------+
|                |                                             |
|  Sidebar       |   Teleprompter canvas                       |
|  (Scripts)     |   - camera preview (full-bleed)             |
|                |   - scrolling text (24-120pt, user size)    |
|  NavigationSplitView  - focus line / reading guide          |
|  sidebar       |                                             |
|                |   +-------------------------------------+   |
|  List + Section|   |  Transport (one GlassEffectContainer)|  |
|  Item / Folder |   |  [<<] [ Record ] [ Play/Pause ] [>>] |  |
|                |   +-------------------------------------+   |
+----------------+---------------------------------------------+
```

Screen-by-screen tokens:

- Shell: `NavigationSplitView` (sidebar + detail). Sidebar uses `List` with
  `Section` + `Item` rows, vibrant `.sidebar` material.
- Script library: `List`, `Section` headers, `.searchable` in the toolbar,
  swipe / context-menu actions via `Menu`.
- Editor: `TextEditor` with `.body` chrome and a large preview of teleprompter
  type.
- Teleprompter canvas: camera preview as full-bleed background; scrolling text
  in user-sized `Font.system(size:)`; focus line as a thin `.separator` or
  accent overlay; controls float in a `GlassEffectContainer` over
  `Glass.clear` so the video reads through.
- Recording state: `record.circle` / transport in `.glassProminent` tinted
  `.red`; level meter as `ProgressView` or `Gauge`; countdown in large
  `.largeTitle` monospaced digits.
- Settings: `Form` with `Toggle (.switch)`, `Picker`, `Slider`,
  `.controlSize(.regular)`; keyboard shortcuts via `.keyboardShortcut`.
- Recordings browser: `Table` (name, duration, date columns); preview popover;
  `.alert` for delete; `square.and.arrow.up` share.

Rules of thumb:
- Chrome type = semantic tokens (`.body`, `.headline`). Teleprompter type =
  large user-bound size.
- One glass layer per floating cluster; never glass-on-glass.
- Status color only (`.red` recording, `.green` ready); brand via accent +
  content.
- Respect dark mode and the user's accent automatically by using semantic
  tokens.

---

## 9. Provenance and how to refresh

What was extracted and how:

- Library identified via Figma MCP `get_libraries` on the file:
  `macOS 26` (Apple Design Resources), 71 components.
- Components enumerated via `search_design_system` scoped to the library key.
  The MCP search is keyword-based and returns small batches; 61 of 71 component
  sets were resolved by name + component key. Styles and variables are not
  surfaced by the MCP for this community library, so color / type / material
  values come from Apple's macOS HIG token system, mapped to SwiftUI / AppKit.
- macOS type reference sizes and Liquid Glass API surface verified against Apple
  HIG and current macOS 26 references (June 2026).

To get exact, file-true token values and the last ~10 components:

1. In the Figma file, drag one instance of each desired component / style onto
   Page 1 (or paste a sample frame from the kit's example pages).
2. Re-run extraction with the MCP: `get_variable_defs` and `get_design_context`
   on the placed nodes return real hex, type, spacing, and material values.
3. Update sections 2-7 with the resolved values.

Until then, treat the token tables as the semantic contract (correct API names
and adaptive behavior) and the reference numbers as documented macOS defaults.
