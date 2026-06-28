import SwiftUI

/// Shown when a capability is denied or restricted. Explains what is unavailable
/// and links to System Settings so the user can re-enable it (GUIDELINES.md 1.1).
struct PermissionDeniedView: View {

  // MARK: Internal

  let feature: PermissionFeature
  var onClose: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(.orange)
          .frame(width: 72, height: 72)
        Image(systemName: feature.systemImage)
          .font(.system(size: 30))
          .foregroundStyle(.white)
      }
      .accessibilityHidden(true)

      Text(feature.title)
        .font(.title2)
        .fontWeight(.semibold)

      Text(feature.deniedMessage)
        .font(.body)
        // Instructional copy uses the primary label color to clear 4.5:1 (BROP-23).
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 12) {
        Button("Not Now", action: onClose)
          .buttonStyle(.bordered)

        Button("Open Settings") {
          permissions.openSystemSettings(for: feature)
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(32)
    .frame(width: 440)
    .accessibilityElement(children: .contain)
  }

  // MARK: Private

  @Environment(PermissionManager.self) private var permissions

}
