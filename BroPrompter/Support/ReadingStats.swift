import Foundation

/// Pure reading statistics for a script body: a word count and an estimated
/// read-aloud time. No UI dependency, so it can be unit-tested directly.
enum ReadingStats {
  /// Average teleprompter reading pace, in words per minute.
  static let wordsPerMinute = 150

  /// Counts whitespace-separated words in the given text.
  static func wordCount(of text: String) -> Int {
    text.split(whereSeparator: \.isWhitespace).count
  }

  /// Estimated minutes to read the text aloud at `wordsPerMinute`, rounded up,
  /// with a floor of 1 minute for any non-empty text and 0 for empty text.
  static func readMinutes(of text: String) -> Int {
    let words = wordCount(of: text)
    guard words > 0 else { return 0 }
    return max(1, Int((Double(words) / Double(wordsPerMinute)).rounded(.up)))
  }
}
