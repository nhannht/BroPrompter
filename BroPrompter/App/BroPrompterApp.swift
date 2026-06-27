import SwiftUI

@main
struct BroPrompterApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(permissions)
    }
    .defaultSize(width: 1100, height: 720)

    Settings {
      SettingsView()
    }
  }

  @State private var permissions = PermissionManager()

}
