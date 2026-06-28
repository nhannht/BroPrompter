import Testing

@testable import BroPrompter

/// Unit tests for the teleprompter Esc precedence (BROP-38): a take in progress is
/// protected first, then full screen is left before the window is dismissed.
@Suite("Teleprompter exit command")
struct TeleprompterExitCommandTests {

  @Test("a take in progress is stopped before anything else")
  func recordingWins() {
    #expect(TeleprompterExitCommand.resolve(isRecording: true, isFullScreen: true) == .stopRecording)
    #expect(TeleprompterExitCommand.resolve(isRecording: true, isFullScreen: false) == .stopRecording)
  }

  @Test("full screen is left before the window is dismissed")
  func fullScreenBeforeDismiss() {
    #expect(TeleprompterExitCommand.resolve(isRecording: false, isFullScreen: true) == .exitFullScreen)
  }

  @Test("a plain window is dismissed")
  func plainDismiss() {
    #expect(TeleprompterExitCommand.resolve(isRecording: false, isFullScreen: false) == .dismiss)
  }
}
