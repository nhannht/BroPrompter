import SwiftUI

@main
struct BroPrompterApp: App {

  // MARK: Internal

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(permissions)
    }
    .defaultSize(width: 1100, height: 720)
    .modelContainer(ScriptStore.container)
    .commands {
      AppCommands()
    }

    // The teleprompter reads in its own window so it can go full screen
    // (GUIDELINES.md section 3). It shares the one store; the script is passed
    // by id and re-fetched inside the window.
    WindowGroup(id: "teleprompter", for: UUID.self) { $scriptID in
      TeleprompterView(scriptID: scriptID)
        .environment(permissions)
    }
    .defaultSize(width: 900, height: 700)
    .modelContainer(ScriptStore.container)

    Settings {
      SettingsView()
    }
  }

  // MARK: Private

  @State private var permissions = PermissionManager()

}
