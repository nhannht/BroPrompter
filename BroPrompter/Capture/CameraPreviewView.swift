import AVFoundation
import SwiftUI

// MARK: - CameraPreviewView

/// Renders a live `AVCaptureSession` as a SwiftUI view that fills its bounds with
/// the camera image (BROP-5). Bridges `AVCaptureVideoPreviewLayer` through a
/// layer-hosting `NSView`; the preview is mirrored so the reader sees a natural
/// self-view.
struct CameraPreviewView: NSViewRepresentable {
  let session: AVCaptureSession

  func makeNSView(context _: Context) -> CameraPreviewNSView {
    let view = CameraPreviewNSView()
    view.attach(session)
    return view
  }

  func updateNSView(_ nsView: CameraPreviewNSView, context _: Context) {
    nsView.attach(session)
  }
}

// MARK: - CameraPreviewNSView

/// A layer-hosting view whose backing layer is the capture preview layer, so it
/// resizes with the view automatically and needs no manual layout.
final class CameraPreviewNSView: NSView {

  // MARK: Lifecycle

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    layer = previewLayer
    wantsLayer = true
    previewLayer.videoGravity = .resizeAspectFill
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Internal

  /// Points the preview at a session and mirrors it once the connection exists.
  func attach(_ session: AVCaptureSession) {
    if previewLayer.session !== session {
      previewLayer.session = session
    }
    if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = true
    }
  }

  // MARK: Private

  private let previewLayer = AVCaptureVideoPreviewLayer()
}
