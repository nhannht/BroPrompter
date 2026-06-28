import AVFoundation
import Foundation
import Testing

@testable import BroPrompter

/// Integration proof that the lossless trimmer actually writes a shorter, playable
/// file (BROP-8). This is the one AV-touching test: it encodes a short `.m4a`, trims
/// a sub-range through `TakeTrimmer`, and checks the output exists with the expected
/// duration. Headless and CI-safe (audio export needs no display or focus); the
/// pure `TrimSelection` tests remain the baseline for the trim math.
@Suite("Take trimmer")
struct TakeTrimmerTests {

  // MARK: Internal

  @Test("trimming a sub-range writes a shorter playable file")
  func trimsAudioToSubRange() async throws {
    let source = URL.temporaryDirectory.appending(path: "TakeTrimmerTests-\(UUID().uuidString).m4a")
    let destination = URL.temporaryDirectory.appending(path: "TakeTrimmerTests-\(UUID().uuidString)-trim.m4a")
    defer {
      try? FileManager.default.removeItem(at: source)
      try? FileManager.default.removeItem(at: destination)
    }

    try Self.writeTone(seconds: 3, to: source)

    try await TakeTrimmer.trim(source: source, mode: .audio, start: 0.5, end: 2.0, to: destination)

    #expect(FileManager.default.fileExists(atPath: destination.path))
    let trimmedDuration = try await AVURLAsset(url: destination).load(.duration).seconds
    // Passthrough trims on packet boundaries, so allow generous tolerance around 1.5s.
    #expect(trimmedDuration > 1.2)
    #expect(trimmedDuration < 1.8)
  }

  // MARK: Private

  /// Encodes `seconds` of a 440 Hz sine as an AAC `.m4a` at `url`, the stand-in for
  /// a recorded audio take.
  private static func writeTone(seconds: Double, to url: URL) throws {
    let sampleRate = 44_100.0
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: 1,
    ]
    let file = try AVAudioFile(forWriting: url, settings: settings)
    let format = file.processingFormat
    let frameCount = AVAudioFrameCount(sampleRate * seconds)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
      throw CocoaError(.fileWriteUnknown)
    }
    buffer.frameLength = frameCount

    if let samples = buffer.floatChannelData?[0] {
      let angularStep = 2 * Double.pi * 440 / sampleRate
      for frame in 0 ..< Int(frameCount) {
        samples[frame] = Float(sin(Double(frame) * angularStep) * 0.25)
      }
    }
    try file.write(from: buffer)
  }
}
