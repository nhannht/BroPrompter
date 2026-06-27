import SwiftUI

@main
struct BroPrompterApp: App {
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

    Settings {
      SettingsView()
    }
  }

  @State private var permissions = PermissionManager()

}
