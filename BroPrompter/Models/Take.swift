import Foundation
import SwiftData

// MARK: - TakeMode

/// Whether a take captured video (camera on) or audio only (camera off). The
/// teleprompter chooses the mode implicitly from the camera state (BROP-6).
enum TakeMode: String, CaseIterable, Identifiable {
  case video
  case audio

  // MARK: Internal

  var id: String {
    rawValue
  }

  /// The on-disk file extension for the mode's container format.
  var fileExtension: String {
    switch self {
    case .video: "mov"
    case .audio: "m4a"
    }
  }

  var displayName: String {
    switch self {
    case .video: "Video"
    case .audio: "Audio"
    }
  }
}

// MARK: - Take

/// A recorded take: the metadata for one capture, with the media file stored in
/// the app container under `RecordingsDirectory`. Only the relative file name is
/// stored, so the file resolves correctly even if the container path changes.
///
/// CloudKit-safe by construction (every attribute has a default, no unique
/// constraint, no relationship), matching `Script`, so iCloud sync can be turned
/// on later (BROP-27) without a migration. The optional `scriptID` is a loose
/// link to the source script rather than a SwiftData relationship.
@Model
final class Take {

  // MARK: Lifecycle

  init(
    id: UUID = UUID(),
    scriptID: UUID? = nil,
    mode: TakeMode,
    fileName: String,
    duration: TimeInterval,
    createdAt: Date = .now
  ) {
    self.id = id
    self.scriptID = scriptID
    modeRaw = mode.rawValue
    self.fileName = fileName
    self.duration = duration
    self.createdAt = createdAt
  }

  // MARK: Internal

  var id = UUID()
  var scriptID: UUID?
  var modeRaw = TakeMode.video.rawValue
  var fileName = ""
  var duration = 0.0
  var createdAt = Date.now
}

// MARK: - Derived

extension Take {
  /// The capture mode, falling back to video for any unrecognized stored value.
  var mode: TakeMode {
    TakeMode(rawValue: modeRaw) ?? .video
  }

  /// The media file's location in the app container.
  var fileURL: URL {
    RecordingsDirectory.fileURL(forName: fileName)
  }
}
