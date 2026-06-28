import Foundation
import Testing

@testable import BroPrompter

/// Unit tests for the trim in/out math (BROP-8): clamping, the minimum span, and
/// the fraction <-> time conversions the editor's dual-handle scrubber needs are
/// pure functions, so they run headlessly with no player or store.
@Suite("Trim selection")
struct TrimSelectionTests {

  @Test("a fresh selection spans the whole take and is not trimmed")
  func fullSpanByDefault() {
    let selection = TrimSelection(duration: 120)
    #expect(selection.start == 0)
    #expect(selection.end == 120)
    #expect(selection.trimmedDuration == 120)
    #expect(!selection.isTrimmed)
    #expect(selection.canTrim)
  }

  @Test("moving the in-point trims and shortens the result")
  func movingStartTrims() {
    var selection = TrimSelection(duration: 120)
    selection.setStart(30)
    #expect(selection.start == 30)
    #expect(selection.end == 120)
    #expect(selection.trimmedDuration == 90)
    #expect(selection.isTrimmed)
  }

  @Test("the in-point cannot cross the out-point and keeps the minimum span")
  func startClampsToMinimumBeforeEnd() {
    var selection = TrimSelection(duration: 10, start: 0, end: 4)
    selection.setStart(8)
    #expect(selection.start == 4 - TrimSelection.minimumDuration)
    #expect(selection.end == 4)
  }

  @Test("a negative in-point clamps to zero")
  func startClampsToZero() {
    var selection = TrimSelection(duration: 10)
    selection.setStart(-5)
    #expect(selection.start == 0)
  }

  @Test("the out-point cannot exceed the duration")
  func endClampsToDuration() {
    var selection = TrimSelection(duration: 10)
    selection.setEnd(99)
    #expect(selection.end == 10)
  }

  @Test("the out-point cannot cross the in-point and keeps the minimum span")
  func endClampsToMinimumAfterStart() {
    var selection = TrimSelection(duration: 10, start: 6, end: 10)
    selection.setEnd(1)
    #expect(selection.end == 6 + TrimSelection.minimumDuration)
    #expect(selection.start == 6)
  }

  @Test("an explicit sub-range is preserved and reports as trimmed")
  func explicitSubRange() {
    let selection = TrimSelection(duration: 60, start: 10, end: 50)
    #expect(selection.start == 10)
    #expect(selection.end == 50)
    #expect(selection.trimmedDuration == 40)
    #expect(selection.isTrimmed)
  }

  @Test("a take at or below the minimum span cannot be trimmed")
  func shortTakeCannotTrim() {
    let selection = TrimSelection(duration: 0.3)
    #expect(!selection.canTrim)
    #expect(selection.start == 0)
    #expect(selection.end == 0.3)
  }

  @Test("fraction and time convert and clamp to 0...1 of the take")
  func fractionTimeRoundTrip() {
    #expect(TrimSelection.time(atFraction: 0.25, duration: 120) == 30)
    #expect(TrimSelection.time(atFraction: 1.5, duration: 120) == 120)
    #expect(TrimSelection.time(atFraction: -0.5, duration: 120) == 0)
    #expect(TrimSelection.fraction(atTime: 30, duration: 120) == 0.25)
    #expect(TrimSelection.fraction(atTime: 240, duration: 120) == 1)
    #expect(TrimSelection.fraction(atTime: 10, duration: 0) == 0)
  }
}
