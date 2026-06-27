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
  /// The shared scripts container.
  static let container: ModelContainer = {
    let schema = Schema([Script.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    // CloudKit flip later (BROP-27):
    // ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
    do {
      return try ModelContainer(for: schema, configurations: [configuration])
    } catch {
      fatalError("Failed to create the scripts ModelContainer: \(error)")
    }
  }()
}
