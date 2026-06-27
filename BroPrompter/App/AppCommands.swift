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

      Button("Play in Teleprompter") { }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(true)
    }
  }

  // MARK: Private

  @FocusedValue(\.selectedScriptID) private var selectedScriptID
  @FocusedValue(\.pendingDeleteScriptID) private var pendingDeleteScriptID

  @MainActor
  private var context: ModelContext {
    ScriptStore.container.mainContext
  }

  /// During UI tests (BROP-30), import from injected environment values rather
  /// than the open panel, which the App Sandbox would block for a path the user
  /// never granted.
  private static func uiTestImportedScript() -> Script? {
    let environment = ProcessInfo.processInfo.environment
    guard let title = environment["UITEST_IMPORT_TITLE"] else { return nil }
    return Script(title: title, body: environment["UITEST_IMPORT_BODY"] ?? "")
  }

  @MainActor
  private func createScript() {
    let script = Script()
    context.insert(script)
    selectedScriptID?.wrappedValue = script.id
  }

  @MainActor
  private func importTextFile() {
    if let injected = Self.uiTestImportedScript() {
      context.insert(injected)
      selectedScriptID?.wrappedValue = injected.id
      return
    }

    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.plainText]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return }

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
