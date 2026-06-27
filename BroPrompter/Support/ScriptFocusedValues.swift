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
}

// MARK: - SelectedScriptIDKey

private struct SelectedScriptIDKey: FocusedValueKey {
  typealias Value = Binding<UUID?>
}

// MARK: - PendingDeleteScriptIDKey

private struct PendingDeleteScriptIDKey: FocusedValueKey {
  typealias Value = Binding<UUID?>
}
