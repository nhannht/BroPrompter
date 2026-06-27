import SwiftUI

/// Placeholder for the Settings scene opened with Cmd-, . Built out in P7
/// (GUIDELINES.md section 5.3: Settings live in a Settings window).
struct SettingsView: View {
    var body: some View {
        Form {
            Text("Settings arrive in a later phase.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 300)
    }
}
