import SwiftData
import SwiftUI

// MARK: - ScriptEditorView

/// The detail editor. Shows the selected script's title and plain-text body, or
/// an empty state when nothing is selected. Editing autosaves through SwiftData.
struct ScriptEditorView: View {
  let script: Script?

  var body: some View {
    if let script {
      ScriptEditorContent(script: script)
        // Reset the editor's focus and field state when switching scripts.
        .id(script.id)
    } else {
      ContentUnavailableView(
        "No Script Selected",
        systemImage: "doc.text",
        description: Text("Select a script from the sidebar, or create a new one.")
      )
    }
  }
}

// MARK: - ScriptEditorContent

/// The editing surface for one script. Split out so it can bind to a non-optional
/// `@Bindable` script.
private struct ScriptEditorContent: View {

  // MARK: Internal

  @Bindable var script: Script

  var body: some View {
    VStack(spacing: 0) {
      TextField("Title", text: titleBinding)
        .font(.title2)
        .textFieldStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityLabel("Script title")
        .accessibilityIdentifier("scriptTitleField")

      Divider()

      TextEditor(text: bodyBinding)
        .font(.body)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 12)
        .accessibilityLabel("Script body")
        .accessibilityIdentifier("scriptBodyEditor")

      Divider()

      footer
    }
    .toolbar {
      ToolbarItem {
        Button {
          openWindow(id: "teleprompter", value: script.id)
        } label: {
          Label("Play in Teleprompter", systemImage: "play.fill")
        }
        .help("Play in teleprompter")
      }
    }
  }

  // MARK: Private

  @Environment(\.openWindow) private var openWindow

  @AppStorage(Preferences.Key.readingWordsPerMinute) private var wordsPerMinute = Preferences.Default.readingWordsPerMinute

  private var titleBinding: Binding<String> {
    Binding(
      get: { script.title },
      set: { newValue in
        script.title = newValue
        script.updatedAt = .now
      }
    )
  }

  private var bodyBinding: Binding<String> {
    Binding(
      get: { script.body },
      set: { newValue in
        script.body = newValue
        script.updatedAt = .now
      }
    )
  }

  private var footer: some View {
    HStack {
      Text("\(ReadingStats.wordCount(of: script.body)) words")
        .accessibilityIdentifier("wordCountLabel")
      Spacer()
      Text("~\(ReadingStats.readMinutes(of: script.body, wordsPerMinute: wordsPerMinute)) min")
        .accessibilityIdentifier("readTimeLabel")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal)
    .padding(.vertical, 8)
  }
}
