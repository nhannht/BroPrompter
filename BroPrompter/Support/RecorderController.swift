import Foundation
import Observation

// MARK: - RecorderPhase

/// The recorder's lifecycle (BROP-6): idle, the 3-2-1 count-in, recording, a
/// paused take, and finalizing while the file is written.
enum RecorderPhase: Equatable {
  case idle
  case countingIn
  case recording
  case paused
  case finalizing
}

// MARK: - RecorderController

/// Drives a recording's timeline and state: the count-in, the elapsed clock, and
/// the audio level meter. Like `TeleprompterEngine`, the time-dependent logic
/// lives in pure static helpers and a `tick(_:)` integrator, so it is unit-tested
/// without a clock or any AVFoundation. The controller owns no capture objects;
/// the view starts and stops the backing recorder as `phase` changes and feeds
/// the meter back through `updateLevel`.
@MainActor
@Observable
final class RecorderController {

  // MARK: Internal

  /// The current lifecycle phase.
  private(set) var phase = RecorderPhase.idle

  /// Seconds recorded so far in the current take.
  private(set) var elapsed = 0.0

  /// Current audio level, 0...1, for the meter.
  private(set) var level = 0.0

  /// Recent levels (oldest first) for the audio-only waveform.
  private(set) var levelHistory = [Double]()

  /// The number the count-in is currently showing (0 once it is over).
  private(set) var countdownRemaining = 0

  /// Count-in length in seconds; 0 disables the count-in. Set from settings.
  var countdownLength = 3

  /// Whether the controller is advancing time, so the view ticks it only while
  /// the count-in or recording is running.
  var isActive: Bool {
    phase == .countingIn || phase == .recording
  }

  /// Whether a take is in progress (recording or paused), for the recording UI.
  var isCapturing: Bool {
    phase == .recording || phase == .paused
  }

  /// Begins a take: the count-in first, or recording immediately when the
  /// count-in is disabled. The view starts the backing recorder when `phase`
  /// becomes `.recording`.
  func start() {
    guard Self.canStart(phase) else { return }
    lastTick = nil
    countInElapsed = 0
    elapsed = 0
    level = 0
    levelHistory = []
    if countdownLength > 0 {
      countdownRemaining = countdownLength
      phase = .countingIn
    } else {
      beginRecording()
    }
  }

  func pause() {
    guard Self.canPause(phase) else { return }
    phase = .paused
    lastTick = nil
  }

  func resume() {
    guard Self.canResume(phase) else { return }
    phase = .recording
    lastTick = nil
  }

  /// Moves to finalizing. The caller stops the backing recorder, then calls
  /// `finish` once the file is written.
  func stop() {
    guard Self.canStop(phase) else { return }
    phase = .finalizing
    lastTick = nil
  }

  /// Returns to idle after the file has been finalized.
  func finish() {
    phase = .idle
    level = 0
    countdownRemaining = 0
  }

  /// Records a fresh meter reading (in decibels) as a normalized level.
  func updateLevel(decibels: Double) {
    level = Self.meterLevel(fromDecibels: decibels)
    levelHistory.append(level)
    if levelHistory.count > Self.maxLevelHistory {
      levelHistory.removeFirst(levelHistory.count - Self.maxLevelHistory)
    }
  }

  /// Advances the count-in and the elapsed clock by the time since the previous
  /// tick. Call once per frame from a `TimelineView` while `isActive`.
  func tick(_ date: Date) {
    defer { lastTick = date }
    guard let lastTick else { return }
    let interval = date.timeIntervalSince(lastTick)
    guard interval > 0 else { return }

    switch phase {
    case .countingIn:
      countInElapsed += interval
      countdownRemaining = Self.countdownValue(length: countdownLength, elapsed: countInElapsed)
      if Self.isCountdownFinished(length: countdownLength, elapsed: countInElapsed) {
        beginRecording()
      }

    case .recording:
      elapsed += interval

    default:
      break
    }
  }

  // MARK: Private

  /// How many recent levels the waveform keeps.
  private static let maxLevelHistory = 80

  private var lastTick: Date?
  private var countInElapsed = 0.0

  private func beginRecording() {
    elapsed = 0
    countdownRemaining = 0
    phase = .recording
  }
}

// MARK: - Pure recorder logic

extension RecorderController {
  /// Quietest level the meter shows, in decibels; anything lower reads as zero.
  static let meterFloorDecibels = -60.0

  static func canStart(_ phase: RecorderPhase) -> Bool {
    phase == .idle
  }

  static func canPause(_ phase: RecorderPhase) -> Bool {
    phase == .recording
  }

  static func canResume(_ phase: RecorderPhase) -> Bool {
    phase == .paused
  }

  static func canStop(_ phase: RecorderPhase) -> Bool {
    switch phase {
    case .countingIn, .recording, .paused: true
    default: false
    }
  }

  /// Maps an average-power reading in decibels to a 0...1 meter level, linear in
  /// decibels above the floor.
  static func meterLevel(fromDecibels decibels: Double) -> Double {
    guard decibels > meterFloorDecibels else { return 0 }
    guard decibels < 0 else { return 1 }
    return (decibels - meterFloorDecibels) / -meterFloorDecibels
  }

  /// The number to show during the count-in: counts `length` down to 1, then 0.
  static func countdownValue(length: Int, elapsed: TimeInterval) -> Int {
    max(0, length - Int(elapsed.rounded(.down)))
  }

  /// Whether the count-in has elapsed and recording should begin.
  static func isCountdownFinished(length: Int, elapsed: TimeInterval) -> Bool {
    elapsed >= Double(length)
  }

  /// A take's file name: a sanitized script title, a UTC timestamp, and the
  /// mode's extension. Pure (the date is passed in) so it is unit-testable.
  static func takeFileName(scriptTitle: String, mode: TakeMode, date: Date) -> String {
    "\(slug(scriptTitle))-\(timestampFormatter.string(from: date)).\(mode.fileExtension)"
  }
}

// MARK: - File naming

extension RecorderController {
  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return formatter
  }()

  /// A file-name-safe slug: alphanumerics kept, every other run collapsed to a
  /// single hyphen, falling back to "Untitled".
  private static func slug(_ title: String) -> String {
    let allowed = CharacterSet.alphanumerics
    let mapped = String(String.UnicodeScalarView(title.unicodeScalars.map { allowed.contains($0) ? $0 : " " }))
    let collapsed = mapped.split(separator: " ").joined(separator: "-")
    return collapsed.isEmpty ? "Untitled" : collapsed
  }
}
