import SwiftUI

// MARK: - PlaybackCommands

/// The teleprompter "Playback" menu (GUIDELINES.md 5.1), placed before Window.
/// It mirrors every transport action with its keyboard shortcut so the shortcuts
/// are discoverable, and it is the canonical home for them: the control buttons no
/// longer carry the shortcuts, so there is no duplicate key equivalent.
///
/// Each item reads the key teleprompter window's commands through a focused scene
/// value and is disabled when no teleprompter is focused. A disabled menu item
/// does not fire its key equivalent, so the bare-key shortcuts (Space, `-`, `+`,
/// `c`, `r`, arrows) go idle while the library window is key and never swallow
/// typing in the script editor (BROP-38).
struct PlaybackCommands: Commands {

  // MARK: Internal

  var body: some Commands {
    CommandMenu("Playback") {
      Button(commands?.isPlaying == true ? "Pause" : "Play") { commands?.togglePlay() }
        .keyboardShortcut(.space, modifiers: [])
        .disabled(commands == nil)

      Button("Restart from Top") { commands?.restart() }
        .disabled(commands == nil)

      Divider()

      Button("Slower") { commands?.slower() }
        .keyboardShortcut("-", modifiers: [])
        .disabled(commands == nil)

      Button("Faster") { commands?.faster() }
        .keyboardShortcut("+", modifiers: [])
        .disabled(commands == nil)

      Divider()

      Button("Smaller Text") { commands?.smallerFont() }
        .keyboardShortcut("-", modifiers: .command)
        .disabled(commands == nil)

      Button("Larger Text") { commands?.largerFont() }
        .keyboardShortcut("+", modifiers: .command)
        .disabled(commands == nil)

      Divider()

      Button("Scrub Up") { commands?.scrubLineUp() }
        .keyboardShortcut(.upArrow, modifiers: [])
        .disabled(commands == nil)

      Button("Scrub Down") { commands?.scrubLineDown() }
        .keyboardShortcut(.downArrow, modifiers: [])
        .disabled(commands == nil)

      Button("Page Back") { commands?.pageBack() }
        .keyboardShortcut(.leftArrow, modifiers: [])
        .disabled(commands == nil)

      Button("Page Forward") { commands?.pageForward() }
        .keyboardShortcut(.rightArrow, modifiers: [])
        .disabled(commands == nil)

      Divider()

      Button("Toggle Camera") { commands?.toggleCamera() }
        .keyboardShortcut("c", modifiers: [])
        .disabled(commands == nil || commands?.canToggleCamera == false)

      Button(commands?.isCapturing == true ? "Stop Recording" : "Start Recording") {
        commands?.toggleRecord()
      }
      .keyboardShortcut("r", modifiers: [])
      .disabled(commands == nil || commands?.canToggleRecord == false)

      Divider()

      Button(commands?.isFullScreen == true ? "Exit Full Screen" : "Enter Full Screen") {
        commands?.toggleFullScreen()
      }
      .keyboardShortcut(.return, modifiers: .command)
      .disabled(commands == nil)
    }
  }

  // MARK: Private

  @FocusedValue(\.teleprompterCommands) private var commands

}
