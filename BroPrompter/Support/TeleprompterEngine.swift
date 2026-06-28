import Foundation
import Observation

// MARK: - TeleprompterEngine

/// Drives the teleprompter scroll: an `offset` in points that advances at a
/// user-set `speed` while playing, clamped to the scrollable range. The motion
/// math lives in pure static helpers so it can be unit-tested without a running
/// clock (mirrors the `ReadingStats` pattern). At the end of the script the
/// scroll stops and takes no further action (GUIDELINES.md section 3 / BROP-4).
@MainActor
@Observable
final class TeleprompterEngine {

  // MARK: Lifecycle

  init(speed: Double = 60) {
    self.speed = speed
  }

  // MARK: Internal

  /// Current scroll position, in points from the top of the content.
  var offset = 0.0

  /// Auto-scroll speed, in points per second. Adjustable live.
  var speed: Double

  /// Whether the scroll is currently advancing.
  private(set) var isPlaying = false

  /// The furthest the content can scroll (content height minus viewport height),
  /// never negative. Set from layout as the reading view measures itself.
  var maxOffset = 0.0 {
    didSet { offset = Self.clamp(offset, maxOffset: maxOffset) }
  }

  /// Fraction of the script scrolled, 0...1.
  var progress: Double {
    Self.progress(offset: offset, maxOffset: maxOffset)
  }

  /// Estimated seconds elapsed at the current pace.
  var elapsed: TimeInterval {
    Self.elapsed(offset: offset, speed: speed)
  }

  /// Estimated seconds remaining at the current pace.
  var remaining: TimeInterval {
    Self.remaining(offset: offset, maxOffset: maxOffset, speed: speed)
  }

  /// Whether the scroll has reached the end of the content.
  var isAtEnd: Bool {
    maxOffset > 0 && offset >= maxOffset
  }

  func play() {
    guard !isAtEnd else { return }
    lastTick = nil
    isPlaying = true
  }

  func pause() {
    isPlaying = false
    lastTick = nil
  }

  func toggle() {
    isPlaying ? pause() : play()
  }

  /// Jumps back to the top and stops, ready to read from the start again.
  func restart() {
    offset = 0
    lastTick = nil
  }

  /// Manually moves the scroll by a points delta (trackpad / arrow-key scrub),
  /// clamped to range. Does not change the play/pause state.
  func scrub(by delta: Double) {
    offset = Self.clamp(offset + delta, maxOffset: maxOffset)
  }

  /// Nudges the auto-scroll speed by a delta, clamped to the supported range so a
  /// held keyboard or menu repeat cannot drive it past the slider's bounds (BROP-41).
  func nudgeSpeed(by delta: Double) {
    speed = min(Self.maximumSpeed, max(Self.minimumSpeed, speed + delta))
  }

  /// Advances the offset by the time since the previous tick. Call once per
  /// animation frame (from `TimelineView`). Seeds the clock on the first playing
  /// tick, and stops when the scroll reaches the end.
  func tick(_ date: Date) {
    guard isPlaying else { lastTick = date
      return
    }
    defer { lastTick = date }
    guard let lastTick else { return }
    let interval = date.timeIntervalSince(lastTick)
    guard interval > 0 else { return }
    offset = Self.nextOffset(current: offset, speed: speed, dt: interval, maxOffset: maxOffset)
    if isAtEnd { isPlaying = false }
  }

  // MARK: Private

  /// Timestamp of the previous tick, used to integrate elapsed time.
  private var lastTick: Date?
}

// MARK: - Pure scroll math

extension TeleprompterEngine {
  /// Slowest allowed auto-scroll speed, in points per second.
  static let minimumSpeed = 10.0

  /// Fastest allowed auto-scroll speed, in points per second. Shared with the
  /// transport slider's range so the control and the engine agree (BROP-41).
  static let maximumSpeed = 300.0

  /// Clamps an offset into the valid `0...maxOffset` range.
  static func clamp(_ offset: Double, maxOffset: Double) -> Double {
    min(max(0, offset), max(0, maxOffset))
  }

  /// One "page" of manual scrub for the Left/Right keys (BROP-38): most of the
  /// visible height, so a jump keeps a little overlap for context, floored at one
  /// line so a tiny viewport still advances. `lineHeight` is the reader's current
  /// line step.
  static func pageStep(viewportHeight: Double, lineHeight: Double) -> Double {
    max(lineHeight, viewportHeight * 0.8)
  }

  /// The offset after advancing `dt` seconds at `speed`, clamped to range.
  static func nextOffset(
    current: Double,
    speed: Double,
    dt: TimeInterval,
    maxOffset: Double
  ) -> Double {
    clamp(current + speed * dt, maxOffset: maxOffset)
  }

  /// Fraction scrolled, 0...1 (0 when there is nothing to scroll).
  static func progress(offset: Double, maxOffset: Double) -> Double {
    guard maxOffset > 0 else { return 0 }
    return min(1, max(0, offset / maxOffset))
  }

  /// Seconds elapsed at `speed` (0 when there is no forward speed).
  static func elapsed(offset: Double, speed: Double) -> TimeInterval {
    guard speed > 0 else { return 0 }
    return max(0, offset) / speed
  }

  /// Seconds remaining at `speed` (0 when stopped or at the end).
  static func remaining(offset: Double, maxOffset: Double, speed: Double) -> TimeInterval {
    guard speed > 0 else { return 0 }
    return max(0, maxOffset - offset) / speed
  }

  /// Formats a duration as `m:ss` (clamped at zero). Pure, so it is `nonisolated`
  /// and can be reused off the main actor (for example by `RecordingsList`).
  nonisolated static func clockString(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds).rounded())
    return "\(total / 60):" + String(format: "%02d", total % 60)
  }
}
