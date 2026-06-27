import AppKit
import AVFoundation
import SwiftData
import SwiftUI

// MARK: - TeleprompterView

/// The teleprompter reading surface (BROP-4), shown in its own window so it can
/// go full screen (GUIDELINES.md section 3). Looks the script up by id from the
/// shared store; the scrolling itself lives in `TeleprompterReader`.
struct TeleprompterView: View {

  // MARK: Lifecycle

  init(scriptID: UUID?) {
    if let scriptID {
      _scripts = Query(filter: #Predicate<Script> { $0.id == scriptID })
    } else {
      _scripts = Query(filter: #Predicate<Script> { _ in false })
    }
  }

  // MARK: Internal

  var body: some View {
    if let script = scripts.first {
      TeleprompterReader(script: script)
    } else {
      ContentUnavailableView(
        "Script Not Found",
        systemImage: "doc.text",
        description: Text("This script may have been deleted.")
      )
    }
  }

  // MARK: Private

  @Query private var scripts: [Script]
}

// MARK: - TeleprompterReader

/// Scrolls one script's body upward at the engine's pace, with a fixed focus
/// line the reader's eye tracks. The body is inset top and bottom so the first
/// and last lines can each reach the focus line. The transport auto-hides while
/// playing and reveals on pointer move or key press; play/pause, speed, font,
/// scrub, and exit are all reachable from the keyboard.
private struct TeleprompterReader: View {

  // MARK: Internal

  @Bindable var script: Script

  var body: some View {
    GeometryReader { proxy in
      let focusY = proxy.size.height * Self.focusFraction
      ZStack(alignment: .top) {
        cameraBackground
          .ignoresSafeArea()

        if isCameraActive {
          contrastScrim
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }

        scrollingText(viewport: proxy.size, focusY: focusY)
          .offset(y: -engine.offset)

        focusLine(width: proxy.size.width, y: focusY)

        // Invisible animation driver: advances the engine once per frame while
        // playing, then stops ticking when paused.
        TimelineView(.animation(paused: !engine.isPlaying)) { context in
          Color.clear
            .onChange(of: context.date) { _, date in engine.tick(date) }
        }
        .allowsHitTesting(false)

        // Recording driver: ticks the count-in and elapsed clock and samples the
        // audio meter while a take is counting in or recording.
        TimelineView(.animation(paused: !recorder.isActive)) { context in
          Color.clear
            .onChange(of: context.date) { _, date in advanceRecorder(date) }
        }
        .allowsHitTesting(false)

        // Tap toggles play/pause and drag scrubs. Kept as its own layer below
        // the transport overlay so the controls stay hittable (an equivalent
        // gesture on the container made the buttons report non-hittable).
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { togglePlay() }
          .gesture(scrubGesture)
          .accessibilityHidden(true)
      }
      .overlay {
        RecordingOverlay(
          recorder: recorder,
          mode: recordingMode,
          savedTakeURL: savedTakeURL,
          onDismissSaved: { savedTakeURL = nil }
        )
      }
      .overlay(alignment: .bottom) { controls }
      .background(WindowReader { window in
        windowBox.window = window
        // A just-opened teleprompter should be the key, frontmost window so its
        // controls and shortcuts respond on the first interaction.
        guard !didActivateWindow, let window else { return }
        didActivateWindow = true
        window.makeKeyAndOrderFront(nil)
      })
      .focusable()
      .focusEffectDisabled()
      .focused($isFocused)
      .onKeyPress(.upArrow) { scrub(by: -lineStep) }
      .onKeyPress(.downArrow) { scrub(by: lineStep) }
      .onExitCommand {
        // While recording, Esc stops the take instead of closing, so a take is
        // never lost to an accidental exit (GUIDELINES.md 2.2).
        if recorder.isCapturing {
          stopRecording()
        } else {
          dismiss()
        }
      }
      .onContinuousHover { phase in
        if case .active = phase { revealControls() }
      }
      .onChange(of: engine.isPlaying) { _, playing in
        playing ? scheduleHide() : revealControls()
      }
      .onChange(of: cameraEnabled) { _, _ in syncCamera() }
      .onChange(of: cameraDeviceID) { _, _ in
        guard isCameraAuthorizedAndEnabled else { return }
        session.selectCamera(id: selectedCameraID, quality: cameraQuality)
      }
      .onChange(of: cameraQualityRaw) { _, _ in
        guard isCameraAuthorizedAndEnabled else { return }
        session.updateQuality(cameraQuality, cameraID: selectedCameraID)
      }
      .onChange(of: recorder.phase) { old, new in
        if new == .recording, old != .paused { beginFileRecording() }
      }
      .onChange(of: countdownLength) { _, length in recorder.countdownLength = length }
      .onAppear {
        viewportHeight = proxy.size.height
        engine.speed = script.scrollSpeed
        updateMaxOffset()
        isFocused = true
        installScrollMonitor()
        session.refreshDevices()
        recorder.countdownLength = countdownLength
        syncCamera()
      }
      .onChange(of: proxy.size.height) { _, newHeight in
        viewportHeight = newHeight
        updateMaxOffset()
      }
      .onDisappear {
        removeScrollMonitor()
        if recorder.isCapturing {
          finalizeOnClose()
        } else {
          session.stop()
        }
      }
      .task(id: savedTakeURL) {
        guard savedTakeURL != nil else { return }
        try? await Task.sleep(for: .seconds(5))
        savedTakeURL = nil
      }
      .sheet(item: $permissionRequest) { request in
        permissionSheet(request)
      }
    }
  }

  // MARK: Private

  /// Vertical position of the focus line as a fraction of the viewport height,
  /// near the top third where the reader's eyeline sits (GUIDELINES.md 2.3).
  private static let focusFraction = 0.4
  private static let speedStep = 10.0
  private static let fontStep = 2.0
  private static let fontRange = 24.0...120.0

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(PermissionManager.self) private var permissions

  @State private var engine = TeleprompterEngine()
  @State private var session = CaptureSessionManager()
  @State private var recorder = RecorderController()
  @State private var audioRecorder = AudioTakeRecorder()
  @State private var recordingMode = TakeMode.video
  @State private var savedTakeURL: URL?
  @State private var viewportHeight = 0.0
  @State private var contentHeight = 0.0
  @State private var lastDragHeight = 0.0
  @State private var showControls = true
  @State private var hideTask: Task<Void, Never>?
  @State private var windowBox = WindowBox()
  @State private var scrollMonitor: Any?
  @State private var didActivateWindow = false
  @State private var permissionRequest: PermissionRequest?

  @FocusState private var isFocused: Bool

  /// Global reading-column width as a fraction of the viewport (DESIGN.md: line
  /// width is a display preference, not a per-script attribute).
  @AppStorage("teleprompter.lineWidthFraction") private var lineWidthFraction = 0.8

  /// Camera background preferences, global like the line width (a capture
  /// environment choice, not a per-script attribute). The mic id is selected
  /// here but consumed only when recording starts (P4 / BROP-6).
  @AppStorage("camera.enabled") private var cameraEnabled = false
  @AppStorage("camera.deviceID") private var cameraDeviceID = ""
  @AppStorage("camera.micID") private var micDeviceID = ""
  @AppStorage("camera.quality") private var cameraQualityRaw = CaptureQuality.preferred.rawValue

  /// Recording preferences, global like the camera settings. Countdown length in
  /// seconds (0 disables); video codec for video takes.
  @AppStorage("recording.countdown") private var countdownLength = 3
  @AppStorage("recording.codec") private var videoCodecRaw = VideoCodec.hevc.rawValue

  /// One line's worth of scroll, used for arrow-key scrub steps.
  private var lineStep: Double {
    script.fontSize * 1.4
  }

  /// Drag to scrub the scroll manually; dragging up advances the script.
  private var scrubGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        engine.scrub(by: lastDragHeight - value.translation.height)
        lastDragHeight = value.translation.height
        revealControls()
      }
      .onEnded { _ in lastDragHeight = 0 }
  }

  private var controls: some View {
    TeleprompterControls(
      script: script,
      engine: engine,
      speed: speedBinding,
      cameraEnabled: cameraEnabled,
      cameras: session.availableCameras,
      microphones: session.availableMicrophones,
      qualities: qualityOptions,
      selectedCameraID: $cameraDeviceID,
      selectedMicID: $micDeviceID,
      selectedQuality: qualityBinding,
      selectedCountdown: $countdownLength,
      selectedCodec: codecBinding,
      isCapturing: recorder.isCapturing,
      recordDisabled: recorder.phase == .finalizing,
      cameraControlDisabled: recorder.isCapturing || recorder.phase == .countingIn,
      onRestart: { engine.restart()
        revealControls()
      },
      onTogglePlay: togglePlay,
      onSlower: { changeSpeed(by: -Self.speedStep) },
      onFaster: { changeSpeed(by: Self.speedStep) },
      onSmaller: { changeFont(by: -Self.fontStep) },
      onLarger: { changeFont(by: Self.fontStep) },
      onToggleCamera: toggleCamera,
      onToggleRecord: toggleRecord,
      onClose: { dismiss() }
    )
    .opacity(showControls ? 1 : 0)
    .allowsHitTesting(showControls)
  }

  private var speedBinding: Binding<Double> {
    Binding(
      get: { engine.speed },
      set: { newValue in
        engine.speed = newValue
        script.scrollSpeed = newValue
      }
    )
  }

  /// Whether the live camera is currently feeding the background.
  private var isCameraActive: Bool {
    cameraEnabled && session.isRunning
  }

  /// Whether the camera is both enabled and authorized to run.
  private var isCameraAuthorizedAndEnabled: Bool {
    cameraEnabled && permissions.status(for: .camera) == .authorized
  }

  /// The selected camera quality, falling back to the default preset.
  private var cameraQuality: CaptureQuality {
    CaptureQuality(rawValue: cameraQualityRaw) ?? .preferred
  }

  /// The selected camera id, or `nil` to use the system default camera.
  private var selectedCameraID: String? {
    cameraDeviceID.isEmpty ? nil : cameraDeviceID
  }

  /// Bridges the raw stored quality to the picker's `CaptureQuality` selection.
  private var qualityBinding: Binding<CaptureQuality> {
    Binding(
      get: { cameraQuality },
      set: { cameraQualityRaw = $0.rawValue }
    )
  }

  /// Qualities the picker offers: those the selected camera supports, or the
  /// full list as a fallback before the camera has been queried (for example
  /// when access has not yet been granted).
  private var qualityOptions: [CaptureQuality] {
    let supported = session.supportedQualities(forCameraID: selectedCameraID)
    return supported.isEmpty ? CaptureQuality.allCases : supported
  }

  @ViewBuilder
  private var cameraBackground: some View {
    if isCameraActive {
      CameraPreviewView(session: session.session)
    } else {
      Color(nsColor: .textBackgroundColor)
    }
  }

  /// A soft dark veil concentrated around the focus line so the reading text
  /// clears contrast over any camera image (GUIDELINES.md 4 / 2.3).
  private var contrastScrim: some View {
    LinearGradient(
      stops: [
        .init(color: .black.opacity(0), location: 0),
        .init(color: .black.opacity(0.4), location: Self.focusFraction),
        .init(color: .black.opacity(0), location: 1),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  /// Reading text is high-contrast white over the camera (paired with the scrim
  /// and a shadow) and the semantic primary label color over the plain
  /// background. Over arbitrary video `.primary` cannot guarantee contrast, so
  /// the white treatment is the documented exception to semantic color
  /// (GUIDELINES.md 4).
  private var readingTextStyle: AnyShapeStyle {
    isCameraActive ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
  }

  /// The selected video codec, falling back to HEVC.
  private var videoCodec: VideoCodec {
    VideoCodec(rawValue: videoCodecRaw) ?? .hevc
  }

  /// The AVFoundation codec for the selected `videoCodec`.
  private var avCodec: AVVideoCodecType {
    videoCodec == .h264 ? .h264 : .hevc
  }

  /// Bridges the raw stored codec to the picker's `VideoCodec` selection.
  private var codecBinding: Binding<VideoCodec> {
    Binding(
      get: { videoCodec },
      set: { videoCodecRaw = $0.rawValue }
    )
  }

  /// The selected microphone id, or `nil` for the system default mic.
  private var selectedMicrophoneID: String? {
    micDeviceID.isEmpty ? nil : micDeviceID
  }

  /// Inserts a finished take into the shared store.
  private static func persistTake(url: URL, mode: TakeMode, duration: TimeInterval, scriptID: UUID) {
    let take = Take(scriptID: scriptID, mode: mode, fileName: url.lastPathComponent, duration: duration)
    let context = ScriptStore.container.mainContext
    context.insert(take)
    try? context.save()
  }

  /// Starts or stops the camera to match the stored preference and authorization.
  private func syncCamera() {
    if isCameraAuthorizedAndEnabled {
      session.start(cameraID: selectedCameraID, quality: cameraQuality)
    } else {
      session.stop()
    }
  }

  /// Turns the camera background on or off from the transport. Enabling routes
  /// through the in-context permission flow (GUIDELINES.md 1.1): an explainer
  /// before the first system prompt, and a recovery sheet to System Settings
  /// when access has been denied. Locked while a take is in progress so the mode
  /// cannot change mid-recording.
  private func toggleCamera() {
    guard !recorder.isCapturing, recorder.phase != .countingIn else { return }
    if cameraEnabled {
      cameraEnabled = false
    } else {
      requestCameraAndEnable()
    }
    revealControls()
  }

  private func requestCameraAndEnable() {
    switch permissions.status(for: .camera) {
    case .authorized:
      cameraEnabled = true

    case .notDetermined:
      permissionRequest = .cameraExplain

    default:
      permissionRequest = .cameraDenied
    }
  }

  /// Starts a take (count-in then recording) or stops one in progress. Recording
  /// always needs the microphone, so enabling routes through the in-context mic
  /// permission flow first.
  private func toggleRecord() {
    revealControls()
    if recorder.isCapturing || recorder.phase == .countingIn {
      stopRecording()
    } else {
      requestMicrophoneAndRecord()
    }
  }

  private func requestMicrophoneAndRecord() {
    switch permissions.status(for: .microphone) {
    case .authorized:
      recorder.start()

    case .notDetermined:
      permissionRequest = .microphoneExplain

    default:
      permissionRequest = .microphoneDenied
    }
  }

  @ViewBuilder
  private func permissionSheet(_ request: PermissionRequest) -> some View {
    switch request {
    case .cameraExplain:
      PermissionPrePromptView(
        feature: .camera,
        onResult: { granted in
          permissionRequest = nil
          cameraEnabled = granted
        },
        onCancel: { permissionRequest = nil }
      )

    case .cameraDenied:
      PermissionDeniedView(feature: .camera) { permissionRequest = nil }

    case .microphoneExplain:
      PermissionPrePromptView(
        feature: .microphone,
        onResult: { granted in
          permissionRequest = nil
          if granted { recorder.start() }
        },
        onCancel: { permissionRequest = nil }
      )

    case .microphoneDenied:
      PermissionDeniedView(feature: .microphone) { permissionRequest = nil }
    }
  }

  /// Advances the recorder clock and samples the audio meter once per frame.
  private func advanceRecorder(_ date: Date) {
    recorder.tick(date)
    if recorder.phase == .recording {
      recorder.updateLevel(decibels: currentMeterDecibels())
    }
  }

  private func currentMeterDecibels() -> Double {
    recordingMode == .video ? session.audioMeterDecibels() : audioRecorder.meterDecibels()
  }

  /// Begins the backing recorder when the count-in finishes. The mode follows
  /// the camera ("what you see is what you record").
  private func beginFileRecording() {
    let mode: TakeMode = isCameraActive ? .video : .audio
    recordingMode = mode
    let name = RecorderController.takeFileName(scriptTitle: script.title, mode: mode, date: .now)
    let url = RecordingsDirectory.fileURL(forName: name)
    switch mode {
    case .video:
      session.startRecording(to: url, micID: selectedMicrophoneID, codec: avCodec)
    case .audio:
      try? audioRecorder.start(to: url)
    }
  }

  /// Stops the take, finalizes the file, persists the Take, and confirms.
  private func stopRecording() {
    let mode = recordingMode
    let duration = recorder.elapsed
    let scriptID = script.id
    recorder.stop()
    Task {
      let url = await finalizeRecording(mode: mode)
      if let url {
        saveTake(url: url, mode: mode, duration: duration, scriptID: scriptID)
      }
      recorder.finish()
    }
  }

  private func finalizeRecording(mode: TakeMode) async -> URL? {
    switch mode {
    case .video: await session.stopRecording()
    case .audio: audioRecorder.stop()
    }
  }

  private func saveTake(url: URL, mode: TakeMode, duration: TimeInterval, scriptID: UUID) {
    Self.persistTake(url: url, mode: mode, duration: duration, scriptID: scriptID)
    savedTakeURL = url
  }

  /// Finalizes an in-progress take when the window closes, so it is never lost
  /// (GUIDELINES.md 2.2). Captures strong references so the save completes even
  /// as the view goes away, then releases the camera.
  private func finalizeOnClose() {
    let mode = recordingMode
    let duration = recorder.elapsed
    let scriptID = script.id
    let session = session
    let audioRecorder = audioRecorder
    Task { @MainActor in
      let url: URL? =
        switch mode {
        case .video: await session.stopRecording()
        case .audio: audioRecorder.stop()
        }
      if let url {
        Self.persistTake(url: url, mode: mode, duration: duration, scriptID: scriptID)
      }
      session.stop()
    }
  }

  private func scrollingText(viewport: CGSize, focusY: CGFloat) -> some View {
    Text(script.body)
      .font(.system(size: script.fontSize, weight: .medium))
      .lineSpacing(script.fontSize * 0.3)
      .multilineTextAlignment(.center)
      .foregroundStyle(readingTextStyle)
      .shadow(color: .black.opacity(isCameraActive ? 0.8 : 0), radius: isCameraActive ? 5 : 0, y: 1)
      .frame(width: viewport.width * lineWidthFraction)
      .padding(.top, focusY)
      .padding(.bottom, viewport.height - focusY)
      .frame(maxWidth: .infinity)
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
        contentHeight = newHeight
        updateMaxOffset()
      }
  }

  private func focusLine(width: CGFloat, y: CGFloat) -> some View {
    Rectangle()
      .fill(Color.accentColor.opacity(0.7))
      .frame(width: width, height: 2)
      .position(x: width / 2, y: y)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }

  /// The scrollable range is the content height beyond the viewport. With the
  /// top and bottom insets this equals the text's own height, so the first and
  /// last lines both align to the focus line at the ends of the scroll.
  private func updateMaxOffset() {
    engine.maxOffset = max(0, contentHeight - viewportHeight)
  }

  private func togglePlay() {
    engine.toggle()
    revealControls()
  }

  private func changeSpeed(by delta: Double) {
    engine.nudgeSpeed(by: delta)
    script.scrollSpeed = engine.speed
    revealControls()
  }

  private func changeFont(by delta: Double) {
    script.fontSize = min(Self.fontRange.upperBound, max(Self.fontRange.lowerBound, script.fontSize + delta))
    revealControls()
  }

  private func scrub(by delta: Double) -> KeyPress.Result {
    engine.scrub(by: delta)
    revealControls()
    return .handled
  }

  private func revealControls() {
    setControls(visible: true)
    scheduleHide()
  }

  /// Hides the transport after a short idle, but only while playing. When
  /// paused the controls stay put so the reader can always reach them.
  private func scheduleHide() {
    hideTask?.cancel()
    guard engine.isPlaying else { return }
    hideTask = Task {
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled, engine.isPlaying else { return }
      setControls(visible: false)
      NSCursor.setHiddenUntilMouseMoves(true)
    }
  }

  private func setControls(visible: Bool) {
    guard showControls != visible else { return }
    if reduceMotion {
      showControls = visible
    } else {
      withAnimation(.easeInOut(duration: 0.2)) { showControls = visible }
    }
  }

  /// Routes two-finger scroll over the teleprompter window to manual scrub.
  /// Reads the window from a reference box so the long-lived monitor never sees
  /// a stale value, and ignores scroll aimed at any other window.
  private func installScrollMonitor() {
    scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [engine, windowBox] event in
      guard let eventWindow = event.window, eventWindow === windowBox.window else { return event }
      engine.scrub(by: event.scrollingDeltaY)
      return nil
    }
  }

  private func removeScrollMonitor() {
    if let scrollMonitor {
      NSEvent.removeMonitor(scrollMonitor)
    }
    scrollMonitor = nil
  }
}

// MARK: - PermissionRequest

/// Which permission sheet the teleprompter is presenting, if any: the in-context
/// explainer before the first system prompt, or the recovery sheet after a
/// denial, for either the camera (preview) or the microphone (recording)
/// (GUIDELINES.md 1.1).
private enum PermissionRequest: Identifiable {
  case cameraExplain
  case cameraDenied
  case microphoneExplain
  case microphoneDenied

  var id: Self {
    self
  }
}

// MARK: - WindowBox

/// A stable reference holder for the host window, so a long-lived event monitor
/// always reads the current value instead of a captured `@State` snapshot.
private final class WindowBox {
  weak var window: NSWindow?
}

// MARK: - WindowReader

/// Resolves the `NSWindow` hosting a SwiftUI view, reported through a callback.
private struct WindowReader: NSViewRepresentable {
  let onResolve: (NSWindow?) -> Void

  func makeNSView(context _: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async { onResolve(view.window) }
    return view
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    DispatchQueue.main.async { onResolve(nsView.window) }
  }
}
