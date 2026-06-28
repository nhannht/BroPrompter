import SwiftUI

// MARK: - TeleprompterControls

/// The floating transport for the teleprompter (BROP-4, BROP-47, BROP-53): a
/// compact, evenly spaced glass pill matching the prototype (4335:14431) -
/// restart, play/pause, a centered record button, a speed stepper, and an
/// overflow menu for the remaining options. Camera, microphone, and capture
/// defaults live in the Settings window (reachable from the menu); every action
/// is also a Playback-menu command with a keyboard shortcut (GUIDELINES.md 4, 5).
/// Presentation only: all side effects run through the closures the reader passes.
struct TeleprompterControls: View {

  // MARK: Internal

  let engine: TeleprompterEngine

  let isCapturing: Bool
  let recordDisabled: Bool
  @Binding var mirrorText: Bool
  @Binding var cameraMirrored: Bool

  let onRestart: () -> Void
  let onTogglePlay: () -> Void
  let onSlower: () -> Void
  let onFaster: () -> Void
  let onSmaller: () -> Void
  let onLarger: () -> Void
  let onToggleRecord: () -> Void
  let onClose: () -> Void

  var body: some View {
    transportRow
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .controlSize(.large)
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .glassEffect(.regular, in: .capsule)
      .padding()
  }

  // MARK: Private

  /// Evenly spaced so the pill stays compact and balanced, with the record button
  /// at the visual center: three controls on the leading side (restart, play,
  /// more) mirror the speed stepper's three parts on the trailing side (BROP-54).
  private var transportRow: some View {
    HStack(spacing: 22) {
      restartButton
      playButton
      moreMenu
      recordButton
      speedControl
    }
  }

  private var restartButton: some View {
    Button(action: onRestart) {
      Label("Restart", systemImage: "gobackward")
    }
    .accessibilityIdentifier("teleprompterRestart")
    .help("Restart from the top")
    .minimumHitTarget()
  }

  private var playButton: some View {
    Button(action: onTogglePlay) {
      Label(
        engine.isPlaying ? "Pause" : "Play",
        systemImage: engine.isPlaying ? "pause.fill" : "play.fill"
      )
    }
    .accessibilityIdentifier("teleprompterPlayPause")
    .help(engine.isPlaying ? "Pause" : "Play")
    .minimumHitTarget()
  }

  /// Speed shown as a multiplier of the default scroll speed, matching the
  /// prototype's "- 1.0x +". Display only: the engine stays in points/second and
  /// the buttons reuse the reader's slower/faster nudges.
  private var speedControl: some View {
    HStack(spacing: 8) {
      Button(action: onSlower) {
        Image(systemName: "minus")
      }
      .accessibilityLabel("Slower")
      .accessibilityIdentifier("teleprompterSlower")
      .minimumHitTarget()

      Text(speedLabel)
        .font(.callout.monospacedDigit())
        .frame(minWidth: 40)
        .accessibilityLabel("Scroll speed")
        .accessibilityValue(speedLabel)
        .accessibilityIdentifier("teleprompterSpeed")

      Button(action: onFaster) {
        Image(systemName: "plus")
      }
      .accessibilityLabel("Faster")
      .accessibilityIdentifier("teleprompterFaster")
      .minimumHitTarget()
    }
  }

  private var speedLabel: String {
    String(format: "%.1fx", engine.speed / Preferences.defaultScrollSpeed)
  }

  /// The primary action: a prominent solid-red circular button (prototype
  /// 4335:14431). A white record ring idle, a white stop-square while recording.
  private var recordButton: some View {
    Button(action: onToggleRecord) {
      ZStack {
        Circle()
          .fill(.red)
          .frame(width: 36, height: 36)
        if isCapturing {
          RoundedRectangle(cornerRadius: 4)
            .fill(.white)
            .frame(width: 13, height: 13)
        } else {
          Circle()
            .strokeBorder(.white.opacity(0.9), lineWidth: 2.5)
            .frame(width: 26, height: 26)
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(recordDisabled)
    .accessibilityLabel(isCapturing ? "Stop recording" : "Start recording")
    .accessibilityIdentifier("teleprompterRecord")
    .help(isCapturing ? "Stop recording" : "Start recording (saves to Recordings)")
    .minimumHitTarget()
  }

  /// The remaining options, kept off the pill so the transport stays minimal
  /// (BROP-53): live text size, text and camera mirroring, the Settings window
  /// (camera, microphone, quality, codec), and exit.
  private var moreMenu: some View {
    Menu {
      Button("Larger Text", systemImage: "textformat.size.larger", action: onLarger)
      Button("Smaller Text", systemImage: "textformat.size.smaller", action: onSmaller)
      Toggle("Mirror Text (Beam Splitter)", isOn: $mirrorText)
      Toggle("Mirror Camera (Self-View)", isOn: $cameraMirrored)
      Divider()
      SettingsLink {
        Label("Settings…", systemImage: "gearshape")
      }
      Button("Exit Teleprompter", systemImage: "xmark", action: onClose)
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .menuIndicator(.hidden)
    .accessibilityLabel("More options")
    .accessibilityIdentifier("teleprompterMore")
    .help("Text size, mirror, settings, and exit")
    .minimumHitTarget()
  }
}
