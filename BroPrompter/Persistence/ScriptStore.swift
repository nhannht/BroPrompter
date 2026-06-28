import Foundation
import SwiftData

/// Builds the SwiftData container that stores scripts.
///
/// Local-only for now. The store is CloudKit-ready: when the Apple Developer
/// account activates (BROP-27), add the iCloud/CloudKit entitlement and switch
/// the configuration to `cloudKitDatabase: .automatic`. No data migration is
/// needed, because `Script` is CloudKit-safe.
///
/// A single shared container backs both the app scene and the menu commands, so
/// `ScriptStore.container.mainContext` is the same context the window edits.
enum ScriptStore {

  // MARK: Internal

  /// The shared scripts container.
  static let container: ModelContainer = {
    let schema = Schema([Script.self, Take.self])
    let config = configuration(for: schema)
    do {
      return try ModelContainer(for: schema, configurations: [config])
    } catch {
      // The local store is corrupt or unreadable. Move it aside (preserved for
      // manual recovery, not deleted) and retry once, so the app still launches
      // instead of crash-looping on every start (BROP-41). A hosted test run is
      // in-memory and never reaches this path.
      moveStoreAside(at: config.url)
      do {
        return try ModelContainer(for: schema, configurations: [config])
      } catch {
        fatalError("Failed to create the scripts ModelContainer after recovery: \(error)")
      }
    }
  }()

  // MARK: Private

  /// `true` when the app is launched as the host of a hosted test bundle, so the
  /// suite never touches the real local store.
  private static var isRunningHostedTests: Bool {
    let environment = ProcessInfo.processInfo.environment
    return environment["XCTestConfigurationFilePath"] != nil
      || environment["XCTestBundlePath"] != nil
      || environment["XCTestSessionIdentifier"] != nil
  }

  private static func configuration(for schema: Schema) -> ModelConfiguration {
    if isRunningHostedTests {
      return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    }
    // CloudKit flip later (BROP-27):
    // ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
    return ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
  }

  /// Moves a corrupt store file and its SQLite sidecars out of the way, renaming
  /// each with a timestamped suffix so the data is preserved for recovery rather
  /// than deleted. The next container creation then starts from a fresh store.
  private static func moveStoreAside(at storeURL: URL) {
    let manager = FileManager.default
    let stamp = "corrupt-\(Int(Date.now.timeIntervalSince1970))"
    let files = [storeURL, appendingSuffix(storeURL, "-wal"), appendingSuffix(storeURL, "-shm")]
    for url in files where manager.fileExists(atPath: url.path) {
      try? manager.moveItem(at: url, to: appendingSuffix(url, ".\(stamp)"))
    }
  }

  /// A URL whose last path component has `suffix` appended verbatim, for the SQLite
  /// sidecar files (`store-wal` / `store-shm`) and the timestamped corrupt copy.
  private static func appendingSuffix(_ url: URL, _ suffix: String) -> URL {
    URL(fileURLWithPath: url.path + suffix)
  }
}
