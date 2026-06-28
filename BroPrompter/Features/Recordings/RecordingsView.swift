import SwiftData
import SwiftUI

// MARK: - RecordingsView

/// The recordings browser (BROP-7, prototype H5): a full-window screen reached
/// from the Library toolbar, listing every take most-recent-first with a thumbnail,
/// name, resolution/duration, recorded date, and per-row play / share. Export,
/// re-record, and delete live in the row context menu (delete behind a confirm,
/// GUIDELINES.md 2.2 / 4). Selecting a take opens its Take Review.
struct RecordingsView: View {

  // MARK: Internal

  let onBack: () -> Void
  let onOpen: (Take) -> Void

  var body: some View {
    let rows = RecordingsList.rows(for: takes, now: Date())

    VStack(alignment: .leading, spacing: 0) {
      header(rows)
      Divider()
      if rows.isEmpty {
        emptyState
      } else {
        columnHeader
        list(rows)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .navigationTitle("Recordings")
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Button(action: onBack) {
          Label("Library", systemImage: "chevron.left")
        }
        .keyboardShortcut("[", modifiers: .command)
        .help("Back to the script library")
        .accessibilityIdentifier("recordingsBack")
      }
    }
    .alert(
      "Delete take?",
      isPresented: deleteAlertPresented,
      presenting: pendingDelete
    ) { take in
      Button("Delete", role: .destructive) { confirmDelete(take) }
      Button("Cancel", role: .cancel) { pendingDelete = nil }
    } message: { take in
      Text("\"\(name(of: take, in: rows))\" and its recording will be permanently deleted.")
    }
  }

  // MARK: Private

  private static let recordedColumnWidth: CGFloat = 150
  private static let actionsColumnWidth: CGFloat = 76
  private static let rowInsets = EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)

  @Environment(\.modelContext) private var modelContext
  @Environment(\.openWindow) private var openWindow

  @Query(sort: \Take.createdAt, order: .reverse)
  private var takes: [Take]
  @State private var pendingDelete: Take?
  @State private var selection: UUID?

  private var deleteAlertPresented: Binding<Bool> {
    Binding(
      get: { pendingDelete != nil },
      set: { presented in if !presented { pendingDelete = nil } }
    )
  }

  private var columnHeader: some View {
    HStack(spacing: 0) {
      Text("NAME")
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("RECORDED")
        .frame(width: Self.recordedColumnWidth, alignment: .trailing)
      Text("ACTIONS")
        .frame(width: Self.actionsColumnWidth, alignment: .trailing)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 20)
    .padding(.vertical, 6)
  }

  private var emptyState: some View {
    ContentUnavailableView(
      "No Recordings",
      systemImage: "video.slash",
      description: Text("Record a take from the teleprompter and it shows up here.")
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func header(_ rows: [RecordingsList.Row]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Recordings")
        .font(.largeTitle.bold())
      Text(summary(rows))
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 12)
  }

  private func list(_ rows: [RecordingsList.Row]) -> some View {
    List(selection: $selection) {
      ForEach(rows) { row in
        rowView(row)
          .tag(row.id)
          .listRowInsets(Self.rowInsets)
          .contextMenu { rowMenu(row) }
      }
    }
    .listStyle(.inset)
  }

  private func rowView(_ row: RecordingsList.Row) -> some View {
    HStack(spacing: 0) {
      HStack(spacing: 12) {
        thumbnail(row)
        VStack(alignment: .leading, spacing: 2) {
          Text(row.displayName)
            .font(.headline)
          Text(row.subtitle)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .onTapGesture(count: 2) { onOpen(row.take) }

      Text(row.recorded)
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(width: Self.recordedColumnWidth, alignment: .trailing)

      rowActions(row)
        .frame(width: Self.actionsColumnWidth, alignment: .trailing)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(row.displayName), \(row.subtitle), \(row.recorded)")
  }

  private func thumbnail(_ row: RecordingsList.Row) -> some View {
    Button { onOpen(row.take) } label: {
      RoundedRectangle(cornerRadius: 6)
        .fill(Color.black.opacity(0.85))
        .frame(width: 64, height: 40)
        .overlay {
          Image(systemName: row.take.mode == .video ? "play.fill" : "waveform")
            .foregroundStyle(.white)
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Play \(row.displayName)")
    .accessibilityIdentifier("recordingThumbnail")
  }

  private func rowActions(_ row: RecordingsList.Row) -> some View {
    HStack(spacing: 14) {
      Button { onOpen(row.take) } label: {
        Image(systemName: "play.fill")
      }
      .help("Play")
      .minimumHitTarget()
      .accessibilityLabel("Play \(row.displayName)")

      ShareLink(item: row.take.fileURL) {
        Image(systemName: "square.and.arrow.up")
      }
      .help("Share")
      .minimumHitTarget()
      .accessibilityLabel("Share \(row.displayName)")
    }
    .buttonStyle(.borderless)
  }

  @ViewBuilder
  private func rowMenu(_ row: RecordingsList.Row) -> some View {
    Button("Play") { onOpen(row.take) }
    Button("Export...") { TakeExporter.exportCopy(of: row.take.fileURL, suggestedName: row.displayName) }
    ShareLink("Share", item: row.take.fileURL)
    if row.take.scriptID != nil {
      Button("Re-record") { reRecord(row.take) }
    }
    Divider()
    Button("Delete", role: .destructive) { pendingDelete = row.take }
  }

  private func summary(_ rows: [RecordingsList.Row]) -> String {
    let bytes = rows.reduce(into: Int64(0)) { total, row in
      total += fileSize(of: row.take)
    }
    guard bytes > 0 else { return RecordingsList.countLabel(rows.count) }
    return "\(RecordingsList.countLabel(rows.count))    \(RecordingsList.sizeLabel(bytes))"
  }

  private func fileSize(of take: Take) -> Int64 {
    let values = try? take.fileURL.resourceValues(forKeys: [.fileSizeKey])
    return Int64(values?.fileSize ?? 0)
  }

  private func name(of take: Take, in rows: [RecordingsList.Row]) -> String {
    rows.first { $0.id == take.id }?.displayName ?? "This take"
  }

  private func reRecord(_ take: Take) {
    guard let scriptID = take.scriptID else { return }
    openWindow(id: "teleprompter", value: scriptID)
  }

  private func confirmDelete(_ take: Take) {
    TakeStore.delete(take, in: modelContext)
    pendingDelete = nil
  }
}
