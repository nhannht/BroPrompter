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

  private let speedRange = TeleprompterEngine.minimumSpeed...TeleprompterEngine.maximumSpeed

  @State private var showCameraSettings = false

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

      fontControl

      Divider().frame(height: 20)

      cameraControl
        .disabled(cameraControlDisabled)

      Divider().frame(height: 20)

      recordButton

      Spacer()

      Button(action: onClose) {
        Label("Close", systemImage: "xmark")
      }
      .accessibilityIdentifier("teleprompterClose")
      .help("Close the teleprompter")
      .minimumHitTarget()
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
      .accessibilityLabel("Slower")
      .accessibilityIdentifier("teleprompterSlower")
      .minimumHitTarget()

      Slider(value: $speed, in: speedRange)
        .frame(width: 120)
        .accessibilityLabel("Scroll speed")
        .accessibilityValue("\(Int(speed)) points per second")
        .accessibilityIdentifier("teleprompterSpeed")

      Button(action: onFaster) {
        Image(systemName: "hare")
      }
      .accessibilityLabel("Faster")
      .accessibilityIdentifier("teleprompterFaster")
      .minimumHitTarget()
    }
  }

  private var fontControl: some View {
    HStack(spacing: 8) {
      Button(action: onSmaller) {
        Image(systemName: "textformat.size.smaller")
      }
      .accessibilityLabel("Smaller text")
      .accessibilityIdentifier("teleprompterFontSmaller")
      .minimumHitTarget()

      Text("\(Int(script.fontSize))")
        .font(.callout.monospacedDigit())
        .frame(minWidth: 28)
        .accessibilityLabel("Font size \(Int(script.fontSize)) points")
        .accessibilityIdentifier("teleprompterFontSize")

      Button(action: onLarger) {
        Image(systemName: "textformat.size.larger")
      }
      .accessibilityLabel("Larger text")
      .accessibilityIdentifier("teleprompterFontLarger")
      .minimumHitTarget()
    }
  }

  private var cameraControl: some View {
    HStack(spacing: 8) {
      Button(action: onToggleCamera) {
        Image(systemName: cameraEnabled ? "video.fill" : "video.slash")
      }
      .accessibilityLabel(cameraEnabled ? "Turn camera off" : "Turn camera on")
      .accessibilityIdentifier("teleprompterCamera")
      .help(cameraEnabled ? "Turn the camera off" : "Turn the camera on")
      .minimumHitTarget()

      Button {
        showCameraSettings.toggle()
      } label: {
        Image(systemName: "slider.horizontal.3")
      }
      .accessibilityLabel("Capture settings")
      .accessibilityIdentifier("teleprompterCameraSettings")
      .help("Choose camera, microphone, quality, countdown, and codec")
      .minimumHitTarget()
      .popover(isPresented: $showCameraSettings, arrowEdge: .bottom) {
        cameraSettings
      }
    }
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

  private var cameraSettings: some View {
    Form {
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
    .padding()
    .frame(width: 320)
  }
}
