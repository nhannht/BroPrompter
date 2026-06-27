import Foundation

/// Presentation logic for the recordings browser (BROP-7): it turns the stored
/// `Take` rows into the names, subtitles, and recorded-date labels the H5
/// Recordings screen shows, with all date math driven by an injected `now` and
/// `Calendar` so it is unit-testable without a clock (mirrors `ReadingStats` /
/// `TeleprompterEngine`). No AVFoundation, no file I/O.
enum RecordingsList {

  // MARK: Internal

  /// One browser row: the take plus its derived display strings.
  struct Row: Identifiable {
    let take: Take
    let displayName: String
    let subtitle: String
    let recorded: String

    var id: UUID {
      take.id
    }
  }

  /// The takes as browser rows, most recent first. Each take is numbered within
  /// its own mode by capture order (oldest = 1), so video and audio takes count
  /// up independently (Take 1, Take 2, ...; Audio take 1, ...).
  static func rows(for takes: [Take], now: Date, calendar: Calendar = .current) -> [Row] {
    var perModeCount = [TakeMode: Int]()
    var ordinalByID = [UUID: Int]()
    for take in takes.sorted(by: { $0.createdAt < $1.createdAt }) {
      perModeCount[take.mode, default: 0] += 1
      ordinalByID[take.id] = perModeCount[take.mode]
    }

    return takes
      .sorted { $0.createdAt > $1.createdAt }
      .map { take in
        Row(
          take: take,
          displayName: displayName(for: take, ordinal: ordinalByID[take.id] ?? 1),
          subtitle: subtitle(for: take),
          recorded: recordedLabel(for: take.createdAt, now: now, calendar: calendar)
        )
      }
  }

  /// "Take N" for video, "Audio take N" for audio.
  static func displayName(for take: Take, ordinal: Int) -> String {
    switch take.mode {
    case .video: "Take \(ordinal)"
    case .audio: "Audio take \(ordinal)"
    }
  }

  /// The row subtitle: resolution + duration for video ("1080p / 2:14"), or
  /// "Audio / 3:12" for audio. Falls back to "Video" when a pre-BROP-7 take has
  /// no stored quality.
  static func subtitle(for take: Take) -> String {
    let clock = TeleprompterEngine.clockString(take.duration)
    switch take.mode {
    case .audio:
      return "Audio / \(clock)"
    case .video:
      guard let quality = take.quality else { return "Video / \(clock)" }
      return "\(resolutionLabel(quality)) / \(clock)"
    }
  }

  /// The full metadata line for the Take Review screen, for example
  /// "Take 3 | 1080p HEVC | 2:14 | Today 14:32".
  static func reviewDetail(
    for take: Take,
    ordinal: Int,
    now: Date,
    calendar: Calendar = .current
  ) -> String {
    var parts = [displayName(for: take, ordinal: ordinal)]
    if let quality = take.quality {
      let codec = take.codec.map { " \($0.displayName)" } ?? ""
      parts.append("\(resolutionLabel(quality))\(codec)")
    } else if take.mode == .audio {
      parts.append("Audio")
    }
    parts.append(TeleprompterEngine.clockString(take.duration))
    parts.append(recordedLabel(for: take.createdAt, now: now, calendar: calendar))
    return parts.joined(separator: "  |  ")
  }

  /// A short resolution tag for a capture quality (for example "1080p", "4K").
  static func resolutionLabel(_ quality: CaptureQuality) -> String {
    switch quality {
    case .hd720p30: "720p"
    case .hd1080p30: "1080p"
    case .hd1080p60: "1080p60"
    case .uhd4K30: "4K"
    }
  }

  /// "Today 14:32" / "Yesterday 18:40" / "Jun 26", relative to `now`.
  static func recordedLabel(for date: Date, now: Date, calendar: Calendar = .current) -> String {
    if calendar.isDate(date, inSameDayAs: now) {
      return "Today \(timeString(date, calendar: calendar))"
    }
    if
      let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
      calendar.isDate(date, inSameDayAs: yesterday)
    {
      return "Yesterday \(timeString(date, calendar: calendar))"
    }
    return dayString(date, calendar: calendar)
  }

  /// "1 take" / "5 takes".
  static func countLabel(_ count: Int) -> String {
    count == 1 ? "1 take" : "\(count) takes"
  }

  /// A human file size, for example "1.24 GB".
  static func sizeLabel(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }

  // MARK: Private

  private static func timeString(_ date: Date, calendar: Calendar) -> String {
    formatter(calendar, format: "HH:mm").string(from: date)
  }

  private static func dayString(_ date: Date, calendar: Calendar) -> String {
    formatter(calendar, format: "MMM d").string(from: date)
  }

  private static func formatter(_ calendar: Calendar, format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = calendar.locale ?? .current
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = format
    return formatter
  }
}
