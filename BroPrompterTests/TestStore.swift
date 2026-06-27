import Foundation
import SwiftData

@testable import BroPrompter

/// Shared helpers for the Layer 1 SwiftData tests (BROP-29): isolated containers
/// that never touch the app's real store.
enum TestStore {
  /// A throwaway in-memory container for CRUD tests.
  static func inMemoryContainer() throws -> ModelContainer {
    let schema = Schema([Script.self, Take.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  /// An on-disk container at a caller-chosen URL, used to prove persistence
  /// across a container reopen.
  static func container(at url: URL) throws -> ModelContainer {
    let schema = Schema([Script.self, Take.self])
    let configuration = ModelConfiguration(schema: schema, url: url)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  /// A unique temporary store URL.
  static func tempStoreURL() -> URL {
    URL.temporaryDirectory.appending(path: "BroPrompterTests-\(UUID().uuidString).store")
  }

  /// Removes the store file and its SQLite sidecars.
  static func removeStore(at url: URL) {
    let manager = FileManager.default
    for suffix in ["", "-wal", "-shm"] {
      try? manager.removeItem(at: URL(fileURLWithPath: url.path(percentEncoded: false) + suffix))
    }
  }
}
