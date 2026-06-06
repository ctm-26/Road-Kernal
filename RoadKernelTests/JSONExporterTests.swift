import XCTest
import CoreLocation
import SwiftData
@testable import RoadKernel

/// Unit tests for the pure-logic layer. These run without the UI or a device,
/// which is the payoff of keeping computation in plain Swift (not SwiftUI).
final class JSONExporterTests: XCTestCase {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Signal.self, configurations: config)
        return ModelContext(container)
    }

    @MainActor
    func testSignalDefaults() {
        let signal = Signal(coordinate: CLLocationCoordinate2D(latitude: 40, longitude: -74))
        XCTAssertEqual(signal.source, .manual)
        XCTAssertEqual(signal.confidence, .low)
        XCTAssertEqual(signal.latitude, 40, accuracy: 1e-9)
        XCTAssertEqual(signal.longitude, -74, accuracy: 1e-9)
        XCTAssertTrue(signal.name.isEmpty)
    }

    @MainActor
    func testEnumAccessorsRoundTrip() {
        let signal = Signal(coordinate: .init(latitude: 0, longitude: 0))
        signal.confidence = .high
        signal.source = .observed
        XCTAssertEqual(signal.confidenceRaw, "high")
        XCTAssertEqual(signal.sourceRaw, "observed")
        XCTAssertEqual(signal.confidence, .high)
        XCTAssertEqual(signal.source, .observed)
    }

    func testExportEmptyIsValidJSON() throws {
        let json = JSONExporter.export(signals: [])
        let payload = try JSONDecoder().decode(JSONExporter.Payload.self, from: Data(json.utf8))
        XCTAssertTrue(payload.signals.isEmpty)
    }

    @MainActor
    func testExportContainsAndRoundTripsSignal() throws {
        let context = try makeInMemoryContext()
        let signal = Signal(coordinate: .init(latitude: 40.123456, longitude: -74.654321))
        signal.name = "Main St + River Rd"
        signal.confidence = .medium
        context.insert(signal)

        let json = JSONExporter.export(signals: [signal])
        XCTAssertTrue(json.contains("Main St + River Rd"))
        XCTAssertTrue(json.contains("medium"))

        let payload = try JSONDecoder().decode(JSONExporter.Payload.self, from: Data(json.utf8))
        XCTAssertEqual(payload.signals.count, 1)
        let dto = try XCTUnwrap(payload.signals.first)
        XCTAssertEqual(dto.name, "Main St + River Rd")
        XCTAssertEqual(dto.confidence, "medium")
        XCTAssertEqual(dto.source, "manual")
        XCTAssertEqual(dto.latitude, 40.123456, accuracy: 1e-9)
        XCTAssertEqual(dto.longitude, -74.654321, accuracy: 1e-9)
        XCTAssertFalse(dto.id.isEmpty)
    }
}
