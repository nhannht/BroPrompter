import AVFoundation
import CoreMedia
import Observation

// MARK: - CaptureDevice

/// A capture device as the pickers need it: a stable id and a display name, so
/// SwiftUI never holds an `AVCaptureDevice` directly.
struct CaptureDevice: Identifiable, Hashable {
  let id: String
  let name: String
}

// MARK: - CaptureSessionManager

/// Owns the camera `AVCaptureSession` behind the teleprompter (BROP-5): it
/// enumerates devices, starts and stops a live preview, and applies a chosen
/// `CaptureQuality` by selecting the camera's matching `activeFormat`. Session
/// configuration and the blocking start/stop run on a serial queue off the main
/// thread; observable state is published back on the main actor.
///
/// No audio input is added here. The microphone is wired only when recording
/// starts (P4 / BROP-6), so the microphone privacy indicator stays off during
/// preview (GUIDELINES.md 2.1).
@MainActor
@Observable
final class CaptureSessionManager {

  // MARK: Internal

  /// The capture session the preview layer renders.
  let session = AVCaptureSession()

  /// Cameras available to pick from, refreshed by `refreshDevices`.
  private(set) var availableCameras = [CaptureDevice]()

  /// Microphones available to pick from. Selection only in P3 (see type note).
  private(set) var availableMicrophones = [CaptureDevice]()

  /// Whether the session is running and feeding the preview.
  private(set) var isRunning = false

  /// Discovers connected cameras and microphones for the device pickers. Cheap
  /// and non-blocking, so it runs on the main actor.
  func refreshDevices() {
    availableCameras = Self.discover(Self.cameraDeviceTypes, mediaType: .video)
    availableMicrophones = Self.discover([.microphone], mediaType: .audio)
  }

  /// The qualities the given camera can deliver, in menu order. Empty when the
  /// camera is unknown or unavailable.
  func supportedQualities(forCameraID id: String?) -> [CaptureQuality] {
    guard let device = Self.camera(withID: id) ?? Self.defaultCamera else { return [] }
    return CaptureFormatResolver.availableQualities(in: Self.descriptors(of: device))
  }

  /// Starts a live preview from the chosen camera at the chosen quality. Falls
  /// back to the system default camera when `cameraID` is unknown, and to the
  /// camera's default format when the quality is unavailable. Does nothing when
  /// no camera is present (for example in CI).
  func start(cameraID: String?, quality: CaptureQuality) {
    guard let device = Self.camera(withID: cameraID) ?? Self.defaultCamera else { return }
    configure(device: device, quality: quality)
    run()
  }

  /// Stops the preview and releases the camera, so the green privacy dot clears.
  func stop() {
    nonisolated(unsafe) let session = session
    sessionQueue.async { [weak self] in
      if session.isRunning { session.stopRunning() }
      session.beginConfiguration()
      for input in session.inputs { session.removeInput(input) }
      session.commitConfiguration()
      Task { @MainActor in self?.isRunning = false }
    }
  }

  /// Switches the live camera, applying the chosen quality where possible.
  func selectCamera(id: String?, quality: CaptureQuality) {
    start(cameraID: id, quality: quality)
  }

  /// Reapplies a quality to the current camera without tearing down the session.
  func updateQuality(_ quality: CaptureQuality, cameraID: String?) {
    guard let device = Self.camera(withID: cameraID) ?? Self.defaultCamera else { return }
    configure(device: device, quality: quality)
  }

  // MARK: Private

  /// Camera device types BroPrompter offers: built-in, external/USB, iPhone
  /// Continuity Camera, and Desk View.
  private static let cameraDeviceTypes: [AVCaptureDevice.DeviceType] =
    [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera]

  /// The system default camera, used when no specific camera is chosen.
  private static var defaultCamera: AVCaptureDevice? {
    AVCaptureDevice.default(for: .video)
  }

  /// Serial queue for session configuration and the blocking start/stop calls.
  private let sessionQueue = DispatchQueue(label: "com.nhannht.BroPrompter.capture")

  /// Resolves a camera by its unique id.
  private static func camera(withID id: String?) -> AVCaptureDevice? {
    guard let id else { return nil }
    return AVCaptureDevice(uniqueID: id)
  }

  /// Lists the devices of the given types as picker-friendly values.
  private static func discover(
    _ types: [AVCaptureDevice.DeviceType],
    mediaType: AVMediaType
  ) -> [CaptureDevice] {
    AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: mediaType, position: .unspecified)
      .devices
      .map { CaptureDevice(id: $0.uniqueID, name: $0.localizedName) }
  }

  /// Lifts a camera's formats into hardware-free descriptors, index-aligned with
  /// `device.formats` so `CaptureFormatResolver.match` returns a usable index.
  private nonisolated static func descriptors(of device: AVCaptureDevice) -> [VideoFormatDescriptor] {
    device.formats.map { format in
      let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
      let maxFrameRate = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
      return VideoFormatDescriptor(
        width: Int(dimensions.width),
        height: Int(dimensions.height),
        maxFrameRate: maxFrameRate
      )
    }
  }

  /// Selects the camera's `activeFormat` for `quality` and pins its frame rate.
  /// Leaves the default format when the quality is unsupported.
  private nonisolated static func applyQuality(_ quality: CaptureQuality, to device: AVCaptureDevice) {
    guard
      let index = CaptureFormatResolver.match(quality, in: descriptors(of: device)),
      index < device.formats.count,
      (try? device.lockForConfiguration()) != nil
    else { return }
    defer { device.unlockForConfiguration() }

    device.activeFormat = device.formats[index]
    let duration = CMTime(value: 1, timescale: CMTimeScale(quality.frameRate))
    device.activeVideoMinFrameDuration = duration
    device.activeVideoMaxFrameDuration = duration
  }

  /// Replaces the session input with the chosen camera and applies the quality.
  /// On macOS the session honors the device's `activeFormat` directly, so no
  /// `.inputPriority` preset is needed (that preset is iOS-only).
  private func configure(device: AVCaptureDevice, quality: CaptureQuality) {
    nonisolated(unsafe) let session = session
    nonisolated(unsafe) let device = device
    sessionQueue.async {
      session.beginConfiguration()
      defer { session.commitConfiguration() }

      for input in session.inputs { session.removeInput(input) }
      guard
        let input = try? AVCaptureDeviceInput(device: device),
        session.canAddInput(input)
      else { return }

      session.addInput(input)
      Self.applyQuality(quality, to: device)
    }
  }

  /// Starts the session if it is not already running, then publishes the state.
  private func run() {
    nonisolated(unsafe) let session = session
    sessionQueue.async { [weak self] in
      if !session.isRunning { session.startRunning() }
      let running = session.isRunning
      Task { @MainActor in self?.isRunning = running }
    }
  }
}
