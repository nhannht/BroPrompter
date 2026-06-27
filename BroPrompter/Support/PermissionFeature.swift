import AVFoundation

/// A capability that BroPrompter must request from the user, with the copy and
/// system routing for its in-context permission flow (GUIDELINES.md section 1).
enum PermissionFeature: String, Identifiable, CaseIterable {
  case camera
  case microphone

  // MARK: Internal

  var id: String {
    rawValue
  }

  /// The AVFoundation media type whose authorization status this feature maps to.
  var mediaType: AVMediaType {
    switch self {
    case .camera: .video
    case .microphone: .audio
    }
  }

  /// SF Symbol shown in the pre-prompt and denied cards.
  var systemImage: String {
    switch self {
    case .camera: "camera"
    case .microphone: "mic"
    }
  }

  var title: String {
    switch self {
    case .camera: "Camera Access"
    case .microphone: "Microphone Access"
    }
  }

  /// In-context explainer shown before the system dialog. Mirrors the
  /// Info.plist usage string so the benefit reads the same in both places.
  var prePromptMessage: String {
    switch self {
    case .camera:
      "BroPrompter shows the camera behind your script so you can read while looking at the lens, and records video takes."
    case .microphone:
      "BroPrompter records your voice for audio and video takes."
    }
  }

  var enableButtonTitle: String {
    switch self {
    case .camera: "Enable Camera"
    case .microphone: "Enable Microphone"
    }
  }

  /// Shown after a denial, with a path to System Settings and a graceful fallback.
  var deniedMessage: String {
    switch self {
    case .camera:
      "BroPrompter cannot use the camera. Turn it on in System Settings, Privacy and Security, Camera to record video. You can still use the text-only teleprompter and record audio-only takes."
    case .microphone:
      "BroPrompter cannot use the microphone. Turn it on in System Settings, Privacy and Security, Microphone to record audio. You can still use the text-only teleprompter."
    }
  }

  /// Deep link into the relevant System Settings privacy pane.
  var settingsURLString: String {
    switch self {
    case .camera:
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
    case .microphone:
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    }
  }
}
