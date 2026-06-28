import Testing

@testable import BroPrompter

/// Layer 1 unit tests for the pure reading-statistics helper (BROP-29).
@Suite("ReadingStats")
struct ReadingStatsTests {

  @Test("counts whitespace-separated words", arguments: [
    (text: "", expected: 0),
    (text: "hello", expected: 1),
    (text: "hello world", expected: 2),
    (text: "  spaced   out   words  ", expected: 3),
    (text: "line one\nline two", expected: 4),
    (text: "tab\tseparated", expected: 2),
  ])
  func wordCount(_ testCase: (text: String, expected: Int)) {
    #expect(ReadingStats.wordCount(of: testCase.text) == testCase.expected)
  }

  @Test("estimates read minutes at 150 wpm, rounded up, floor 1 for non-empty", arguments: [
    (words: 0, minutes: 0),
    (words: 1, minutes: 1),
    (words: 150, minutes: 1),
    (words: 151, minutes: 2),
    (words: 300, minutes: 2),
    (words: 301, minutes: 3),
  ])
  func readMinutes(_ testCase: (words: Int, minutes: Int)) {
    let text = String(repeating: "word ", count: testCase.words)
    #expect(ReadingStats.readMinutes(of: text) == testCase.minutes)
  }

  @Test("read minutes scale with the configured wpm, default matches 150", arguments: [
    (wpm: 300, minutes: 1),
    (wpm: 150, minutes: 2),
    (wpm: 100, minutes: 3),
  ])
  func readMinutesAtCustomPace(_ testCase: (wpm: Int, minutes: Int)) {
    let text = String(repeating: "word ", count: 300)
    #expect(ReadingStats.readMinutes(of: text, wordsPerMinute: testCase.wpm) == testCase.minutes)
    // The default parameter preserves the original 150-wpm behavior.
    #expect(ReadingStats.readMinutes(of: text) == ReadingStats.readMinutes(of: text, wordsPerMinute: 150))
  }
}
