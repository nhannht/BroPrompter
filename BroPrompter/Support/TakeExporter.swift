import AppKit
import UniformTypeIdentifiers

/// Exports a copy of a take to a location the user picks (BROP-7). `NSSavePanel`
/// grants write access to the chosen destination through the sandbox powerbox, so
/// no broad file access is needed beyond `files.user-selected.read-write`.
///
/// This is only the explicit "Export a copy" path; sharing uses SwiftUI
/// `ShareLink` at the call site.
enum TakeExporter {

  // MARK: Internal

  /// Presents a save panel (defaulting to the user's Movies folder) and copies
  /// the take file to the chosen destination. Does nothing if the user cancels.
  @MainActor
  static func exportCopy(of source: URL, suggestedName: String) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "\(suggestedName).\(source.pathExtension)"
    panel.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
    if let type = UTType(filenameExtension: source.pathExtension) {
      panel.allowedContentTypes = [type]
    }
    panel.canCreateDirectories = true

    guard panel.runModal() == .OK, let destination = panel.url else { return }
    do {
      try writeCopy(of: source, to: destination)
    } catch {
      presentError(error)
    }
  }

  // MARK: Private

  /// Copies `source` to `destination`. When the destination already exists the
  /// copy lands in a sibling temporary file and is then swapped in atomically, so
  /// a failed copy never destroys the user's existing file (the save panel's
  /// "Replace?" path). A brand-new destination is copied directly, so there is
  /// nothing to lose if it fails.
  private static func writeCopy(of source: URL, to destination: URL) throws {
    let manager = FileManager.default
    guard manager.fileExists(atPath: destination.path) else {
      try manager.copyItem(at: source, to: destination)
      return
    }
    let temporary = destination
      .deletingLastPathComponent()
      .appendingPathComponent("\(UUID().uuidString).\(destination.pathExtension)")
    do {
      try manager.copyItem(at: source, to: temporary)
      _ = try manager.replaceItemAt(destination, withItemAt: temporary)
    } catch {
      try? manager.removeItem(at: temporary)
      throw error
    }
  }

  /// Reports an export failure to the user instead of failing silently.
  @MainActor
  private static func presentError(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = "Export Failed"
    alert.informativeText = error.localizedDescription
    alert.alertStyle = .warning
    alert.runModal()
  }
}
