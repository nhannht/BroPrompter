import AppKit
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
        Color(nsColor: .textBackgroundColor)
          .ignoresSafeArea()

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
      }
      .contentShape(Rectangle())
      .onTapGesture { togglePlay() }
      .gesture(scrubGesture)
      .overlay(alignment: .bottom) { controls }
      .background(WindowReader { windowBox.window = $0 })
      .focusable()
      .focusEffectDisabled()
      .focused($isFocused)
      .onKeyPress(.upArrow) { scrub(by: -lineStep) }
      .onKeyPress(.downArrow) { scrub(by: lineStep) }
      .onExitCommand { dismiss() }
      .onContinuousHover { phase in
        if case .active = phase { revealControls() }
      }
      .onChange(of: engine.isPlaying) { _, playing in
        playing ? scheduleHide() : revealControls()
      }
      .onAppear {
        viewportHeight = proxy.size.height
        engine.speed = script.scrollSpeed
        updateMaxOffset()
        isFocused = true
        installScrollMonitor()
      }
      .onChange(of: proxy.size.height) { _, newHeight in
        viewportHeight = newHeight
        updateMaxOffset()
      }
      .onDisappear(perform: removeScrollMonitor)
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

  @State private var engine = TeleprompterEngine()
  @State private var viewportHeight = 0.0
  @State private var contentHeight = 0.0
  @State private var lastDragHeight = 0.0
  @State private var showControls = true
  @State private var hideTask: Task<Void, Never>?
  @State private var windowBox = WindowBox()
  @State private var scrollMonitor: Any?

  @FocusState private var isFocused: Bool

  /// Global reading-column width as a fraction of the viewport (DESIGN.md: line
  /// width is a display preference, not a per-script attribute).
  @AppStorage("teleprompter.lineWidthFraction") private var lineWidthFraction = 0.8

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
      onRestart: { engine.restart()
        revealControls()
      },
      onTogglePlay: togglePlay,
      onSlower: { changeSpeed(by: -Self.speedStep) },
      onFaster: { changeSpeed(by: Self.speedStep) },
      onSmaller: { changeFont(by: -Self.fontStep) },
      onLarger: { changeFont(by: Self.fontStep) },
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

  private func scrollingText(viewport: CGSize, focusY: CGFloat) -> some View {
    Text(script.body)
      .font(.system(size: script.fontSize, weight: .medium))
      .lineSpacing(script.fontSize * 0.3)
      .multilineTextAlignment(.center)
      .foregroundStyle(.primary)
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
