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
    do {
      return try ModelContainer(for: schema, configurations: [configuration(for: schema)])
    } catch {
      fatalError("Failed to create the scripts ModelContainer: \(error)")
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
}
