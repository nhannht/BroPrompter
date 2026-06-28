import Foundation

/// Pure reading statistics for a script body: a word count and an estimated
/// read-aloud time. No UI dependency, so it can be unit-tested directly.
enum ReadingStats {
  /// Default teleprompter reading pace, in words per minute, when the user has
  /// not chosen one in Settings (BROP-9).
  static let wordsPerMinute = 150

  /// Counts whitespace-separated words in the given text.
  static func wordCount(of text: String) -> Int {
    text.split(whereSeparator: \.isWhitespace).count
  }

  /// Estimated minutes to read the text aloud at `wordsPerMinute`, rounded up,
  /// with a floor of 1 minute for any non-empty text and 0 for empty text. The
  /// pace is configurable (Settings), defaulting to `wordsPerMinute`.
  static func readMinutes(of text: String, wordsPerMinute: Int = wordsPerMinute) -> Int {
    let words = wordCount(of: text)
    guard words > 0, wordsPerMinute > 0 else { return 0 }
    return max(1, Int((Double(words) / Double(wordsPerMinute)).rounded(.up)))
  }
}
