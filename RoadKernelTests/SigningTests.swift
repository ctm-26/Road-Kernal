import XCTest
import CryptoKit
import CoreLocation
import SwiftData
@testable import RoadKernel

/// Tests for the signing / content-addressing foundation. All pure logic —
/// no Keychain, no device — using an EphemeralIdentity.
final class SigningTests: XCTestCase {

    private func sampleDTO(name: String = "Main St + River Rd") -> JSONExporter.SignalDTO {
        JSONExporter.SignalDTO(
            id: "00000000-0000-0000-0000-000000000001",
            name: name,
            intersectionName: "",
            latitude: 40.123456,
            longitude: -74.654321,
            confidence: "low",
            source: "manual",
            notes: "",
            createdAt: "2026-06-06T00:00:00Z",
            updatedAt: "2026-06-06T00:00:00Z"
        )
    }

    func testSignAndVerifyRoundTrip() throws {
        let identity = EphemeralIdentity()
        let record = try RecordSigner.make(payload: sampleDTO(), identity: identity)
        XCTAssertTrue(RecordSigner.verify(record))
    }

    func testTamperedPayloadFailsVerification() throws {
        let identity = EphemeralIdentity()
        let original = try RecordSigner.make(payload: sampleDTO(), identity: identity)
        // Swap in different content but keep the old hash/signature.
        let tampered = SignedRecord(
            payload: sampleDTO(name: "Tampered"),
            contentHash: original.contentHash,
            parentHashes: original.parentHashes,
            authorPublicKey: original.authorPublicKey,
            signature: original.signature
        )
        XCTAssertFalse(RecordSigner.verify(tampered))
    }

    func testWrongAuthorKeyFailsVerification() throws {
        let identity = EphemeralIdentity()
        let impostor = EphemeralIdentity()
        let original = try RecordSigner.make(payload: sampleDTO(), identity: identity)
        let swappedKey = SignedRecord(
            payload: original.payload,
            contentHash: original.contentHash,
            parentHashes: original.parentHashes,
            authorPublicKey: impostor.publicKey.rawRepresentation.base64EncodedString(),
            signature: original.signature
        )
        XCTAssertFalse(RecordSigner.verify(swappedKey))
    }

    func testContentHashIsDeterministicAndAddressable() throws {
        let identity = EphemeralIdentity()
        let a = try RecordSigner.make(payload: sampleDTO(), identity: identity)
        let b = try RecordSigner.make(payload: sampleDTO(), identity: identity)
        XCTAssertEqual(a.contentHash, b.contentHash, "Same content must address to the same hash")

        let c = try RecordSigner.make(payload: sampleDTO(name: "Different"), identity: identity)
        XCTAssertNotEqual(a.contentHash, c.contentHash, "Different content must change the hash")
    }

    func testParentHashesAreCoveredByTheHash() throws {
        let identity = EphemeralIdentity()
        let root = try RecordSigner.make(payload: sampleDTO(), identity: identity)
        let child = try RecordSigner.make(payload: sampleDTO(name: "Child"),
                                          parents: [root.contentHash],
                                          identity: identity)
        XCTAssertEqual(child.parentHashes, [root.contentHash])
        XCTAssertTrue(RecordSigner.verify(child))
    }

    @MainActor
    func testSignedBundleVerifiesAndDecodes() throws {
        let container = try ModelContainer(
            for: Signal.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let signal = Signal(coordinate: CLLocationCoordinate2D(latitude: 40.1, longitude: -74.2))
        signal.name = "Main St + River Rd"
        context.insert(signal)

        let identity = EphemeralIdentity()
        let json = try JSONExporter.signedBundleJSON(signals: [signal], identity: identity)

        let bundle = try JSONDecoder().decode(JSONExporter.SignedBundle.self, from: Data(json.utf8))
        XCTAssertEqual(bundle.records.count, 1)
        XCTAssertEqual(bundle.kind, "roadkernel.signals.v1")
        XCTAssertTrue(bundle.records.allSatisfy { RecordSigner.verify($0) })
    }
}
