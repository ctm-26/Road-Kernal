import XCTest
@testable import RoadKernel

final class TelemetryTests: XCTestCase {

    func testSpeedConversions() {
        var sample = TelemetryData.empty
        sample.speedMetersPerSecond = 10
        XCTAssertEqual(sample.speedKilometersPerHour, 36, accuracy: 0.001)
        XCTAssertEqual(sample.speedMilesPerHour, 22.369, accuracy: 0.01)
    }

    func testUnknownSpeedReadsAsZero() {
        XCTAssertEqual(TelemetryData.empty.speedKilometersPerHour, 0, accuracy: 0.001)
        XCTAssertEqual(TelemetryData.empty.speedMilesPerHour, 0, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        var sample = TelemetryData(timestamp: Date(timeIntervalSince1970: 1000),
                                   speedMetersPerSecond: 12, headingDegrees: 90, horizontalAccuracy: 5)
        sample.rpm = 6500
        sample.gear = 4

        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(TelemetryData.self, from: data)
        XCTAssertEqual(decoded, sample)
    }

    @MainActor
    func testSettingsPersistAcrossInstances() {
        let suite = UserDefaults(suiteName: "telemetry.tests")!
        suite.removePersistentDomain(forName: "telemetry.tests")

        let store = SettingsStore(defaults: suite)
        store.useMetric = true
        store.mockMode = true

        let reloaded = SettingsStore(defaults: suite)
        XCTAssertTrue(reloaded.useMetric)
        XCTAssertTrue(reloaded.mockMode)
    }
}
