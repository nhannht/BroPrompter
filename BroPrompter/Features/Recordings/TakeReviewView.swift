import AVKit
import SwiftData
import SwiftUI

/// The single-take review screen (BROP-7, prototype H4): a full-window AVKit
/// player with the take's metadata and next actions (re-record, share, export,
/// delete). Reached from the Recordings list; "All Takes" returns there and
/// "Done" returns to the library. Delete is confirmed and removes both the file
/// and the record (GUIDELINES.md 2.2 / 4). Trim is tracked separately (BROP-35).
struct TakeReviewView: View {

  // MARK: Internal

  let take: Take
  let onBack: () -> Void
  let onDone: () -> Void
  let onTrim: () -> Void
  let onDeleted: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      playerArea
      Text(detail)
        .font(.callout)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("takeReviewDetail")
      actions
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationTitle("Review Take")
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Button(action: onBack) {
          Label("All Takes", systemImage: "chevron.left")
        }
        .keyboardShortcut("[", modifiers: .command)
        .help("Back to all takes")
        .accessibilityIdentifier("takeReviewBack")
      }
      ToolbarItem(placement: .principal) {
        Text(title)
          .font(.headline)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Done", action: onDone)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("takeReviewDone")
      }
    }
    .alert("Delete take?", isPresented: $showDeleteConfirm) {
      Button("Delete", role: .destructive) { deleteTake() }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("\"\(displayName)\" and its recording will be permanently deleted.")
    }
    .task(id: take.id) { loadPlayer() }
    .onDisappear { player?.pause() }
  }

  // MARK: Private

  @Environment(\.modelContext) private var modelContext
  @Environment(\.openWindow) private var openWindow

  @Query(sort: \Take.createdAt)
  private var takes: [Take]
  @Query private var scripts: [Script]

  @State private var player: AVPlayer?
  @State private var showDeleteConfirm = false

  private var playerArea: some View {
    ZStack {
      if let player {
        VideoPlayer(player: player)
      } else {
        Color.black
      }
      if take.mode == .audio {
        Image(systemName: "waveform")
          .font(.system(size: 64))
          .foregroundStyle(.white.opacity(0.7))
          .allowsHitTesting(false)
      }
    }
    .aspectRatio(16.0 / 9.0, contentMode: .fit)
    .clipShape(.rect(cornerRadius: 12))
    .frame(maxWidth: 900)
  }

  private var actions: some View {
    HStack(spacing: 12) {
      if take.scriptID != nil {
        Button("Re-record", action: reRecord)
          .accessibilityIdentifier("takeReviewReRecord")
      }
      Button("Trim", action: onTrim)
        .accessibilityIdentifier("takeReviewTrim")
      ShareLink(item: take.fileURL) {
        Text("Share")
      }
      .accessibilityIdentifier("takeReviewShare")
      Button("Export...", action: export)
        .accessibilityIdentifier("takeReviewExport")
      Button("Delete", role: .destructive) { showDeleteConfirm = true }
        .tint(.red)
        .accessibilityIdentifier("takeReviewDelete")
    }
    .controlSize(.large)
  }

  /// This take's 1-based position among takes of the same mode, oldest first.
  private var ordinal: Int {
    takes.filter { $0.mode == take.mode && $0.createdAt <= take.createdAt }.count
  }

  private var displayName: String {
    RecordingsList.displayName(for: take, ordinal: ordinal)
  }

  private var detail: String {
    RecordingsList.reviewDetail(for: take, ordinal: ordinal, now: Date())
  }

  private var title: String {
    guard
      let scriptID = take.scriptID,
      let script = scripts.first(where: { $0.id == scriptID }),
      !script.title.isEmpty
    else { return "Review Take" }
    return "Review Take - \(script.title)"
  }

  private func loadPlayer() {
    player = AVPlayer(url: take.fileURL)
  }

  private func reRecord() {
    guard let scriptID = take.scriptID else { return }
    openWindow(id: "teleprompter", value: scriptID)
  }

  private func export() {
    TakeExporter.exportCopy(of: take.fileURL, suggestedName: displayName)
  }

  private func deleteTake() {
    player?.pause()
    TakeStore.delete(take, in: modelContext)
    onDeleted()
  }
}
