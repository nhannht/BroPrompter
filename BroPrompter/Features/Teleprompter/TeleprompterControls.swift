import SwiftUI

// MARK: - TeleprompterControls

/// The floating transport for the teleprompter (BROP-4): restart, play/pause,
/// live speed and font-size controls, a progress bar with elapsed and remaining
/// time, and a close button. Every control carries a VoiceOver label, an
/// accessibility identifier, and a keyboard shortcut so the surface is fully
/// keyboard-operable (GUIDELINES.md sections 4 and 5). The view is presentation
/// only: all side effects run through the closures the reader passes in.
struct TeleprompterControls: View {

  // MARK: Internal

  @Bindable var script: Script

  let engine: TeleprompterEngine
  @Binding var speed: Double

  let onRestart: () -> Void
  let onTogglePlay: () -> Void
  let onSlower: () -> Void
  let onFaster: () -> Void
  let onSmaller: () -> Void
  let onLarger: () -> Void
  let onClose: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      progressRow
      transportRow
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.bar, in: .rect(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(Color(nsColor: .separatorColor))
    )
    .frame(maxWidth: 720)
    .padding()
  }

  // MARK: Private

  private let speedRange = TeleprompterEngine.minimumSpeed...300

  private var progressRow: some View {
    HStack(spacing: 12) {
      Text(TeleprompterEngine.clockString(engine.elapsed))
        .accessibilityLabel("Elapsed time")
        .accessibilityIdentifier("teleprompterElapsed")
      ProgressView(value: engine.progress)
        .accessibilityLabel("Reading progress")
        .accessibilityIdentifier("teleprompterProgress")
      Text("-" + TeleprompterEngine.clockString(engine.remaining))
        .accessibilityLabel("Remaining time")
        .accessibilityIdentifier("teleprompterRemaining")
    }
    .font(.caption.monospacedDigit())
    .foregroundStyle(.secondary)
  }

  private var transportRow: some View {
    HStack(spacing: 16) {
      Button(action: onRestart) {
        Label("Restart", systemImage: "gobackward")
      }
      .accessibilityIdentifier("teleprompterRestart")
      .help("Restart from the top")

      Button(action: onTogglePlay) {
        Label(
          engine.isPlaying ? "Pause" : "Play",
          systemImage: engine.isPlaying ? "pause.fill" : "play.fill"
        )
      }
      .keyboardShortcut(.space, modifiers: [])
      .accessibilityIdentifier("teleprompterPlayPause")
      .help(engine.isPlaying ? "Pause" : "Play")

      Divider().frame(height: 20)

      speedControl

      Divider().frame(height: 20)

      fontControl

      Spacer()

      Button(action: onClose) {
        Label("Close", systemImage: "xmark")
      }
      .accessibilityIdentifier("teleprompterClose")
      .help("Close the teleprompter")
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.borderless)
    .controlSize(.large)
  }

  private var speedControl: some View {
    HStack(spacing: 8) {
      Button(action: onSlower) {
        Image(systemName: "tortoise")
      }
      .keyboardShortcut("-", modifiers: [])
      .accessibilityLabel("Slower")
      .accessibilityIdentifier("teleprompterSlower")

      Slider(value: $speed, in: speedRange)
        .frame(width: 120)
        .accessibilityLabel("Scroll speed")
        .accessibilityIdentifier("teleprompterSpeed")

      Button(action: onFaster) {
        Image(systemName: "hare")
      }
      .keyboardShortcut("+", modifiers: [])
      .accessibilityLabel("Faster")
      .accessibilityIdentifier("teleprompterFaster")
    }
  }

  private var fontControl: some View {
    HStack(spacing: 8) {
      Button(action: onSmaller) {
        Image(systemName: "textformat.size.smaller")
      }
      .keyboardShortcut("-", modifiers: .command)
      .accessibilityLabel("Smaller text")
      .accessibilityIdentifier("teleprompterFontSmaller")

      Text("\(Int(script.fontSize))")
        .font(.callout.monospacedDigit())
        .frame(minWidth: 28)
        .accessibilityLabel("Font size \(Int(script.fontSize)) points")
        .accessibilityIdentifier("teleprompterFontSize")

      Button(action: onLarger) {
        Image(systemName: "textformat.size.larger")
      }
      .keyboardShortcut("+", modifiers: .command)
      .accessibilityLabel("Larger text")
      .accessibilityIdentifier("teleprompterFontLarger")
    }
  }
}
