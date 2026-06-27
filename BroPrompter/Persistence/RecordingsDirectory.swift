import AppKit
import Foundation

/// The folder that holds recorded take files, inside the app's sandbox container
/// (BROP-6). Created on demand. Takes store only their relative file name and
/// resolve to a URL through here.
enum RecordingsDirectory {
  /// The recordings folder under Application Support, created if needed.
  static var url: URL {
    let directory = URL.applicationSupportDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// The on-disk location for a take's file name.
  static func fileURL(forName name: String) -> URL {
    url.appending(path: name)
  }

  /// Opens Finder with the file selected, the P4 "confirm the result" path
  /// (GUIDELINES.md 2.2). The full recordings browser arrives in P5 (BROP-7).
  static func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}
