import AVFoundation
import Foundation

/// Trims a take to a sub-range losslessly (BROP-8). An `AVAssetExportSession` with
/// the passthrough preset copies the selected sample range without re-encoding, so
/// the output keeps the original codec, resolution, and quality. Like
/// `TakeExporter`, this is a thin AVFoundation edge; the in/out math lives in the
/// pure, unit-tested `TrimSelection`.
///
/// Passthrough trims on sync-sample (keyframe) boundaries, so the cut may snap to
/// the nearest keyframe. That is the inherent cost of a lossless, no-re-encode trim
/// (frame-accurate trimming would require re-encoding, which is lossy).
enum TakeTrimmer {

  // MARK: Internal

  /// A failure surfaced to the editor when the trim cannot be written.
  enum TrimError: LocalizedError {
    case unsupportedAsset
    case exportFailed(String)

    // MARK: Internal

    var errorDescription: String? {
      switch self {
      case .unsupportedAsset:
        "This recording can't be trimmed without re-encoding."
      case .exportFailed(let reason):
        "The trimmed recording couldn't be saved. \(reason)"
      }
    }
  }

  /// Losslessly writes the `start...end` (seconds) range of `source` to
  /// `destination`, choosing the container from `mode` (.mov for video, .m4a for
  /// audio).
  ///
  /// Not `@MainActor`: the export session and its asset must not cross an actor
  /// boundary mid-export, so the caller awaits this off the main actor (the
  /// structured-concurrency-safe pattern for `AVAssetExportSession`).
  static func trim(
    source: URL,
    mode: TakeMode,
    start: TimeInterval,
    end: TimeInterval,
    to destination: URL
  ) async throws {
    let asset = AVURLAsset(url: source)
    guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
      throw TrimError.unsupportedAsset
    }

    let timescale: CMTimeScale = 600
    let startTime = CMTime(seconds: max(0, start), preferredTimescale: timescale)
    let endTime = CMTime(seconds: end, preferredTimescale: timescale)
    session.timeRange = CMTimeRange(start: startTime, end: endTime)

    // The export fails if the destination already exists; clear any stale file.
    try? FileManager.default.removeItem(at: destination)

    do {
      try await session.export(to: destination, as: fileType(for: mode))
    } catch {
      throw TrimError.exportFailed(error.localizedDescription)
    }
  }

  // MARK: Private

  /// The output container for a take's mode.
  private static func fileType(for mode: TakeMode) -> AVFileType {
    switch mode {
    case .video: .mov
    case .audio: .m4a
    }
  }
}
