import Foundation
import SwiftData

/// Mutations on the take store that also touch the media files on disk (BROP-7).
/// The browser deletes through here so the metadata row and its recording never
/// drift apart.
enum TakeStore {
  /// Deletes a take: removes its media file from the recordings folder, then the
  /// model row. A missing file is ignored, so a partially deleted take still
  /// clears from the list.
  @MainActor
  static func delete(_ take: Take, in context: ModelContext) {
    try? FileManager.default.removeItem(at: take.fileURL)
    context.delete(take)
    try? context.save()
  }
}
