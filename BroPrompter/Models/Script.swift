import Foundation
import SwiftData

/// A teleprompter script: a title plus the plain-text body the user reads.
///
/// The model is CloudKit-safe by construction so iCloud sync can be turned on
/// later (BROP-27) without a data migration: every attribute has a default and
/// there are no unique constraints. See `ScriptStore` for the container.
@Model
final class Script {

  // MARK: Lifecycle

  init(title: String = "", body: String = "") {
    self.title = title
    self.body = body
    let now = Date.now
    createdAt = now
    updatedAt = now
  }

  // MARK: Internal

  /// Stable identity that also serves as the `SceneStorage` selection key.
  /// Non-unique on purpose: CloudKit cannot enforce uniqueness, so this stays a
  /// plain attribute rather than an `@Attribute(.unique)`.
  var id = UUID()
  var title = ""
  var body = ""
  var createdAt = Date.now
  var updatedAt = Date.now
}
