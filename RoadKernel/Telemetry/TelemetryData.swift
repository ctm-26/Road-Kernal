import Foundation

/// A single telemetry sample. The GPS fields are real (from CoreLocation); the
/// GT7-style fields are optional and only set by a source that can supply them
/// (the mock source now, a vehicle/OBD link later). Codable so it can stream
/// across the iPhone↔iPad link.
struct TelemetryData: Codable, Equatable {
    var timestamp: Date

    var speedMetersPerSecond: Double   // -1 when unknown
    var headingDegrees: Double         // -1 when unknown
    var horizontalAccuracy: Double     // -1 when unknown

    var rpm: Double?
    var gear: Int?
    var throttle: Double?              // 0...1
    var brake: Double?                 // 0...1
    var fuelPercent: Double?
    var lapTime: TimeInterval?
    var currentLap: Int?
    var position: Int?

    static let empty = TelemetryData(timestamp: .distantPast,
                                     speedMetersPerSecond: -1,
                                     headingDegrees: -1,
                                     horizontalAccuracy: -1)
}

extension TelemetryData {
    var speedKilometersPerHour: Double { speedMetersPerSecond >= 0 ? speedMetersPerSecond * 3.6 : 0 }
    var speedMilesPerHour: Double { speedMetersPerSecond >= 0 ? speedMetersPerSecond * 2.236936 : 0 }
}

/// State of the live link between devices (or mock when running standalone).
enum ConnectionStatus: String {
    case disconnected, searching, connected, mock
}
