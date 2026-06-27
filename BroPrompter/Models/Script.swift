import Foundation
import SwiftData

// MARK: - Script

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

  /// Teleprompter reading-surface settings, persisted per script (DESIGN.md 3.3):
  /// the reading font size in points and the auto-scroll speed in points/second.
  /// Both keep CloudKit-safe defaults so sync can be turned on later (BROP-27)
  /// without a migration.
  var fontSize = 48.0
  var scrollSpeed = 60.0
}

// MARK: - Import

extension Script {
  /// Builds a script imported from a text file: the title is the file name
  /// without its extension, the body is the file's contents. Pure (no disk
  /// access) so it can be unit-tested with a synthesized URL and literal text.
  static func imported(from url: URL, contents: String) -> Script {
    Script(title: url.deletingPathExtension().lastPathComponent, body: contents)
  }
}
