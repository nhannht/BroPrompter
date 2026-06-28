import Foundation

// MARK: - TrimSelection

/// The in/out trim selection over a take's timeline (BROP-8). Pure range math for
/// the trim editor: no AVFoundation and no UI, so it is unit-testable like
/// `RecordingsList` and `TeleprompterEngine`. Times are seconds from the take's
/// start; `start` is the in-point and `end` the out-point. The editor builds the
/// `CMTimeRange` for the export from these seconds (`TakeTrimmer`), keeping this
/// type free of media frameworks.
struct TrimSelection: Equatable {

  // MARK: Lifecycle

  /// A selection spanning the whole take (no trim yet).
  init(duration: TimeInterval) {
    self.init(duration: duration, start: 0, end: duration)
  }

  /// A selection with explicit in/out points, each clamped into a valid range.
  init(duration: TimeInterval, start: TimeInterval, end: TimeInterval) {
    self.duration = max(0, duration)
    let clampedEnd = Self.clampedEnd(end, start: start, duration: self.duration, minimum: Self.minimumDuration)
    self.end = clampedEnd
    self.start = Self.clampedStart(start, end: clampedEnd, minimum: Self.minimumDuration)
  }

  // MARK: Internal

  /// The shortest trimmed span the editor allows, in seconds. Keeps the in/out
  /// handles from crossing or producing a zero-length take.
  static let minimumDuration: TimeInterval = 0.5

  /// The full take length in seconds.
  let duration: TimeInterval

  /// The in-point in seconds, in `0...end - minimumDuration`.
  private(set) var start: TimeInterval

  /// The out-point in seconds, in `start + minimumDuration...duration`.
  private(set) var end: TimeInterval

  /// The length of the trimmed result in seconds.
  var trimmedDuration: TimeInterval {
    end - start
  }

  /// Whether either handle has moved off the full span. A small epsilon keeps
  /// sub-frame jitter from counting as a trim (so Save stays disabled until the
  /// user makes a real cut).
  var isTrimmed: Bool {
    start > Self.epsilon || end < duration - Self.epsilon
  }

  /// Whether the take is long enough to trim at all (longer than the minimum
  /// span). Degenerate short takes cannot be cut.
  var canTrim: Bool {
    duration > Self.minimumDuration + Self.epsilon
  }

  /// Moves the in-point, clamped to `0...end - minimumDuration`.
  mutating func setStart(_ proposed: TimeInterval) {
    start = Self.clampedStart(proposed, end: end, minimum: Self.minimumDuration)
  }

  /// Moves the out-point, clamped to `start + minimumDuration...duration`.
  mutating func setEnd(_ proposed: TimeInterval) {
    end = Self.clampedEnd(proposed, start: start, duration: duration, minimum: Self.minimumDuration)
  }

  // MARK: Private

  /// Tolerance for "the handle is effectively at the edge", in seconds.
  private static let epsilon: TimeInterval = 0.05
}

// MARK: - Pure helpers

extension TrimSelection {
  /// Clamps a proposed in-point so it stays at or after 0 and at least `minimum`
  /// before the out-point.
  static func clampedStart(
    _ proposed: TimeInterval,
    end: TimeInterval,
    minimum: TimeInterval
  ) -> TimeInterval {
    min(max(0, proposed), max(0, end - minimum))
  }

  /// Clamps a proposed out-point so it stays at most `duration` and at least
  /// `minimum` after the in-point.
  static func clampedEnd(
    _ proposed: TimeInterval,
    start: TimeInterval,
    duration: TimeInterval,
    minimum: TimeInterval
  ) -> TimeInterval {
    max(min(proposed, duration), min(duration, start + minimum))
  }

  /// The time in seconds at a `0...1` fraction of the take.
  static func time(atFraction fraction: Double, duration: TimeInterval) -> TimeInterval {
    duration * min(max(0, fraction), 1)
  }

  /// The `0...1` fraction of the take at a time in seconds.
  static func fraction(atTime time: TimeInterval, duration: TimeInterval) -> Double {
    guard duration > 0 else { return 0 }
    return min(max(0, time / duration), 1)
  }
}
