import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Menu-bar commands for the script library (GUIDELINES.md 5.1/5.2): standard
/// File menu entries plus a Script menu, each mirrored by a keyboard shortcut.
/// Commands act on the shared `ScriptStore` context and reach the active
/// window's selection through focused scene values published by `RootView`.
struct AppCommands: Commands {

  // MARK: Internal

  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      Button("New Script", action: createScript)
        .keyboardShortcut("n")

      Button("Import Text File...", action: importTextFile)
        .keyboardShortcut("i", modifiers: [.command, .shift])
    }

    CommandGroup(replacing: .saveItem) {
      Button("Save", action: save)
        .keyboardShortcut("s")
    }

    CommandMenu("Script") {
      Button("Delete Script", action: requestDeleteSelected)
        .keyboardShortcut(.delete, modifiers: .command)
        .disabled(selectedScriptID?.wrappedValue == nil)

      Divider()

      Button("Play in Teleprompter", action: playInTeleprompter)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(selectedScriptID?.wrappedValue == nil)
    }

    CommandMenu("Go") {
      Button("Library") { rootRoute?.wrappedValue = .library }
        .keyboardShortcut("l", modifiers: [.command, .shift])
        .disabled(rootRoute == nil)

      Button("Recordings") { rootRoute?.wrappedValue = .recordings }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .disabled(rootRoute == nil)
    }
  }

  // MARK: Private

  @Environment(\.openWindow) private var openWindow

  @FocusedValue(\.selectedScriptID) private var selectedScriptID
  @FocusedValue(\.pendingDeleteScriptID) private var pendingDeleteScriptID
  @FocusedValue(\.rootRoute) private var rootRoute

  @MainActor
  private var context: ModelContext {
    ScriptStore.container.mainContext
  }

  /// Reads a plain-text file without assuming UTF-8: tries the encoding the file
  /// declares (BOM or extended attribute), then UTF-8, then ISO Latin-1, which
  /// maps every byte. So a valid non-UTF-8 text file imports instead of silently
  /// doing nothing (BROP-41).
  private static func readText(at url: URL) -> String? {
    var usedEncoding = String.Encoding.utf8
    if let detected = try? String(contentsOf: url, usedEncoding: &usedEncoding) {
      return detected
    }
    if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
      return utf8
    }
    return try? String(contentsOf: url, encoding: .isoLatin1)
  }

  @MainActor
  private func createScript() {
    let script = Preferences.newScript()
    context.insert(script)
    selectedScriptID?.wrappedValue = script.id
  }

  /// Opens the selected script in the teleprompter window (BROP-4). Text only:
  /// no camera permission is needed to read (the camera background lands in P3).
  private func playInTeleprompter() {
    guard let id = selectedScriptID?.wrappedValue else { return }
    openWindow(id: "teleprompter", value: id)
  }

  @MainActor
  private func importTextFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.plainText]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    guard let contents = Self.readText(at: url) else { return }

    let script = Script.imported(from: url, contents: contents)
    context.insert(script)
    selectedScriptID?.wrappedValue = script.id
  }

  @MainActor
  private func save() {
    try? context.save()
  }

  private func requestDeleteSelected() {
    pendingDeleteScriptID?.wrappedValue = selectedScriptID?.wrappedValue
  }
}
