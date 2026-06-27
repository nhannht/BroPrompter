import Foundation
import Testing

@testable import BroPrompter

/// Layer 1 tests for the pure import derivation extracted in BROP-29.
@Suite("Script import")
struct ScriptImportTests {

  @Test("derives the title from the file name and keeps the contents", arguments: [
    (path: "/tmp/My Talk.txt", title: "My Talk"),
    (path: "/tmp/notes", title: "notes"),
    (path: "/tmp/release.notes.txt", title: "release.notes"),
  ])
  func importedTitle(_ testCase: (path: String, title: String)) {
    let url = URL(fileURLWithPath: testCase.path)
    let script = Script.imported(from: url, contents: "line one\nline two")
    #expect(script.title == testCase.title)
    #expect(script.body == "line one\nline two")
  }
}
