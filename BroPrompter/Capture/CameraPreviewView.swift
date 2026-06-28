import AVFoundation
import SwiftUI

// MARK: - CameraPreviewView

/// Renders the camera's shared `AVCaptureVideoPreviewLayer` as a SwiftUI view
/// that fills its bounds with the camera image (BROP-5). The layer is owned by
/// `CaptureSessionManager`, not by this view, so unmounting the view (camera off,
/// window close) never deallocates the layer mid session-config, which would
/// deadlock CoreAnimation against the session lock (BROP-42). This view only
/// hosts the layer; the manager handles the session and mirroring.
struct CameraPreviewView: NSViewRepresentable {
  let previewLayer: AVCaptureVideoPreviewLayer

  func makeNSView(context _: Context) -> CameraPreviewNSView {
    CameraPreviewNSView(previewLayer: previewLayer)
  }

  func updateNSView(_: CameraPreviewNSView, context _: Context) { }
}

// MARK: - CameraPreviewNSView

/// A layer-hosting view whose backing layer is the shared capture preview layer,
/// so it resizes with the view automatically and needs no manual layout. It does
/// not own the layer; `CaptureSessionManager` does.
final class CameraPreviewNSView: NSView {

  init(previewLayer: AVCaptureVideoPreviewLayer) {
    super.init(frame: .zero)
    layer = previewLayer
    wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
