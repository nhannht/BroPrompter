import SwiftData
import Testing

@testable import BroPrompter

/// Guards the CloudKit-safe shape of the synced models (BROP-27). The scripts
/// store flips to `cloudKitDatabase: .automatic` once the Apple Developer account
/// verifies; CloudKit then rejects any uniqueness constraint or required
/// (non-optional) relationship. `Script` and `Take` are built without either: all
/// attributes are defaulted and links stay loose `UUID`s rather than SwiftData
/// relationships. These tests fail in CI the moment a change breaks that
/// invariant, long before anyone tries the flip against real CloudKit.
@Suite("CloudKit readiness")
struct CloudKitReadinessTests {

  // MARK: Internal

  @Test("the scripts schema is exactly Script and Take")
  func schemaContainsExpectedEntities() {
    #expect(Set(entities.map(\.name)) == ["Script", "Take"])
  }

  @Test("no synced entity declares a uniqueness constraint")
  func noUniquenessConstraints() {
    for entity in entities {
      #expect(
        entity.uniquenessConstraints.isEmpty,
        "\(entity.name) has a uniqueness constraint, which CloudKit cannot enforce"
      )
    }
  }

  @Test("no synced entity declares a SwiftData relationship")
  func noRelationships() {
    for entity in entities {
      #expect(
        entity.relationships.isEmpty,
        "\(entity.name) declares a relationship; the synced model keeps links as loose UUIDs so CloudKit stays happy"
      )
    }
  }

  // MARK: Private

  /// The entities the scripts container will mirror to CloudKit.
  private var entities: [Schema.Entity] {
    Schema([Script.self, Take.self]).entities
  }

}
