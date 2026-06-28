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
    let script = Preferences.newScript()
    modelContext.insert(script)
    selection = script.id
  }
}

// MARK: - ScriptRow

/// A single library row: the script title over its word count and estimated
/// reading duration (prototype H3 4332:14362, "320 words / 2:08"), at the
/// reading pace from Settings.
private struct ScriptRow: View {

  // MARK: Internal

  let script: Script

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(displayTitle)
        .font(.body)
        .lineLimit(1)
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(displayTitle), \(subtitle)")
  }

  // MARK: Private

  @AppStorage(Preferences.Key.readingWordsPerMinute) private var wordsPerMinute = Preferences.Default.readingWordsPerMinute

  private var displayTitle: String {
    script.title.isEmpty ? "Untitled Script" : script.title
  }

  private var subtitle: String {
    let words = ReadingStats.wordCount(of: script.body)
    let seconds = ReadingStats.readSeconds(of: script.body, wordsPerMinute: wordsPerMinute)
    return "\(words) words / \(TeleprompterEngine.clockString(Double(seconds)))"
  }
}
