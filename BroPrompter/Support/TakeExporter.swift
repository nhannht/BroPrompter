import AppKit
import UniformTypeIdentifiers

/// Exports a copy of a take to a location the user picks (BROP-7). `NSSavePanel`
/// grants write access to the chosen destination through the sandbox powerbox, so
/// no broad file access is needed beyond `files.user-selected.read-write`.
///
/// This is only the explicit "Export a copy" path; sharing uses SwiftUI
/// `ShareLink` at the call site.
enum TakeExporter {
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
    try? FileManager.default.removeItem(at: destination)
    try? FileManager.default.copyItem(at: source, to: destination)
  }
}
