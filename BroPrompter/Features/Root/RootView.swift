import SwiftData
import SwiftUI

/// App shell. A `NavigationSplitView` with the script library sidebar and the
/// editor detail. It owns the library selection (persisted across launches and
/// shared with the menu commands) and the delete-confirmation alert. Playing a
/// script opens the text teleprompter in its own window (BROP-4); the P0 camera
/// permission flow is re-attached to an in-teleprompter toggle in P3 (BROP-5).
struct RootView: View {

  // MARK: Internal

  var body: some View {
    NavigationSplitView {
      ScriptSidebar(
        scripts: scripts,
        selection: selectionBinding,
        requestDelete: { pendingDeleteID = $0 }
      )
    } detail: {
      ScriptEditorView(script: selectedScript)
    }
    .focusedSceneValue(\.selectedScriptID, selectionBinding)
    .focusedSceneValue(\.pendingDeleteScriptID, $pendingDeleteID)
    .alert(
      "Delete script?",
      isPresented: deleteAlertIsPresented,
      presenting: scriptPendingDeletion
    ) { script in
      Button("Delete", role: .destructive) { delete(script) }
      Button("Cancel", role: .cancel) { }
    } message: { script in
      Text("\"\(displayTitle(script))\" will be permanently deleted.")
    }
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Script.updatedAt, order: .reverse)
  private var scripts: [Script]

  @SceneStorage("selectedScriptID") private var selectedScriptRaw = ""
  @State private var pendingDeleteID: UUID?

  /// Bridges the persisted `String` selection to the `UUID?` the list uses.
  private var selectionBinding: Binding<UUID?> {
    Binding(
      get: { selectedScriptRaw.isEmpty ? nil : UUID(uuidString: selectedScriptRaw) },
      set: { selectedScriptRaw = $0?.uuidString ?? "" }
    )
  }

  private var selectedScript: Script? {
    script(for: selectionBinding.wrappedValue)
  }

  private var scriptPendingDeletion: Script? {
    script(for: pendingDeleteID)
  }

  private var deleteAlertIsPresented: Binding<Bool> {
    Binding(
      get: { pendingDeleteID != nil },
      set: { isPresented in if !isPresented { pendingDeleteID = nil } }
    )
  }

  private func script(for id: UUID?) -> Script? {
    guard let id else { return nil }
    return scripts.first { $0.id == id }
  }

  private func displayTitle(_ script: Script) -> String {
    script.title.isEmpty ? "Untitled Script" : script.title
  }

  private func delete(_ script: Script) {
    if script.id == selectionBinding.wrappedValue {
      selectionBinding.wrappedValue = nil
    }
    modelContext.delete(script)
    pendingDeleteID = nil
  }
}
