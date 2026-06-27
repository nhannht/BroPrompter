import Foundation
import SwiftData
import Testing

@testable import BroPrompter

/// Layer 1 proof that scripts survive relaunch at the data layer (BROP-29):
/// write to an on-disk store, drop the container, reopen the same file, and
/// confirm the data is still there.
@MainActor
@Suite("Script persistence")
struct ScriptPersistenceTests {

  @Test("data survives reopening the on-disk store")
  func dataSurvivesReopen() throws {
    let url = TestStore.tempStoreURL()
    defer { TestStore.removeStore(at: url) }

    let savedID: UUID
    do {
      let container = try TestStore.container(at: url)
      let script = Script(title: "Persisted", body: "stays on disk")
      savedID = script.id
      container.mainContext.insert(script)
      try container.mainContext.save()
    }

    // A fresh container at the same URL stands in for an app relaunch.
    let reopened = try TestStore.container(at: url)
    let fetched = try reopened.mainContext.fetch(FetchDescriptor<Script>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.id == savedID)
    #expect(fetched.first?.title == "Persisted")
    #expect(fetched.first?.body == "stays on disk")
  }
}
