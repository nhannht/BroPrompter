import AVKit
import SwiftData
import SwiftUI

// MARK: - TrimEditorView

/// The lossless trim editor (BROP-8). Reached from Take Review's Trim action, it
/// previews the take with a clean (control-free) player, a dual-handle timeline for
/// the in/out points, and Save controls. "Save as New Take" is the non-destructive
/// default; "Replace Original" is destructive and confirmed (GUIDELINES.md 2.2,
/// "protect the take"). The cut is lossless passthrough (`TakeTrimmer`), so it snaps
/// to keyframe boundaries. No prototype frame exists for this screen; it follows the
/// recordings flow's full-window navigation and the design tokens.
struct TrimEditorView: View {

  // MARK: Lifecycle

  init(take: Take, onCancel: @escaping () -> Void, onSaved: @escaping (Take) -> Void) {
    self.take = take
    self.onCancel = onCancel
    self.onSaved = onSaved
    _selection = State(initialValue: TrimSelection(duration: take.duration))
  }

  // MARK: Internal

  let take: Take
  let onCancel: () -> Void
  let onSaved: (Take) -> Void

  var body: some View {
    VStack(spacing: 16) {
      playerArea
      TrimTimeline(
        duration: take.duration,
        selection: $selection,
        currentTime: preview?.currentTime ?? 0,
        onScrub: { preview?.scrub(to: $0) }
      )
      .frame(maxWidth: 900)
      detail
      actions
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationTitle("Trim Take")
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Button(action: onCancel) {
          Label("Review Take", systemImage: "chevron.left")
        }
        .keyboardShortcut(.cancelAction)
        .help("Back to the take without saving")
        .accessibilityIdentifier("trimEditorBack")
      }
      ToolbarItem(placement: .principal) {
        Text("Trim")
          .font(.headline)
      }
    }
    .alert("Replace original take?", isPresented: $showReplaceConfirm) {
      Button("Replace", role: .destructive) { replaceOriginal() }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("The original recording will be replaced with the trimmed version. This can't be undone.")
    }
    .alert("Couldn't trim", isPresented: errorPresented, presenting: errorMessage) { _ in
      Button("OK", role: .cancel) { errorMessage = nil }
    } message: { message in
      Text(message)
    }
    .task(id: take.id) { preview = TrimPreview(url: take.fileURL) }
    .onDisappear { preview?.invalidate() }
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext

  @State private var selection: TrimSelection
  @State private var preview: TrimPreview?
  @State private var isExporting = false
  @State private var showReplaceConfirm = false
  @State private var errorMessage: String?

  private var canSave: Bool {
    selection.isTrimmed && selection.canTrim && !isExporting
  }

  private var errorPresented: Binding<Bool> {
    Binding(
      get: { errorMessage != nil },
      set: { presented in if !presented { errorMessage = nil } }
    )
  }

  private var playerArea: some View {
    ZStack {
      Color.black
      if take.mode == .video, let preview {
        PlayerSurface(player: preview.player)
      } else {
        Image(systemName: "waveform")
          .font(.system(size: 64))
          .foregroundStyle(.white.opacity(0.7))
          .allowsHitTesting(false)
      }
      if isExporting {
        ProgressView("Trimming...")
          .padding(16)
          .glassEffect(.regular, in: .rect(cornerRadius: 10))
      }
    }
    .aspectRatio(16.0 / 9.0, contentMode: .fit)
    .clipShape(.rect(cornerRadius: 12))
    .frame(maxWidth: 900)
  }

  private var detail: some View {
    HStack(spacing: 24) {
      label("Start", time: selection.start)
      label("End", time: selection.end)
      label("Length", time: selection.trimmedDuration)
    }
    .font(.callout)
    .accessibilityIdentifier("trimEditorDetail")
  }

  private var actions: some View {
    HStack(spacing: 12) {
      Button("Reset", action: resetSelection)
        .disabled(!selection.isTrimmed || isExporting)
        .accessibilityIdentifier("trimEditorReset")
      Button {
        preview?.playSelection(selection)
      } label: {
        Label("Play Selection", systemImage: "play.fill")
      }
      .disabled(isExporting)
      .accessibilityIdentifier("trimEditorPlay")

      Spacer()

      Button("Replace Original...") { showReplaceConfirm = true }
        .tint(.red)
        .disabled(!canSave)
        .accessibilityIdentifier("trimEditorReplace")
      Button("Save as New Take", action: saveAsNew)
        .buttonStyle(.borderedProminent)
        .disabled(!canSave)
        .accessibilityIdentifier("trimEditorSaveNew")
    }
    .controlSize(.large)
  }

  private func label(_ title: String, time: TimeInterval) -> some View {
    HStack(spacing: 6) {
      Text(title)
        .foregroundStyle(.secondary)
      Text(TeleprompterEngine.clockString(time))
        .monospacedDigit()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title) \(TeleprompterEngine.clockString(time))")
  }

  private func resetSelection() {
    selection = TrimSelection(duration: take.duration)
    preview?.scrub(to: 0)
  }

  private func saveAsNew() {
    runExport {
      let newTake = try await TakeStore.saveTrimmed(take, selection: selection, in: modelContext)
      onSaved(newTake)
    }
  }

  private func replaceOriginal() {
    runExport {
      try await TakeStore.replaceWithTrimmed(take, selection: selection, in: modelContext)
      onSaved(take)
    }
  }

  /// Runs an export action, showing the progress overlay and surfacing any failure
  /// as an alert while leaving the original take untouched.
  private func runExport(_ work: @escaping () async throws -> Void) {
    preview?.pause()
    isExporting = true
    Task {
      defer { isExporting = false }
      do {
        try await work()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }
}

// MARK: - TrimTimeline

/// A dual-handle trim scrubber: a track with the selected range filled, draggable
/// in/out handles, and a playhead. SwiftUI has no native range slider, so this is
/// custom. Each handle is an adjustable accessibility element so it can be nudged
/// with the keyboard and VoiceOver.
private struct TrimTimeline: View {

  // MARK: Internal

  let duration: TimeInterval
  @Binding var selection: TrimSelection
  let currentTime: TimeInterval
  let onScrub: (TimeInterval) -> Void

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let startX = position(forTime: selection.start, width: width)
      let endX = position(forTime: selection.end, width: width)

      ZStack(alignment: .leading) {
        Capsule()
          .fill(.quaternary)
          .frame(height: Self.trackHeight)

        Capsule()
          .fill(Color.accentColor.opacity(0.35))
          .frame(width: max(0, endX - startX), height: Self.trackHeight)
          .offset(x: startX)

        playhead(width: width)

        handle(systemImage: "chevron.compact.left", centerX: startX)
          .gesture(dragGesture(width: width) { selection.setStart($0)
            onScrub(selection.start)
          })
          .accessibilityLabel("Trim start")
          .accessibilityValue(TeleprompterEngine.clockString(selection.start))
          .accessibilityAdjustableAction { adjustStart($0) }
          .accessibilityIdentifier("trimEditorStartHandle")

        handle(systemImage: "chevron.compact.right", centerX: endX)
          .gesture(dragGesture(width: width) { selection.setEnd($0)
            onScrub(selection.end)
          })
          .accessibilityLabel("Trim end")
          .accessibilityValue(TeleprompterEngine.clockString(selection.end))
          .accessibilityAdjustableAction { adjustEnd($0) }
          .accessibilityIdentifier("trimEditorEndHandle")
      }
      .coordinateSpace(.named(Self.space))
      .frame(maxHeight: .infinity)
    }
    .frame(height: 44)
  }

  // MARK: Private

  private static let handleWidth: CGFloat = 14
  private static let handleHeight: CGFloat = 32
  private static let trackHeight: CGFloat = 6
  private static let space = "trimTimeline"

  private func playhead(width: CGFloat) -> some View {
    let usable = max(1, width - Self.handleWidth)
    let fraction = TrimSelection.fraction(atTime: currentTime, duration: duration)
    let x = Self.handleWidth / 2 + CGFloat(fraction) * usable
    return Capsule()
      .fill(.primary)
      .frame(width: 2, height: 22)
      .offset(x: x - 1)
      .allowsHitTesting(false)
  }

  private func handle(systemImage: String, centerX: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(Color.accentColor)
      .frame(width: Self.handleWidth, height: Self.handleHeight)
      .overlay {
        Image(systemName: systemImage)
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.white)
      }
      .offset(x: centerX - Self.handleWidth / 2)
      .accessibilityElement()
  }

  private func position(forTime time: TimeInterval, width: CGFloat) -> CGFloat {
    let usable = max(1, width - Self.handleWidth)
    return Self.handleWidth / 2 + CGFloat(TrimSelection.fraction(atTime: time, duration: duration)) * usable
  }

  private func time(atX x: CGFloat, width: CGFloat) -> TimeInterval {
    let usable = max(1, width - Self.handleWidth)
    let fraction = Double((x - Self.handleWidth / 2) / usable)
    return TrimSelection.time(atFraction: fraction, duration: duration)
  }

  private func dragGesture(width: CGFloat, update: @escaping (TimeInterval) -> Void) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
      .onChanged { value in
        update(time(atX: value.location.x, width: width))
      }
  }

  private func adjustStart(_ direction: AccessibilityAdjustmentDirection) {
    let delta: TimeInterval = direction == .increment ? 1 : -1
    selection.setStart(selection.start + delta)
    onScrub(selection.start)
  }

  private func adjustEnd(_ direction: AccessibilityAdjustmentDirection) {
    let delta: TimeInterval = direction == .increment ? 1 : -1
    selection.setEnd(selection.end + delta)
    onScrub(selection.end)
  }
}

// MARK: - PlayerSurface

/// A bare `AVPlayerView` (no transport chrome) so the trim timeline is the only
/// scrubber. The system player controls would compete with the in/out handles.
private struct PlayerSurface: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context _: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.controlsStyle = .none
    view.videoGravity = .resizeAspect
    view.player = player
    return view
  }

  func updateNSView(_ nsView: AVPlayerView, context _: Context) {
    nsView.player = player
  }
}

// MARK: - TrimPreview

/// Drives the editor's preview player: it owns the `AVPlayer`, reports the playhead
/// for the timeline, and plays only the selected range (pausing at the out-point).
/// Time-observer callbacks land on the main queue, so they hop onto the main actor
/// to mutate state.
@MainActor
@Observable
private final class TrimPreview {

  // MARK: Lifecycle

  init(url: URL) {
    player = AVPlayer(url: url)
    let interval = CMTime(seconds: 0.03, preferredTimescale: 600)
    observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      MainActor.assumeIsolated {
        self?.tick(time.seconds)
      }
    }
  }

  // MARK: Internal

  let player: AVPlayer
  private(set) var currentTime: TimeInterval = 0

  /// Plays from the selection's in-point and stops at the out-point.
  func playSelection(_ selection: TrimSelection) {
    stopAt = selection.end
    seek(to: selection.start)
    player.play()
    isPlaying = true
  }

  /// Pauses and shows a specific frame, used while a handle is dragged.
  func scrub(to time: TimeInterval) {
    pause()
    currentTime = time
    seek(to: time)
  }

  func pause() {
    player.pause()
    isPlaying = false
    stopAt = nil
  }

  /// Stops playback and tears down the time observer; called when the view leaves.
  func invalidate() {
    pause()
    if let observer {
      player.removeTimeObserver(observer)
      self.observer = nil
    }
  }

  // MARK: Private

  private var observer: Any?
  private var stopAt: TimeInterval?
  private var isPlaying = false

  private func tick(_ seconds: TimeInterval) {
    currentTime = seconds
    if let stopAt, isPlaying, seconds >= stopAt {
      pause()
    }
  }

  private func seek(to time: TimeInterval) {
    player.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
  }
}
