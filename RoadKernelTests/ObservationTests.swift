import XCTest
import CoreLocation
import SwiftData
@testable import RoadKernel

/// v0.2 logic: the observation model, nearest-signal matching, confidence
/// heuristic, and the signal→observation Merkle link in the signed bundle.
final class ObservationTests: XCTestCase {

    func testObservationDefaults() {
        let observation = SignalObservation(signalID: UUID(), state: .red,
                                            coordinate: .init(latitude: 1, longitude: 2))
        XCTAssertEqual(observation.observedState, .red)
        XCTAssertEqual(observation.source, .observed)
        XCTAssertEqual(observation.latitude, 1, accuracy: 1e-9)
        XCTAssertEqual(observation.speed, -1, accuracy: 1e-9)   // unknown sentinel
    }

    func testObservationFromLocationCapturesMetadata() {
        let location = CLLocation(
            coordinate: .init(latitude: 40, longitude: -74),
            altitude: 0, horizontalAccuracy: 8, verticalAccuracy: 8,
            course: 90, speed: 0, timestamp: Date(timeIntervalSince1970: 1_000_000)
        )
        let observation = SignalObservation(signalID: UUID(), state: .green, location: location)
        XCTAssertEqual(observation.horizontalAccuracy, 8, accuracy: 1e-9)
        XCTAssertEqual(observation.heading, 90, accuracy: 1e-9)
        XCTAssertEqual(observation.speed, 0, accuracy: 1e-9)
        XCTAssertEqual(observation.timestamp, Date(timeIntervalSince1970: 1_000_000))
    }

    func testMatcherRanksNearestAndFiltersByRadius() {
        let near = Signal(coordinate: .init(latitude: 40.0000, longitude: -74.0000))
        let mid  = Signal(coordinate: .init(latitude: 40.0003, longitude: -74.0000)) // ~22 m
        let far  = Signal(coordinate: .init(latitude: 40.0100, longitude: -74.0000)) // ~1.1 km
        let here = CLLocationCoordinate2D(latitude: 40.0001, longitude: -74.0000)

        let candidates = SignalMatcher.candidates(near: here, in: [far, mid, near], radius: 60)
        XCTAssertEqual(candidates.count, 2)        // far is excluded
        XCTAssertTrue(candidates.first === near)   // nearest first
    }

    func testConfidenceHeuristicThresholds() {
        XCTAssertEqual(ConfidenceHeuristic.suggested(sampleCount: 0), .low)
        XCTAssertEqual(ConfidenceHeuristic.suggested(sampleCount: 3), .low)
        XCTAssertEqual(ConfidenceHeuristic.suggested(sampleCount: 4), .medium)
        XCTAssertEqual(ConfidenceHeuristic.suggested(sampleCount: 9), .medium)
        XCTAssertEqual(ConfidenceHeuristic.suggested(sampleCount: 10), .high)
    }

    func testSignedBundleLinksObservationToSignalParent() throws {
        let signal = Signal(coordinate: .init(latitude: 40, longitude: -74))
        let observation = SignalObservation(signalID: signal.id, state: .red,
                                            coordinate: .init(latitude: 40, longitude: -74))
        let identity = EphemeralIdentity()

        let bundle = try JSONExporter.signedBundle(signals: [signal],
                                                   observations: [observation],
                                                   identity: identity)
        XCTAssertEqual(bundle.signals.count, 1)
        XCTAssertEqual(bundle.observations.count, 1)
        // The observation block links to the signal block as its Merkle parent.
        XCTAssertEqual(bundle.observations[0].parentHashes, [bundle.signals[0].contentHash])
        XCTAssertTrue(RecordSigner.verify(bundle.signals[0]))
        XCTAssertTrue(RecordSigner.verify(bundle.observations[0]))
    }
}
