import SwiftData
import SwiftUI

// MARK: - AppRoute

/// The active top-level screen in the main window (BROP-7). Library is the
/// default; Recordings and Take Review replace the whole window to match the
/// prototype's full-window navigation (back through the in-window chrome).
enum AppRoute {
  case library
  case recordings
  case takeReview(Take)
  case trim(Take)
}

// MARK: - RootView

/// App shell. A `NavigationSplitView` with the script library sidebar and the
/// editor detail, plus the full-window Recordings and Take Review screens routed
/// in from the Library toolbar (BROP-7). It owns the library selection (persisted
/// across launches and shared with the menu commands) and the delete-confirmation
/// alert. Playing a script opens the text teleprompter in its own window (BROP-4);
/// the P0 camera permission flow is re-attached to an in-teleprompter toggle in
/// P3 (BROP-5).
struct RootView: View {

  // MARK: Internal

  var body: some View {
    Group {
      switch route {
      case .library:
        libraryScreen

      case .recordings:
        RecordingsView(
          onBack: { route = .library },
          onOpen: { route = .takeReview($0) }
        )

      case .takeReview(let take):
        takeReviewScreen(take)

      case .trim(let take):
        TrimEditorView(
          take: take,
          onCancel: { route = .takeReview(take) },
          onSaved: { route = .takeReview($0) }
        )
      }
    }
    .focusedSceneValue(\.rootRoute, $route)
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Script.updatedAt, order: .reverse)
  private var scripts: [Script]

  @SceneStorage("selectedScriptID") private var selectedScriptRaw = ""
  @State private var pendingDeleteID: UUID?
  @State private var route = AppRoute.library

  /// The default Library screen: the script sidebar and editor, with a toolbar
  /// entry into the recordings browser.
  private var libraryScreen: some View {
    NavigationSplitView {
      ScriptSidebar(
        scripts: scripts,
        selection: selectionBinding,
        requestDelete: { pendingDeleteID = $0 }
      )
    } detail: {
      ScriptEditorView(script: selectedScript)
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Recordings") { route = .recordings }
          .help("Browse recordings")
          .accessibilityIdentifier("libraryRecordings")
      }
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

  private func takeReviewScreen(_ take: Take) -> some View {
    TakeReviewView(
      take: take,
      onBack: { route = .recordings },
      onDone: { route = .library },
      onTrim: { route = .trim(take) },
      onDeleted: { route = .recordings }
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
