import Foundation
import Testing

@testable import BroPrompter

/// Layer 1 unit tests for the pure capture-format selection logic (BROP-32):
/// which `CaptureQuality` presets a camera can deliver, and which of its formats
/// best matches a chosen quality. Driven by synthetic `VideoFormatDescriptor`
/// arrays, so the suite needs no camera and is CI-safe.
@Suite("Capture format resolver")
struct CaptureFormatResolverTests {

  // MARK: Internal

  @Test("availableQualities excludes presets the camera cannot deliver")
  func availableExcludesUnsupported() {
    #expect(CaptureFormatResolver.availableQualities(in: Self.only1080p30) == [.hd720p30, .hd1080p30])
  }

  @Test("availableQualities lists every supported preset in menu order")
  func availableListsAllSupported() {
    #expect(CaptureFormatResolver.availableQualities(in: Self.fullRange)
      == [.hd720p30, .hd1080p30, .hd1080p60, .uhd4K30])
  }

  @Test("availableQualities is empty when there are no formats")
  func availableEmptyWithoutFormats() {
    #expect(CaptureFormatResolver.availableQualities(in: []).isEmpty)
  }

  @Test("match resolves a supported quality to its format index")
  func matchResolvesIndex() {
    #expect(CaptureFormatResolver.match(.hd720p30, in: Self.fullRange) == 0)
    #expect(CaptureFormatResolver.match(.hd1080p60, in: Self.fullRange) == 2)
    #expect(CaptureFormatResolver.match(.uhd4K30, in: Self.fullRange) == 3)
  }

  @Test("match prefers the format with the least frame-rate headroom")
  func matchPrefersLeastHeadroom() {
    // Two 1080p formats: 30 fps then 60 fps. A 30 fps request takes the 30 fps one.
    #expect(CaptureFormatResolver.match(.hd1080p30, in: Self.fullRange) == 1)
  }

  @Test("match returns nil for an unsupported quality")
  func matchNilWhenUnsupported() {
    #expect(CaptureFormatResolver.match(.hd1080p60, in: Self.only1080p30) == nil)
    #expect(CaptureFormatResolver.match(.uhd4K30, in: Self.only1080p30) == nil)
    #expect(CaptureFormatResolver.match(.hd720p30, in: []) == nil)
  }

  // MARK: Private

  /// A camera that tops out at 1080p30: no 60 fps, no 4K.
  private static let only1080p30 = [
    VideoFormatDescriptor(width: 1_280, height: 720, maxFrameRate: 30),
    VideoFormatDescriptor(width: 1_920, height: 1_080, maxFrameRate: 30),
  ]

  /// A capable camera: 720p, 1080p up to 60 fps, and 4K30.
  private static let fullRange = [
    VideoFormatDescriptor(width: 1_280, height: 720, maxFrameRate: 30),
    VideoFormatDescriptor(width: 1_920, height: 1_080, maxFrameRate: 30),
    VideoFormatDescriptor(width: 1_920, height: 1_080, maxFrameRate: 60),
    VideoFormatDescriptor(width: 3_840, height: 2_160, maxFrameRate: 30),
  ]

}
