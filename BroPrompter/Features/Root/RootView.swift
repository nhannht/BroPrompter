import SwiftData
import SwiftUI

/// App shell. A `NavigationSplitView` with the script library sidebar and the
/// editor detail. It owns the library selection (persisted across launches and
/// shared with the menu commands) and the delete-confirmation alert, and it
/// still hosts the in-context camera permission flow from P0: access is
/// requested only when the user starts the teleprompter, never at launch
/// (GUIDELINES.md 1.1).
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
      ScriptEditorView(script: selectedScript, startTeleprompter: startCameraFlow)
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
    .sheet(item: $flow) { flow in
      switch flow {
      case .prePrompt(let feature):
        PermissionPrePromptView(feature: feature) { granted in
          self.flow = granted ? nil : .denied(feature)
        } onCancel: {
          self.flow = nil
        }

      case .denied(let feature):
        PermissionDeniedView(feature: feature) {
          self.flow = nil
        }
      }
    }
  }

  // MARK: Private

  /// Drives the permission sheet: either the explainer or the denied state.
  private enum PermissionFlow: Identifiable {
    case prePrompt(PermissionFeature)
    case denied(PermissionFeature)

    var id: String {
      switch self {
      case .prePrompt(let feature): "prePrompt-\(feature.id)"
      case .denied(let feature): "denied-\(feature.id)"
      }
    }
  }

  @Environment(PermissionManager.self) private var permissions
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Script.updatedAt, order: .reverse)
  private var scripts: [Script]

  @SceneStorage("selectedScriptID") private var selectedScriptRaw = ""
  @State private var pendingDeleteID: UUID?
  @State private var flow: PermissionFlow?

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

  /// Routes to the correct permission step based on the current status.
  private func startCameraFlow() {
    let feature = PermissionFeature.camera
    switch permissions.status(for: feature) {
    case .authorized:
      // Access already granted. The teleprompter opens here in P3.
      flow = nil
    case .notDetermined:
      flow = .prePrompt(feature)
    case .denied, .restricted:
      flow = .denied(feature)
    @unknown default:
      flow = .prePrompt(feature)
    }
  }
}
