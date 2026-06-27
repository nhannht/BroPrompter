import AVFoundation
import Foundation

/// Records an audio-only take to an .m4a (AAC) file with metering, used when the
/// camera is off (BROP-6). macOS has no audio session to configure; microphone
/// access is gated separately through `PermissionManager` before recording.
@MainActor
final class AudioTakeRecorder {

  // MARK: Internal

  /// Starts recording to the given file URL. Throws if the recorder cannot be
  /// created (for example an unwritable location).
  func start(to url: URL) throws {
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 44_100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
    let recorder = try AVAudioRecorder(url: url, settings: settings)
    recorder.isMeteringEnabled = true
    recorder.record()
    self.recorder = recorder
  }

  func pause() {
    recorder?.pause()
  }

  func resume() {
    recorder?.record()
  }

  /// The current average power in decibels (-160...0), or the meter floor when
  /// no recording is in progress.
  func meterDecibels() -> Double {
    guard let recorder else { return RecorderController.meterFloorDecibels }
    recorder.updateMeters()
    return Double(recorder.averagePower(forChannel: 0))
  }

  /// Stops recording and returns the written file's URL, or nil if idle.
  @discardableResult
  func stop() -> URL? {
    guard let recorder else { return nil }
    let url = recorder.url
    recorder.stop()
    self.recorder = nil
    return url
  }

  // MARK: Private

  private var recorder: AVAudioRecorder?
}
