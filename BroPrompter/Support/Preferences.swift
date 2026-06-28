import Foundation

/// One home for the app's `@AppStorage`-backed preferences (BROP-9): the key
/// strings, their default values, and resolved getters for the non-View call
/// sites (menu commands, model creation) that cannot use the `@AppStorage`
/// property wrapper. The Settings window and the teleprompter both bind these
/// keys, so centralizing them keeps the two from drifting.
enum Preferences {

  // MARK: Internal

  /// `UserDefaults` keys for every persisted preference. Use these with
  /// `@AppStorage` in views instead of repeating string literals.
  enum Key {
    static let readingWordsPerMinute = "reading.wordsPerMinute"
    static let defaultFontSize = "script.defaultFontSize"
    static let defaultScrollSpeed = "script.defaultScrollSpeed"
    static let mirrorText = "teleprompter.mirrorText"
    static let lineWidthFraction = "teleprompter.lineWidthFraction"
    static let cameraEnabled = "camera.enabled"
    static let micEnabled = "mic.enabled"
    static let cameraMirrored = "camera.mirrored"
    static let cameraDeviceID = "camera.deviceID"
    static let micDeviceID = "camera.micID"
    static let cameraQuality = "camera.quality"
    static let countdown = "recording.countdown"
    static let codec = "recording.codec"
    static let teleprompterTipSeen = "teleprompter.tipSeen"
  }

  /// Default values, used both as the `@AppStorage` fallback and as the resolved
  /// value when a key has never been written.
  enum Default {
    static let readingWordsPerMinute = ReadingStats.wordsPerMinute
    static let fontSize = 48.0
    static let scrollSpeed = 60.0
    static let mirrorText = false
    static let lineWidthFraction = 0.8
    static let cameraEnabled = true
    static let micEnabled = true
    static let cameraMirrored = true
    static let countdown = 3
    static let cameraQualityRaw = CaptureQuality.preferred.rawValue
    static let codecRaw = VideoCodec.hevc.rawValue
  }

  /// The reading pace in words per minute, falling back to the default when the
  /// user has not set one. For non-View call sites; views use `@AppStorage`.
  static var readingWordsPerMinute: Int {
    resolvedInt(Key.readingWordsPerMinute, default: Default.readingWordsPerMinute)
  }

  /// The default reading font size for new scripts, in points.
  static var defaultFontSize: Double {
    resolvedDouble(Key.defaultFontSize, default: Default.fontSize)
  }

  /// The default auto-scroll speed for new scripts, in points/second.
  static var defaultScrollSpeed: Double {
    resolvedDouble(Key.defaultScrollSpeed, default: Default.scrollSpeed)
  }

  /// A new script seeded with the user's default reading size and speed, so a
  /// fresh script opens at the preferred pace rather than the model defaults.
  @MainActor
  static func newScript() -> Script {
    let script = Script()
    script.fontSize = defaultFontSize
    script.scrollSpeed = defaultScrollSpeed
    return script
  }

  // MARK: Private

  private static func resolvedInt(_ key: String, default fallback: Int) -> Int {
    let defaults = UserDefaults.standard
    return defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
  }

  private static func resolvedDouble(_ key: String, default fallback: Double) -> Double {
    let defaults = UserDefaults.standard
    return defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
  }
}
