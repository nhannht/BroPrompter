import Foundation
import SwiftData

/// Mutations on the take store that also touch the media files on disk (BROP-7,
/// BROP-8). The browser and trim editor go through here so a metadata row and its
/// recording never drift apart.
enum TakeStore {
  /// Deletes a take: removes its media file from the recordings folder, then the
  /// model row. A missing file is ignored, so a partially deleted take still
  /// clears from the list.
  @MainActor
  static func delete(_ take: Take, in context: ModelContext) {
    let fileURL = take.fileURL
    context.delete(take)
    // Persist the row deletion before removing the file. If the save fails the
    // row reappears on next launch, so keeping the file leaves the row and its
    // recording consistent instead of orphaning an unplayable take (BROP-41).
    do {
      try context.save()
    } catch {
      return
    }
    try? FileManager.default.removeItem(at: fileURL)
  }

  /// Trims `take` to `selection` and saves the result as a new take, leaving the
  /// original untouched (BROP-8, the non-destructive default). The lossless export
  /// runs off the main actor; the new row carries the source's mode, quality, and
  /// codec since passthrough keeps them. Returns the new take so the caller can
  /// land the user on it.
  @MainActor
  @discardableResult
  static func saveTrimmed(
    _ take: Take,
    selection: TrimSelection,
    in context: ModelContext
  ) async throws -> Take {
    let fileName = trimmedFileName(basedOn: take.fileName)
    try await TakeTrimmer.trim(
      source: take.fileURL,
      mode: take.mode,
      start: selection.start,
      end: selection.end,
      to: RecordingsDirectory.fileURL(forName: fileName)
    )
    let trimmed = Take(
      scriptID: take.scriptID,
      mode: take.mode,
      fileName: fileName,
      duration: selection.trimmedDuration,
      qualityRaw: take.qualityRaw,
      codecRaw: take.codecRaw
    )
    context.insert(trimmed)
    do {
      try context.save()
    } catch {
      // The trimmed file is already on disk; remove it so a failed save does not
      // leave an orphaned recording with no owning row (BROP-41).
      try? FileManager.default.removeItem(at: RecordingsDirectory.fileURL(forName: fileName))
      throw error
    }
    return trimmed
  }

  /// Trims `take` to `selection` in place (BROP-8, the destructive option). The
  /// trimmed range is written to a new file first, so a failed export leaves the
  /// original intact; only after the record points at the trimmed file is the old
  /// file removed. Keeps the same `Take.id`, so the take holds its list position.
  @MainActor
  static func replaceWithTrimmed(
    _ take: Take,
    selection: TrimSelection,
    in context: ModelContext
  ) async throws {
    let fileName = trimmedFileName(basedOn: take.fileName)
    let originalURL = take.fileURL
    try await TakeTrimmer.trim(
      source: originalURL,
      mode: take.mode,
      start: selection.start,
      end: selection.end,
      to: RecordingsDirectory.fileURL(forName: fileName)
    )
    let previousFileName = take.fileName
    let previousDuration = take.duration
    take.fileName = fileName
    take.duration = selection.trimmedDuration
    do {
      try context.save()
    } catch {
      // Roll back the in-memory edit and remove the freshly written file so a
      // failed save leaves the original take and the folder intact (BROP-41).
      take.fileName = previousFileName
      take.duration = previousDuration
      try? FileManager.default.removeItem(at: RecordingsDirectory.fileURL(forName: fileName))
      throw error
    }
    if originalURL != take.fileURL {
      try? FileManager.default.removeItem(at: originalURL)
    }
  }

  /// A unique file name for a trimmed copy: the source's base name with a short
  /// random suffix, keeping the source extension so the container stays the same.
  static func trimmedFileName(basedOn source: String) -> String {
    let url = URL(fileURLWithPath: source)
    let base = url.deletingPathExtension().lastPathComponent
    let suffix = UUID().uuidString.prefix(6)
    let ext = url.pathExtension
    return ext.isEmpty ? "\(base)-trim-\(suffix)" : "\(base)-trim-\(suffix).\(ext)"
  }
}
