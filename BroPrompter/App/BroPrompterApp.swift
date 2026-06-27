import SwiftUI

@main
struct BroPrompterApp: App {
    @State private var permissions = PermissionManager()

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
}
