import Foundation

// MARK: - CaptureQuality

/// A selectable camera capture quality: a target resolution and frame rate. The
/// teleprompter offers a fixed shortlist (BROP-5); which of them a given camera
/// can actually deliver is decided at runtime by `CaptureFormatResolver`.
enum CaptureQuality: String, CaseIterable, Identifiable {
  case hd720p30
  case hd1080p30
  case hd1080p60
  case uhd4K30

  // MARK: Internal

  /// The default quality, used when the camera supports it.
  static let preferred = CaptureQuality.hd1080p30

  var id: String {
    rawValue
  }

  /// Menu label, for example "1080p 30 fps".
  var displayName: String {
    switch self {
    case .hd720p30: "720p 30 fps"
    case .hd1080p30: "1080p 30 fps"
    case .hd1080p60: "1080p 60 fps"
    case .uhd4K30: "4K 30 fps"
    }
  }

  /// Target pixel width.
  var width: Int {
    switch self {
    case .hd720p30: 1_280
    case .hd1080p30, .hd1080p60: 1_920
    case .uhd4K30: 3_840
    }
  }

  /// Target pixel height.
  var height: Int {
    switch self {
    case .hd720p30: 720
    case .hd1080p30, .hd1080p60: 1_080
    case .uhd4K30: 2_160
    }
  }

  /// Target frame rate, in frames per second.
  var frameRate: Double {
    switch self {
    case .hd720p30, .hd1080p30, .uhd4K30: 30
    case .hd1080p60: 60
    }
  }
}

// MARK: - VideoFormatDescriptor

/// The few traits of an `AVCaptureDevice.Format` that quality selection needs,
/// lifted into a plain value so the matching logic is pure and unit-testable
/// without a camera (mirrors the `ReadingStats` / `TeleprompterEngine` pattern).
struct VideoFormatDescriptor: Equatable {
  let width: Int
  let height: Int
  let maxFrameRate: Double
}

// MARK: - CaptureFormatResolver

/// Decides which `CaptureQuality` presets a camera can deliver and which of its
/// formats best matches a chosen quality. Pure functions over
/// `VideoFormatDescriptor`, so `CaptureSessionManager` maps real device formats
/// in and out while the decision stays testable (BROP-32).
enum CaptureFormatResolver {

  // MARK: Internal

  /// The qualities, in menu order, that at least one format can satisfy.
  static func availableQualities(in formats: [VideoFormatDescriptor]) -> [CaptureQuality] {
    CaptureQuality.allCases.filter { quality in
      formats.contains { satisfies(quality, $0) }
    }
  }

  /// The index of the best format for `quality`, or `nil` when none qualifies.
  /// Among satisfying formats (same target dimensions) it picks the one with the
  /// least frame-rate headroom, so the camera is not over-allocated.
  static func match(_ quality: CaptureQuality, in formats: [VideoFormatDescriptor]) -> Int? {
    formats.indices
      .filter { satisfies(quality, formats[$0]) }
      .min { formats[$0].maxFrameRate < formats[$1].maxFrameRate }
  }

  // MARK: Private

  /// Whether a format can deliver the quality: exact target dimensions and at
  /// least the target frame rate.
  private static func satisfies(_ quality: CaptureQuality, _ format: VideoFormatDescriptor) -> Bool {
    format.width == quality.width
      && format.height == quality.height
      && format.maxFrameRate >= quality.frameRate
  }
}
