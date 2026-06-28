import Foundation

// MARK: - TeleprompterExitCommand

/// What the teleprompter's Esc / cancel command should do, resolved by precedence
/// (GUIDELINES.md 2.2 / 3): protect an in-progress take first, then leave full
/// screen rather than closing, and only otherwise dismiss the window. Pure, so the
/// precedence is unit-tested without a running window.
enum TeleprompterExitCommand: Equatable {
  case stopRecording
  case exitFullScreen
  case dismiss

  /// Resolves the Esc action. A recording in progress is stopped first so a take
  /// is never lost to an accidental exit; otherwise full screen is left before the
  /// window is dismissed; otherwise the window is dismissed.
  static func resolve(isRecording: Bool, isFullScreen: Bool) -> TeleprompterExitCommand {
    if isRecording {
      .stopRecording
    } else if isFullScreen {
      .exitFullScreen
    } else {
      .dismiss
    }
  }
}
