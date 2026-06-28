import SwiftUI

// MARK: - TeleprompterControls

/// The floating transport for the teleprompter (BROP-4, BROP-47): a compact pill
/// matching the prototype (07 4335:14397) - restart, play/pause, a speed
/// multiplier, the camera toggle, the record button, an overflow menu for text
/// size and capture settings, and close. Every control carries a VoiceOver label,
/// an accessibility identifier, and (through the Playback menu) a keyboard
/// shortcut, so the surface is fully keyboard-operable (GUIDELINES.md 4 and 5).
/// The view is presentation only: all side effects run through the closures the
/// reader passes in.
struct TeleprompterControls: View {

  // MARK: Internal

  let engine: TeleprompterEngine

  let cameraEnabled: Bool
  let cameras: [CaptureDevice]
  let microphones: [CaptureDevice]
  let qualities: [CaptureQuality]
  @Binding var selectedCameraID: String
  @Binding var selectedMicID: String
  @Binding var selectedQuality: CaptureQuality
  @Binding var selectedCountdown: Int
  @Binding var selectedCodec: VideoCodec

  let isCapturing: Bool
  let recordDisabled: Bool
  let cameraControlDisabled: Bool

  let onRestart: () -> Void
  let onTogglePlay: () -> Void
  let onSlower: () -> Void
  let onFaster: () -> Void
  let onSmaller: () -> Void
  let onLarger: () -> Void
  let onToggleCamera: () -> Void
  let onToggleRecord: () -> Void
  let onClose: () -> Void

  var body: some View {
    transportRow
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .controlSize(.large)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(.bar, in: .capsule)
      .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor)))
      .padding()
  }

  // MARK: Private

  private var transportRow: some View {
    HStack(spacing: 16) {
      Button(action: onRestart) {
        Label("Restart", systemImage: "gobackward")
      }
      .accessibilityIdentifier("teleprompterRestart")
      .help("Restart from the top")
      .minimumHitTarget()

      Button(action: onTogglePlay) {
        Label(
          engine.isPlaying ? "Pause" : "Play",
          systemImage: engine.isPlaying ? "pause.fill" : "play.fill"
        )
      }
      .accessibilityIdentifier("teleprompterPlayPause")
      .help(engine.isPlaying ? "Pause" : "Play")
      .minimumHitTarget()

      Divider().frame(height: 20)

      speedControl

      Divider().frame(height: 20)

      cameraButton
        .disabled(cameraControlDisabled)

      recordButton

      Divider().frame(height: 20)

      overflowMenu

      Button(action: onClose) {
        Label("Close", systemImage: "xmark")
      }
      .accessibilityIdentifier("teleprompterClose")
      .help("Close the teleprompter")
      .minimumHitTarget()
    }
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

  private var cameraButton: some View {
    Button(action: onToggleCamera) {
      Image(systemName: cameraEnabled ? "video.fill" : "video.slash")
    }
    .accessibilityLabel(cameraEnabled ? "Turn camera off" : "Turn camera on")
    .accessibilityIdentifier("teleprompterCamera")
    .help(cameraEnabled ? "Turn the camera off" : "Turn the camera on")
    .minimumHitTarget()
  }

  private var recordButton: some View {
    Button(action: onToggleRecord) {
      Image(systemName: isCapturing ? "stop.circle.fill" : "record.circle")
    }
    .tint(.red)
    .disabled(recordDisabled)
    .accessibilityLabel(isCapturing ? "Stop recording" : "Start recording")
    .accessibilityIdentifier("teleprompterRecord")
    .help(isCapturing ? "Stop recording" : "Start recording")
    .minimumHitTarget()
  }

  /// Text size and capture settings, kept out of the inline pill so it stays
  /// compact (BROP-47). The camera toggle and record button stay inline for
  /// discoverability (BROP-43).
  private var overflowMenu: some View {
    Menu {
      Button("Larger Text", systemImage: "textformat.size.larger", action: onLarger)
      Button("Smaller Text", systemImage: "textformat.size.smaller", action: onSmaller)
      Section("Capture") {
        Picker("Camera", selection: $selectedCameraID) {
          Text("System Default").tag("")
          ForEach(cameras) { Text($0.name).tag($0.id) }
        }
        .accessibilityIdentifier("teleprompterCameraPicker")

        Picker("Microphone", selection: $selectedMicID) {
          Text("System Default").tag("")
          ForEach(microphones) { Text($0.name).tag($0.id) }
        }
        .accessibilityIdentifier("teleprompterMicPicker")

        Picker("Quality", selection: $selectedQuality) {
          ForEach(qualities) { Text($0.displayName).tag($0) }
        }
        .accessibilityIdentifier("teleprompterQualityPicker")

        Picker("Countdown", selection: $selectedCountdown) {
          Text("Off").tag(0)
          Text("3s").tag(3)
          Text("5s").tag(5)
        }
        .accessibilityIdentifier("teleprompterCountdownPicker")

        Picker("Codec", selection: $selectedCodec) {
          ForEach(VideoCodec.allCases) { Text($0.displayName).tag($0) }
        }
        .accessibilityIdentifier("teleprompterCodecPicker")
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .menuIndicator(.hidden)
    .accessibilityLabel("More controls")
    .accessibilityIdentifier("teleprompterMore")
    .help("Text size and capture settings")
    .minimumHitTarget()
  }
}
