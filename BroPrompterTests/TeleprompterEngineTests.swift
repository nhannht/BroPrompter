import Foundation
import Testing

@testable import BroPrompter

/// Layer 1 unit tests for the teleprompter scroll engine (BROP-31): the pure
/// motion math plus the stateful `tick` integration and play/pause behavior.
@MainActor
@Suite("Teleprompter engine")
struct TeleprompterEngineTests {

  @Test("nextOffset advances by speed * dt")
  func nextOffsetAdvances() {
    #expect(TeleprompterEngine.nextOffset(current: 0, speed: 60, dt: 1, maxOffset: 1_000) == 60)
    #expect(TeleprompterEngine.nextOffset(current: 100, speed: 50, dt: 2, maxOffset: 1_000) == 200)
  }

  @Test("nextOffset clamps at both ends")
  func nextOffsetClamps() {
    #expect(TeleprompterEngine.nextOffset(current: 990, speed: 60, dt: 1, maxOffset: 1_000) == 1_000)
    #expect(TeleprompterEngine.nextOffset(current: 10, speed: -100, dt: 1, maxOffset: 1_000) == 0)
  }

  @Test("progress is the clamped offset fraction", arguments: [
    (offset: 0.0, maxOffset: 1_000.0, expected: 0.0),
    (offset: 250.0, maxOffset: 1_000.0, expected: 0.25),
    (offset: 1_000.0, maxOffset: 1_000.0, expected: 1.0),
    (offset: 2_000.0, maxOffset: 1_000.0, expected: 1.0),
    (offset: 100.0, maxOffset: 0.0, expected: 0.0),
  ])
  func progressFraction(_ testCase: (offset: Double, maxOffset: Double, expected: Double)) {
    #expect(TeleprompterEngine.progress(offset: testCase.offset, maxOffset: testCase.maxOffset) == testCase.expected)
  }

  @Test("remaining is the distance left over the speed", arguments: [
    (offset: 400.0, speed: 60.0, expected: 10.0),
    (offset: 1_000.0, speed: 60.0, expected: 0.0),
    (offset: 0.0, speed: 0.0, expected: 0.0),
  ])
  func remainingSeconds(_ testCase: (offset: Double, speed: Double, expected: TimeInterval)) {
    let remaining = TeleprompterEngine.remaining(offset: testCase.offset, maxOffset: 1_000, speed: testCase.speed)
    #expect(remaining == testCase.expected)
  }

  @Test("clockString formats minutes and zero-padded seconds", arguments: [
    (seconds: 0.0, text: "0:00"),
    (seconds: 5.0, text: "0:05"),
    (seconds: 65.0, text: "1:05"),
    (seconds: 600.0, text: "10:00"),
    (seconds: -3.0, text: "0:00"),
  ])
  func clockFormatting(_ testCase: (seconds: TimeInterval, text: String)) {
    #expect(TeleprompterEngine.clockString(testCase.seconds) == testCase.text)
  }

  @Test("tick integrates elapsed time while playing")
  func tickAdvancesWhilePlaying() {
    let engine = TeleprompterEngine(speed: 100)
    engine.maxOffset = 1_000
    let start = Date(timeIntervalSinceReferenceDate: 0)

    engine.play()
    engine.tick(start) // first playing tick only seeds the clock
    engine.tick(start.addingTimeInterval(1)) // +1s at 100 pts/s

    #expect(engine.offset == 100)
    #expect(engine.isPlaying)
  }

  @Test("paused ticks do not move the offset")
  func tickIgnoredWhilePaused() {
    let engine = TeleprompterEngine(speed: 100)
    engine.maxOffset = 1_000
    let start = Date(timeIntervalSinceReferenceDate: 0)

    engine.tick(start)
    engine.tick(start.addingTimeInterval(5))

    #expect(engine.offset == 0)
  }

  @Test("reaching the end clamps and stops playback")
  func stopsAtEnd() {
    let engine = TeleprompterEngine(speed: 100)
    engine.maxOffset = 50
    let start = Date(timeIntervalSinceReferenceDate: 0)

    engine.play()
    engine.tick(start)
    engine.tick(start.addingTimeInterval(1)) // would reach 100, clamps to 50

    #expect(engine.offset == 50)
    #expect(engine.isPlaying == false)
    #expect(engine.isAtEnd)
  }

  @Test("scrub moves the offset within range")
  func scrubClamps() {
    let engine = TeleprompterEngine()
    engine.maxOffset = 300

    engine.scrub(by: 120)
    #expect(engine.offset == 120)

    engine.scrub(by: -500)
    #expect(engine.offset == 0)
  }

  @Test("restart returns to the top")
  func restartToTop() {
    let engine = TeleprompterEngine()
    engine.maxOffset = 300
    engine.scrub(by: 200)

    engine.restart()

    #expect(engine.offset == 0)
  }

  @Test("nudgeSpeed never drops below the minimum")
  func speedFloor() {
    let engine = TeleprompterEngine(speed: 60)

    engine.nudgeSpeed(by: 20)
    #expect(engine.speed == 80)

    engine.nudgeSpeed(by: -1_000)
    #expect(engine.speed == TeleprompterEngine.minimumSpeed)
  }

  @Test("lowering maxOffset clamps the current offset")
  func maxOffsetClampsCurrent() {
    let engine = TeleprompterEngine()
    engine.maxOffset = 1_000
    engine.scrub(by: 900)

    engine.maxOffset = 500

    #expect(engine.offset == 500)
  }
}
