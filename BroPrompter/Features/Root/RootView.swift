import SwiftUI

/// App shell. A NavigationSplitView placeholder for the script sidebar + detail
/// area built out in later phases. For P0 it also hosts the in-context camera
/// permission flow: access is requested when the user opens the camera
/// teleprompter, never at launch (GUIDELINES.md 1.1).
struct RootView: View {

  // MARK: Internal

  var body: some View {
    NavigationSplitView {
      List {
        Section("Scripts") {
          Text("No scripts yet")
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("BroPrompter")
      .frame(minWidth: 200)
    } detail: {
      VStack(spacing: 16) {
        Image(systemName: "camera.viewfinder")
          .font(.system(size: 48))
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Text("Camera teleprompter")
          .font(.title2)
        Text("Set up camera access to read while looking at the lens.")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button("Open camera teleprompter", action: startCameraFlow)
          .buttonStyle(.borderedProminent)
      }
      .padding()
    }
    .sheet(item: $flow) { flow in
      switch flow {
      case .prePrompt(let feature):
        PermissionPrePromptView(feature: feature) { granted in
          self.flow = granted ? nil : .denied(feature)
        } onCancel: {
          self.flow = nil
        }

      case .denied(let feature):
        PermissionDeniedView(feature: feature) {
          self.flow = nil
        }
      }
    }
  }

  // MARK: Private

  /// Drives the permission sheet: either the explainer or the denied state.
  private enum PermissionFlow: Identifiable {
    case prePrompt(PermissionFeature)
    case denied(PermissionFeature)

    var id: String {
      switch self {
      case .prePrompt(let feature): "prePrompt-\(feature.id)"
      case .denied(let feature): "denied-\(feature.id)"
      }
    }
  }

  @Environment(PermissionManager.self) private var permissions
  @State private var flow: PermissionFlow?

  /// Routes to the correct step based on the current authorization status.
  private func startCameraFlow() {
    let feature = PermissionFeature.camera
    switch permissions.status(for: feature) {
    case .authorized:
      // Access already granted. The teleprompter opens here in P3.
      flow = nil
    case .notDetermined:
      flow = .prePrompt(feature)
    case .denied, .restricted:
      flow = .denied(feature)
    @unknown default:
      flow = .prePrompt(feature)
    }
  }
}
