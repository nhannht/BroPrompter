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
/// and last lines can each reach the focus line.
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
      .onTapGesture { engine.toggle() }
      .gesture(scrubGesture)
      .onAppear {
        viewportHeight = proxy.size.height
        engine.speed = script.scrollSpeed
        updateMaxOffset()
      }
      .onChange(of: proxy.size.height) { _, newHeight in
        viewportHeight = newHeight
        updateMaxOffset()
      }
    }
  }

  // MARK: Private

  /// Vertical position of the focus line as a fraction of the viewport height,
  /// near the top third where the reader's eyeline sits (GUIDELINES.md 2.3).
  private static let focusFraction = 0.4

  @State private var engine = TeleprompterEngine()
  @State private var viewportHeight = 0.0
  @State private var contentHeight = 0.0
  @State private var lastDragHeight = 0.0

  /// Global reading-column width as a fraction of the viewport (DESIGN.md: line
  /// width is a display preference, not a per-script attribute).
  @AppStorage("teleprompter.lineWidthFraction") private var lineWidthFraction = 0.8

  /// Drag to scrub the scroll manually; dragging up advances the script.
  private var scrubGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        engine.scrub(by: lastDragHeight - value.translation.height)
        lastDragHeight = value.translation.height
      }
      .onEnded { _ in lastDragHeight = 0 }
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
}
