import SwiftUI

// MARK: - SettingsView

/// The app's Settings window, opened with Cmd-, (GUIDELINES.md 5.3). A native
/// `TabView` in the `Settings` scene, matching the prototype (H7, 4344:14661):
/// General / Reading / Recording / Shortcuts. Every preference binds an
/// `@AppStorage` key from `Preferences`, the same keys the teleprompter reads, so
/// the two stay in sync. The native tab selection carries a non-color selected
/// state, satisfying the BROP-23 "tab selection is color-only" finding.
struct SettingsView: View {
  var body: some View {
    TabView {
      GeneralSettingsTab()
        .tabItem { Label("General", systemImage: "gearshape") }
      ReadingSettingsTab()
        .tabItem { Label("Reading", systemImage: "textformat.size") }
      RecordingSettingsTab()
        .tabItem { Label("Recording", systemImage: "record.circle") }
      ShortcutsSettingsTab()
        .tabItem { Label("Shortcuts", systemImage: "list.bullet") }
    }
  }
}

// MARK: - GeneralSettingsTab

/// Countdown, reading pace, beam-splitter mirror, and default capture quality.
private struct GeneralSettingsTab: View {

  // MARK: Internal

  var body: some View {
    Form {
      Picker("Countdown before recording", selection: $countdown) {
        Text("Off").tag(0)
        Text("3 seconds").tag(3)
        Text("5 seconds").tag(5)
      }

      LabeledContent("Reading speed") {
        HStack(spacing: 12) {
          Slider(value: wpmBinding, in: 80 ... 300, step: 5)
          Text("\(wordsPerMinute) wpm")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 72, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading speed")
        .accessibilityValue("\(wordsPerMinute) words per minute")
      }

      Toggle("Mirror text (beam splitter)", isOn: $mirrorText)

      Picker("Default video quality", selection: $cameraQualityRaw) {
        ForEach(CaptureQuality.allCases) { Text($0.displayName).tag($0.rawValue) }
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 300)
  }

  // MARK: Private

  @AppStorage(Preferences.Key.countdown) private var countdown = Preferences.Default.countdown
  @AppStorage(Preferences.Key.readingWordsPerMinute) private var wordsPerMinute = Preferences.Default.readingWordsPerMinute
  @AppStorage(Preferences.Key.mirrorText) private var mirrorText = Preferences.Default.mirrorText
  @AppStorage(Preferences.Key.cameraQuality) private var cameraQualityRaw = Preferences.Default.cameraQualityRaw

  private var wpmBinding: Binding<Double> {
    Binding(
      get: { Double(wordsPerMinute) },
      set: { wordsPerMinute = Int($0) }
    )
  }
}

// MARK: - ReadingSettingsTab

/// Defaults applied to new scripts (font size, scroll speed) plus the global
/// reading-column width. Font size and speed are per-script, so these seed new
/// scripts; both can still be adjusted live while reading.
private struct ReadingSettingsTab: View {

  // MARK: Internal

  var body: some View {
    Form {
      LabeledContent("Default font size") {
        HStack(spacing: 12) {
          Slider(value: $defaultFontSize, in: 24 ... 120, step: 1)
          Text("\(Int(defaultFontSize)) pt")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 72, alignment: .trailing)
        }
        .accessibilityValue("\(Int(defaultFontSize)) points")
      }

      LabeledContent("Default scroll speed") {
        HStack(spacing: 12) {
          Slider(value: $defaultScrollSpeed, in: TeleprompterEngine.minimumSpeed ... 300, step: 5)
          Text("\(Int(defaultScrollSpeed)) pt/s")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 72, alignment: .trailing)
        }
        .accessibilityValue("\(Int(defaultScrollSpeed)) points per second")
      }

      LabeledContent("Reading column width") {
        HStack(spacing: 12) {
          Slider(value: $lineWidthFraction, in: 0.4 ... 1.0, step: 0.05)
          Text("\(Int(lineWidthFraction * 100))%")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 72, alignment: .trailing)
        }
        .accessibilityValue("\(Int(lineWidthFraction * 100)) percent")
      }

      Text("Font size and speed apply to new scripts and can be changed live while reading.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 320)
  }

  // MARK: Private

  @AppStorage(Preferences.Key.defaultFontSize) private var defaultFontSize = Preferences.Default.fontSize
  @AppStorage(Preferences.Key.defaultScrollSpeed) private var defaultScrollSpeed = Preferences.Default.scrollSpeed
  @AppStorage(Preferences.Key.lineWidthFraction) private var lineWidthFraction = Preferences.Default.lineWidthFraction
}

// MARK: - RecordingSettingsTab

/// Default capture devices and codec. Devices are listed through a
/// `CaptureSessionManager` (enumeration only, no capture starts here).
private struct RecordingSettingsTab: View {

  // MARK: Internal

  var body: some View {
    Form {
      Picker("Default camera", selection: $cameraDeviceID) {
        Text("System Default").tag("")
        ForEach(session.availableCameras) { Text($0.name).tag($0.id) }
      }

      Picker("Default microphone", selection: $micDeviceID) {
        Text("System Default").tag("")
        ForEach(session.availableMicrophones) { Text($0.name).tag($0.id) }
      }

      Picker("Video codec", selection: $codecRaw) {
        ForEach(VideoCodec.allCases) { Text($0.displayName).tag($0.rawValue) }
      }

      Text("Used the next time you record. The teleprompter's capture menu can override these per session.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 280)
    .onAppear { session.refreshDevices() }
  }

  // MARK: Private

  @State private var session = CaptureSessionManager()

  @AppStorage(Preferences.Key.cameraDeviceID) private var cameraDeviceID = ""
  @AppStorage(Preferences.Key.micDeviceID) private var micDeviceID = ""
  @AppStorage(Preferences.Key.codec) private var codecRaw = Preferences.Default.codecRaw
}

// MARK: - ShortcutsSettingsTab

/// A read-only cheat-sheet of the app's keyboard shortcuts, so they are
/// discoverable from one place (GUIDELINES.md 5.1). Grouped by context.
private struct ShortcutsSettingsTab: View {

  // MARK: Internal

  var body: some View {
    Form {
      Section("Library") {
        ForEach(Self.libraryShortcuts, id: \.action) { shortcut in
          row(shortcut)
        }
      }
      Section("Teleprompter") {
        ForEach(Self.teleprompterShortcuts, id: \.action) { shortcut in
          row(shortcut)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 520)
  }

  // MARK: Private

  private static let libraryShortcuts: [(action: String, keys: String)] = [
    ("New Script", "⌘N"),
    ("Import Text File", "⇧⌘I"),
    ("Save", "⌘S"),
    ("Delete Script", "⌘⌫"),
    ("Play in Teleprompter", "⌘↩"),
    ("Go to Library", "⇧⌘L"),
    ("Go to Recordings", "⇧⌘R"),
    ("Settings", "⌘,"),
  ]

  private static let teleprompterShortcuts: [(action: String, keys: String)] = [
    ("Play / Pause", "Space"),
    ("Slower / Faster", "- / +"),
    ("Smaller / Larger text", "⌘- / ⌘+"),
    ("Scrub line", "↑ / ↓"),
    ("Page back / forward", "← / →"),
    ("Enter / exit full screen", "⌘↩"),
    ("Toggle camera", "C"),
    ("Record / Stop", "R"),
    ("Exit (leaves full screen first)", "Esc"),
  ]

  private func row(_ shortcut: (action: String, keys: String)) -> some View {
    LabeledContent(shortcut.action) {
      Text(shortcut.keys)
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(shortcut.action), \(shortcut.keys)")
  }
}
