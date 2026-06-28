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

      readingSizeRow

      bodyCard

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

  /// The per-script reading-size control (prototype Editor 4339:14482): an
  /// "Aa" glyph, a slider bound to `Script.fontSize` (24-120 pt, DESIGN.md 3.3),
  /// and the current value. This is the size the teleprompter reads, so it is a
  /// display setting and does not bump `updatedAt`.
  private var readingSizeRow: some View {
    HStack(spacing: 12) {
      Image(systemName: "textformat.size")
        .foregroundStyle(.secondary)
      Text("Reading size")
        .foregroundStyle(.secondary)
      Slider(value: $script.fontSize, in: 24 ... 120, step: 1)
      Text("\(Int(script.fontSize)) pt")
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(width: 56, alignment: .trailing)
    }
    .font(.callout)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Reading size")
    .accessibilityValue("\(Int(script.fontSize)) points")
    .accessibilityIdentifier("editorReadingSize")
  }

  /// The body editor in a bordered rounded card (prototype Editor 4339:14482),
  /// rather than a bare editor (DESIGN.md 4.1 / 5).
  private var bodyCard: some View {
    TextEditor(text: bodyBinding)
      .font(.body)
      .scrollContentBackground(.hidden)
      .padding(8)
      .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(Color(nsColor: .separatorColor))
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 8)
      .accessibilityLabel("Script body")
      .accessibilityIdentifier("scriptBodyEditor")
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
