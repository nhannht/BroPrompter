import AVFoundation

/// A capability that BroPrompter must request from the user, with the copy and
/// system routing for its in-context permission flow (GUIDELINES.md section 1).
enum PermissionFeature: String, Identifiable, CaseIterable {
    case camera
    case microphone

    var id: String { rawValue }

    /// The AVFoundation media type whose authorization status this feature maps to.
    var mediaType: AVMediaType {
        switch self {
        case .camera: return .video
        case .microphone: return .audio
        }
    }

    /// SF Symbol shown in the pre-prompt and denied cards.
    var systemImage: String {
        switch self {
        case .camera: return "camera"
        case .microphone: return "mic"
        }
    }

    var title: String {
        switch self {
        case .camera: return "Camera Access"
        case .microphone: return "Microphone Access"
        }
    }

    /// In-context explainer shown before the system dialog. Mirrors the
    /// Info.plist usage string so the benefit reads the same in both places.
    var prePromptMessage: String {
        switch self {
        case .camera:
            return "BroPrompter shows the camera behind your script so you can read while looking at the lens, and records video takes."
        case .microphone:
            return "BroPrompter records your voice for audio and video takes."
        }
    }

    var enableButtonTitle: String {
        switch self {
        case .camera: return "Enable Camera"
        case .microphone: return "Enable Microphone"
        }
    }

    /// Shown after a denial, with a path to System Settings and a graceful fallback.
    var deniedMessage: String {
        switch self {
        case .camera:
            return "BroPrompter cannot use the camera. Turn it on in System Settings, Privacy and Security, Camera to record video. You can still use the text-only teleprompter and record audio-only takes."
        case .microphone:
            return "BroPrompter cannot use the microphone. Turn it on in System Settings, Privacy and Security, Microphone to record audio. You can still use the text-only teleprompter."
        }
    }

    /// Deep link into the relevant System Settings privacy pane.
    var settingsURLString: String {
        switch self {
        case .camera:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .microphone:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        }
    }
}
