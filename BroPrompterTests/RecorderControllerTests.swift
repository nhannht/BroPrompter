import Foundation
import Testing

@testable import BroPrompter

/// Layer 1 unit tests for the recorder state machine (BROP-33): the pure meter,
/// countdown, and file-name helpers plus the `tick`-driven count-in and elapsed
/// integration. No AVFoundation, so the suite runs headless and CI-safe.
@MainActor
@Suite("Recorder controller")
struct RecorderControllerTests {

  @Test("meterLevel maps decibels onto 0...1 above the floor", arguments: [
    (decibels: -160.0, expected: 0.0),
    (decibels: -60.0, expected: 0.0),
    (decibels: -30.0, expected: 0.5),
    (decibels: 0.0, expected: 1.0),
    (decibels: 6.0, expected: 1.0),
  ])
  func meterLevelMapping(_ testCase: (decibels: Double, expected: Double)) {
    #expect(RecorderController.meterLevel(fromDecibels: testCase.decibels) == testCase.expected)
  }

  @Test("countdownValue counts the length down to zero", arguments: [
    (elapsed: 0.0, expected: 3),
    (elapsed: 0.9, expected: 3),
    (elapsed: 1.0, expected: 2),
    (elapsed: 2.5, expected: 1),
    (elapsed: 3.0, expected: 0),
  ])
  func countdownCounts(_ testCase: (elapsed: TimeInterval, expected: Int)) {
    #expect(RecorderController.countdownValue(length: 3, elapsed: testCase.elapsed) == testCase.expected)
  }

  @Test("isCountdownFinished is true once the length elapses")
  func countdownFinishes() {
    #expect(RecorderController.isCountdownFinished(length: 3, elapsed: 2.9) == false)
    #expect(RecorderController.isCountdownFinished(length: 3, elapsed: 3.0))
    #expect(RecorderController.isCountdownFinished(length: 0, elapsed: 0))
  }

  @Test("phase guards permit only valid transitions")
  func phaseGuards() {
    #expect(RecorderController.canStart(.idle))
    #expect(RecorderController.canStart(.recording) == false)
    #expect(RecorderController.canPause(.recording))
    #expect(RecorderController.canPause(.paused) == false)
    #expect(RecorderController.canResume(.paused))
    #expect(RecorderController.canStop(.countingIn))
    #expect(RecorderController.canStop(.recording))
    #expect(RecorderController.canStop(.idle) == false)
  }

  @Test("takeFileName sanitizes the title and stamps a UTC time")
  func fileNameComposition() {
    let date = Date(timeIntervalSinceReferenceDate: 0) // 2001-01-01 00:00:00 UTC
    #expect(
      RecorderController.takeFileName(scriptTitle: "My Script!", mode: .video, date: date)
        == "My-Script-2001-01-01-000000.mov"
    )
    #expect(
      RecorderController.takeFileName(scriptTitle: "   ", mode: .audio, date: date)
        == "Untitled-2001-01-01-000000.m4a"
    )
  }

  @Test("start with a count-in enters countingIn and shows the length")
  func startCountsIn() {
    let recorder = RecorderController()
    recorder.countdownLength = 3

    recorder.start()

    #expect(recorder.phase == .countingIn)
    #expect(recorder.countdownRemaining == 3)
    #expect(recorder.isActive)
  }

  @Test("start with the count-in off begins recording immediately")
  func startWithoutCountIn() {
    let recorder = RecorderController()
    recorder.countdownLength = 0

    recorder.start()

    #expect(recorder.phase == .recording)
  }

  @Test("ticking the count-in advances it and then begins recording")
  func countInBecomesRecording() {
    let recorder = RecorderController()
    recorder.countdownLength = 3
    let start = Date(timeIntervalSinceReferenceDate: 0)

    recorder.start()
    recorder.tick(start) // seeds the clock
    recorder.tick(start.addingTimeInterval(1))
    #expect(recorder.phase == .countingIn)
    #expect(recorder.countdownRemaining == 2)

    recorder.tick(start.addingTimeInterval(3))
    #expect(recorder.phase == .recording)
    #expect(recorder.elapsed == 0)
  }

  @Test("ticking while recording accumulates elapsed time")
  func recordingAccumulatesElapsed() {
    let recorder = RecorderController()
    recorder.countdownLength = 0
    let start = Date(timeIntervalSinceReferenceDate: 0)

    recorder.start()
    recorder.tick(start)
    recorder.tick(start.addingTimeInterval(2))

    #expect(recorder.elapsed == 2)
  }

  @Test("pause, resume, and stop move through the expected phases")
  func pauseResumeStop() {
    let recorder = RecorderController()
    recorder.countdownLength = 0

    recorder.start()
    recorder.pause()
    #expect(recorder.phase == .paused)

    recorder.resume()
    #expect(recorder.phase == .recording)

    recorder.stop()
    #expect(recorder.phase == .finalizing)

    recorder.finish()
    #expect(recorder.phase == .idle)
  }

  @Test("updateLevel records a normalized level and grows the history")
  func updateLevelTracksHistory() {
    let recorder = RecorderController()

    recorder.updateLevel(decibels: -30)
    #expect(recorder.level == 0.5)
    #expect(recorder.levelHistory == [0.5])

    recorder.updateLevel(decibels: 0)
    #expect(recorder.level == 1.0)
    #expect(recorder.levelHistory == [0.5, 1.0])
  }
}
