import Foundation
import SwiftData
import Testing

@testable import BroPrompter

/// Layer 1 integration tests for Script CRUD on a SwiftData container (BROP-29).
@MainActor
@Suite("Script model")
struct ScriptModelTests {

  @Test("inserts and fetches a script")
  func insertAndFetch() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    let script = Script(title: "Intro", body: "Hello, everyone.")
    context.insert(script)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Script>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.title == "Intro")
    #expect(fetched.first?.body == "Hello, everyone.")
  }

  @Test("deletes a script")
  func delete() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    let script = Script(title: "Throwaway")
    context.insert(script)
    try context.save()
    context.delete(script)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Script>())
    #expect(fetched.isEmpty)
  }

  @Test("fetches scripts sorted by updatedAt descending")
  func sortedByUpdatedAtDescending() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    let older = Script(title: "Older")
    older.updatedAt = Date(timeIntervalSince1970: 1_000)
    let newer = Script(title: "Newer")
    newer.updatedAt = Date(timeIntervalSince1970: 2_000)
    context.insert(older)
    context.insert(newer)
    try context.save()

    let descriptor = FetchDescriptor<Script>(
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
    let fetched = try context.fetch(descriptor)
    #expect(fetched.map(\.title) == ["Newer", "Older"])
  }

  @Test("persists an edited title")
  func editPersists() throws {
    let container = try TestStore.inMemoryContainer()
    let context = container.mainContext

    let script = Script(title: "Draft")
    context.insert(script)
    try context.save()

    script.title = "Final"
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Script>())
    #expect(fetched.first?.title == "Final")
  }
}
