import Foundation
import Testing

@testable import BroPrompter

/// Unit tests for the recordings-browser presentation logic (BROP-34): names,
/// subtitles, and recorded-date labels are pure functions of the takes plus an
/// injected `now` / `Calendar`, so they run headlessly with no clock or store.
@Suite("Recordings list")
struct RecordingsListTests {

  // MARK: Internal

  @Test("video takes are 'Take N', audio takes are 'Audio take N'")
  func displayNamesByMode() {
    #expect(RecordingsList.displayName(for: Take(mode: .video, fileName: "v", duration: 1), ordinal: 3) == "Take 3")
    #expect(
      RecordingsList.displayName(for: Take(mode: .audio, fileName: "a", duration: 1), ordinal: 2)
        == "Audio take 2"
    )
  }

  @Test("the subtitle shows resolution and duration, with fallbacks")
  func subtitles() {
    let video = Take(mode: .video, fileName: "v", duration: 134, qualityRaw: CaptureQuality.hd1080p30.rawValue)
    #expect(RecordingsList.subtitle(for: video) == "1080p / 2:14")

    let audio = Take(mode: .audio, fileName: "a", duration: 192)
    #expect(RecordingsList.subtitle(for: audio) == "Audio / 3:12")

    let legacy = Take(mode: .video, fileName: "v", duration: 134)
    #expect(RecordingsList.subtitle(for: legacy) == "Video / 2:14")
  }

  @Test("resolution labels map each quality")
  func resolutionLabels() {
    #expect(RecordingsList.resolutionLabel(.hd720p30) == "720p")
    #expect(RecordingsList.resolutionLabel(.hd1080p30) == "1080p")
    #expect(RecordingsList.resolutionLabel(.hd1080p60) == "1080p60")
    #expect(RecordingsList.resolutionLabel(.uhd4K30) == "4K")
  }

  @Test("recorded labels are relative to now")
  func recordedLabels() {
    let calendar = Self.fixedCalendar
    let now = Self.date(2026, 6, 28, 10, 0)

    #expect(RecordingsList.recordedLabel(for: Self.date(2026, 6, 28, 14, 32), now: now, calendar: calendar) == "Today 14:32")
    #expect(
      RecordingsList.recordedLabel(for: Self.date(2026, 6, 27, 18, 40), now: now, calendar: calendar)
        == "Yesterday 18:40"
    )
    #expect(RecordingsList.recordedLabel(for: Self.date(2026, 6, 26, 9, 0), now: now, calendar: calendar) == "Jun 26")
  }

  @Test("rows sort newest first and number each mode by capture order")
  func rowsOrderingAndOrdinals() {
    let takes = [
      Take(mode: .video, fileName: "vA", duration: 1, createdAt: Self.date(2026, 6, 28, 9, 0)),
      Take(mode: .audio, fileName: "aA", duration: 1, createdAt: Self.date(2026, 6, 28, 9, 30)),
      Take(mode: .video, fileName: "vB", duration: 1, createdAt: Self.date(2026, 6, 28, 10, 0)),
      Take(mode: .audio, fileName: "aB", duration: 1, createdAt: Self.date(2026, 6, 28, 10, 30)),
      Take(mode: .video, fileName: "vC", duration: 1, createdAt: Self.date(2026, 6, 28, 11, 0)),
    ]

    let names = RecordingsList.rows(for: takes, now: Self.date(2026, 6, 28, 12, 0), calendar: Self.fixedCalendar)
      .map(\.displayName)
    #expect(names == ["Take 3", "Audio take 2", "Take 2", "Audio take 1", "Take 1"])
  }

  @Test("the count label pluralizes")
  func countLabels() {
    #expect(RecordingsList.countLabel(0) == "0 takes")
    #expect(RecordingsList.countLabel(1) == "1 take")
    #expect(RecordingsList.countLabel(5) == "5 takes")
  }

  // MARK: Private

  /// A Gregorian/UTC/POSIX calendar so date strings are machine-independent.
  private static let fixedCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
  }()

  private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    fixedCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
      ?? .distantPast
  }
}
