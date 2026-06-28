import Foundation
import SwiftUI

/// Focused scene values that bridge the menu-bar commands to the active window's
/// state (GUIDELINES.md 5.1). `RootView` publishes these with
/// `.focusedSceneValue`; `AppCommands` reads them with `@FocusedValue`.
extension FocusedValues {
  /// The selection in the active window's script library.
  var selectedScriptID: Binding<UUID?>? {
    get { self[SelectedScriptIDKey.self] }
    set { self[SelectedScriptIDKey.self] = newValue }
  }

  /// The script the active window has been asked to delete. Setting it makes
  /// the window present its confirmation alert.
  var pendingDeleteScriptID: Binding<UUID?>? {
    get { self[PendingDeleteScriptIDKey.self] }
    set { self[PendingDeleteScriptIDKey.self] = newValue }
  }

  /// The active window's top-level route, so the Go menu can navigate between the
  /// library and the recordings browser (BROP-7).
  var rootRoute: Binding<AppRoute>? {
    get { self[RootRouteKey.self] }
    set { self[RootRouteKey.self] = newValue }
  }

  /// The key teleprompter window's transport commands, or `nil` when no
  /// teleprompter is focused. The Playback menu reads this and disables itself
  /// (so its bare-key shortcuts go idle) when it is `nil` (BROP-38).
  var teleprompterCommands: TeleprompterCommands? {
    get { self[TeleprompterCommandsKey.self] }
    set { self[TeleprompterCommandsKey.self] = newValue }
  }
}

// MARK: - TeleprompterCommands

/// The teleprompter window's transport actions and current state, published as a
/// focused scene value so the Playback menu (`PlaybackCommands`) can drive the key
/// teleprompter window (GUIDELINES.md 5.1). The reader republishes this each body
/// pass, so the menu's labels (Play vs Pause, Enter vs Exit Full Screen) and
/// enablement track the live state. The closures forward to the reader's own
/// methods; no transport logic is duplicated here.
struct TeleprompterCommands {
  var isPlaying: Bool
  var isCapturing: Bool
  var isFullScreen: Bool
  var canToggleCamera: Bool
  var canToggleRecord: Bool

  var togglePlay: () -> Void
  var restart: () -> Void
  var faster: () -> Void
  var slower: () -> Void
  var largerFont: () -> Void
  var smallerFont: () -> Void
  var scrubLineUp: () -> Void
  var scrubLineDown: () -> Void
  var pageBack: () -> Void
  var pageForward: () -> Void
  var toggleCamera: () -> Void
  var toggleRecord: () -> Void
  var toggleFullScreen: () -> Void
}

// MARK: - SelectedScriptIDKey

private struct SelectedScriptIDKey: FocusedValueKey {
  typealias Value = Binding<UUID?>
}

// MARK: - PendingDeleteScriptIDKey

private struct PendingDeleteScriptIDKey: FocusedValueKey {
  typealias Value = Binding<UUID?>
}

// MARK: - RootRouteKey

private struct RootRouteKey: FocusedValueKey {
  typealias Value = Binding<AppRoute>
}

// MARK: - TeleprompterCommandsKey

private struct TeleprompterCommandsKey: FocusedValueKey {
  typealias Value = TeleprompterCommands
}
