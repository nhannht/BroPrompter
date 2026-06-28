import SwiftData
import Testing

@testable import BroPrompter

/// Guards the CloudKit-safe shape of the synced models (BROP-27). The scripts
/// store flips to `cloudKitDatabase: .automatic` once the Apple Developer account
/// verifies; CloudKit then rejects a schema with a uniqueness constraint, a
/// required (non-optional) relationship, or a non-optional attribute that has no
/// default. `Script` and `Take` are built to avoid all three: every attribute is
/// defaulted and links stay loose `UUID`s rather than SwiftData relationships.
///
/// The suite reads the live `ScriptStore` schema rather than a hand-rebuilt copy,
/// so a model later added to the real container is covered automatically. These
/// tests fail in CI the moment a change breaks the invariant, long before anyone
/// can try the flip against real CloudKit.
@Suite("CloudKit readiness")
struct CloudKitReadinessTests {

  // MARK: Internal

  @Test("the scripts schema is exactly Script and Take")
  func schemaContainsExpectedEntities() {
    #expect(Set(entities.map(\.name)) == ["Script", "Take"])
  }

  @Test("no synced entity declares a uniqueness constraint")
  func noUniquenessConstraints() {
    #expect(!entities.isEmpty, "the synced schema is empty; the check below would vacuously pass")
    for entity in entities {
      #expect(
        entity.uniquenessConstraints.isEmpty,
        "\(entity.name) has a uniqueness constraint, which CloudKit cannot enforce"
      )
    }
  }

  @Test("no synced entity declares a SwiftData relationship")
  func noRelationships() {
    #expect(!entities.isEmpty, "the synced schema is empty; the check below would vacuously pass")
    for entity in entities {
      #expect(
        entity.relationships.isEmpty,
        "\(entity.name) declares a relationship; the synced model keeps links as loose UUIDs so CloudKit stays happy"
      )
    }
  }

  @Test("every synced attribute is optional or has a default value")
  func attributesAreOptionalOrDefaulted() {
    #expect(!entities.isEmpty, "the synced schema is empty; the check below would vacuously pass")
    for entity in entities {
      for attribute in entity.attributes {
        #expect(
          attribute.isOptional || attribute.defaultValue != nil,
          "\(entity.name).\(attribute.name) is non-optional with no default; CloudKit requires every attribute optional or defaulted"
        )
      }
    }
  }

  // MARK: Private

  /// The entities the live scripts container persists and (after BROP-27) mirrors
  /// to CloudKit. Read from `ScriptStore` so the guard tracks the schema the app
  /// actually ships, not a copy. The container is built once and runs in-memory
  /// under the hosted test, so reading it here never touches the real store.
  private var entities: [Schema.Entity] {
    ScriptStore.container.schema.entities
  }

}
