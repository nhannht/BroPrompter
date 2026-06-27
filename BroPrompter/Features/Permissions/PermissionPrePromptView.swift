import SwiftUI

/// In-context explainer shown before the system permission dialog. Pairs the
/// benefit copy with the request, raising grant rates (GUIDELINES.md 1.1).
struct PermissionPrePromptView: View {

  // MARK: Internal

  let feature: PermissionFeature
  /// Called with the system dialog's result after the user taps Enable.
  var onResult: (Bool) -> Void
  /// Called when the user declines the pre-prompt without requesting access.
  var onCancel: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(Color.accentColor)
          .frame(width: 72, height: 72)
        Image(systemName: feature.systemImage)
          .font(.system(size: 30))
          .foregroundStyle(.white)
      }
      .accessibilityHidden(true)

      Text(feature.title)
        .font(.title2)
        .fontWeight(.semibold)

      Text(feature.prePromptMessage)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 12) {
        Button("Not Now", action: onCancel)
          .buttonStyle(.bordered)

        Button(feature.enableButtonTitle) {
          Task {
            isRequesting = true
            let granted = await permissions.request(feature)
            isRequesting = false
            onResult(granted)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRequesting)
      }
    }
    .padding(32)
    .frame(width: 440)
    .accessibilityElement(children: .contain)
  }

  // MARK: Private

  @Environment(PermissionManager.self) private var permissions
  @State private var isRequesting = false

}
