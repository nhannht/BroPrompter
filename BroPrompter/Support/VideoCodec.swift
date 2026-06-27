import Foundation

/// The video codec a take is recorded with (BROP-6). A UI/config value; the
/// mapping to `AVVideoCodecType` happens at the capture call site so this stays
/// free of AVFoundation.
enum VideoCodec: String, CaseIterable, Identifiable {
  case hevc
  case h264

  // MARK: Internal

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .hevc: "HEVC"
    case .h264: "H.264"
    }
  }
}
