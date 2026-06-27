import Foundation
import SwiftData
import Testing

@testable import BroPrompter

/// Layer 1 proof that takes survive relaunch at the data layer (BROP-33), and
/// that registering `Take` in the schema works: write to an on-disk store, drop
/// the container, reopen the same file, and confirm the take is still there.
@MainActor
@Suite("Take persistence")
struct TakePersistenceTests {

  @Test("a take survives reopening the on-disk store")
  func takeSurvivesReopen() throws {
    let url = TestStore.tempStoreURL()
    defer { TestStore.removeStore(at: url) }

    let savedID: UUID
    let scriptID = UUID()
    do {
      let container = try TestStore.container(at: url)
      let take = Take(scriptID: scriptID, mode: .audio, fileName: "take.m4a", duration: 12.5)
      savedID = take.id
      container.mainContext.insert(take)
      try container.mainContext.save()
    }

    // A fresh container at the same URL stands in for an app relaunch.
    let reopened = try TestStore.container(at: url)
    let fetched = try reopened.mainContext.fetch(FetchDescriptor<Take>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.id == savedID)
    #expect(fetched.first?.scriptID == scriptID)
    #expect(fetched.first?.mode == .audio)
    #expect(fetched.first?.fileName == "take.m4a")
    #expect(fetched.first?.duration == 12.5)
  }

  @Test("a video take's quality and codec survive reopening the store")
  func videoTakeMetadataSurvivesReopen() throws {
    let url = TestStore.tempStoreURL()
    defer { TestStore.removeStore(at: url) }

    do {
      let container = try TestStore.container(at: url)
      let take = Take(
        mode: .video,
        fileName: "take.mov",
        duration: 134,
        qualityRaw: CaptureQuality.hd1080p30.rawValue,
        codecRaw: VideoCodec.hevc.rawValue
      )
      container.mainContext.insert(take)
      try container.mainContext.save()
    }

    let reopened = try TestStore.container(at: url)
    let fetched = try reopened.mainContext.fetch(FetchDescriptor<Take>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.mode == .video)
    #expect(fetched.first?.quality == .hd1080p30)
    #expect(fetched.first?.codec == .hevc)
  }
}
