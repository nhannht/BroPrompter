import SwiftData
import SwiftUI

// MARK: - ScriptSidebar

/// The script library sidebar: a searchable, selectable list of scripts with a
/// New button and per-row delete. Selection is owned by `RootView` so it can be
/// persisted across launches and shared with the menu commands (GUIDELINES.md
/// 5.3). Deletion is routed up via `requestDelete` so a single confirmation
/// alert covers both this list and the Script menu.
struct ScriptSidebar: View {

  // MARK: Internal

  let scripts: [Script]
  @Binding var selection: UUID?
  let requestDelete: (UUID) -> Void

  var body: some View {
    List(selection: $selection) {
      ForEach(filteredScripts) { script in
        ScriptRow(script: script)
          .tag(script.id)
          .contextMenu {
            Button("Delete", role: .destructive) {
              requestDelete(script.id)
            }
          }
      }
    }
    .navigationTitle("Scripts")
    .searchable(text: $searchText, placement: .sidebar, prompt: "Search scripts")
    .overlay {
      if scripts.isEmpty {
        ContentUnavailableView(
          "No Scripts",
          systemImage: "doc.text",
          description: Text("Create a script to start writing.")
        )
      }
    }
    .toolbar {
      ToolbarItem {
        Button(action: createScript) {
          Label("New Script", systemImage: "square.and.pencil")
        }
        .help("New script")
      }
    }
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @State private var searchText = ""

  private var filteredScripts: [Script] {
    guard !searchText.isEmpty else { return scripts }
    return scripts.filter { script in
      script.title.localizedCaseInsensitiveContains(searchText)
        || script.body.localizedCaseInsensitiveContains(searchText)
    }
  }

  private func createScript() {
    let script = Script()
    modelContext.insert(script)
    selection = script.id
  }
}

// MARK: - ScriptRow

/// A single library row: the script title over its last-modified date.
private struct ScriptRow: View {
  let script: Script

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(script.title.isEmpty ? "Untitled Script" : script.title)
        .font(.body)
        .lineLimit(1)
      Text(script.updatedAt, format: .dateTime.month().day().hour().minute())
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(script.title.isEmpty ? "Untitled Script" : script.title)
  }
}
