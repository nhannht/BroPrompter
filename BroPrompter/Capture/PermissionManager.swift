import AVFoundation
import AppKit
import Observation

/// Single source of truth for camera and microphone authorization. Wraps the
/// AVFoundation APIs and the System Settings recovery path (GUIDELINES.md 1.3).
@MainActor
@Observable
final class PermissionManager {
    /// Current authorization status for a feature, read straight from the system.
    func status(for feature: PermissionFeature) -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: feature.mediaType)
    }

    /// Triggers the system permission dialog. Call only after showing the
    /// in-context pre-prompt explainer. Returns whether access was granted.
    func request(_ feature: PermissionFeature) async -> Bool {
        await AVCaptureDevice.requestAccess(for: feature.mediaType)
    }

    /// Opens the relevant System Settings privacy pane after a denial. The app
    /// cannot re-prompt once denied; only the user can re-enable access here.
    func openSystemSettings(for feature: PermissionFeature) {
        guard let url = URL(string: feature.settingsURLString) else { return }
        NSWorkspace.shared.open(url)
    }
}
