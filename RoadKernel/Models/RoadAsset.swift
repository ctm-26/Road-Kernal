import Foundation
import SwiftData
import CoreLocation

/// A placed intersection-control asset: signal heads, signs, rail crossings,
/// lane/marking zones, and directional stop-line anchors.
@Model
final class RoadAsset {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var latitude: Double
    var longitude: Double
    var directionRaw: String
    var movementRaw: String
    var stopLineLatitude: Double
    var stopLineLongitude: Double
    var zoneRadiusMeters: Double
    var railWarningSeconds: Double
    var railGateDownSeconds: Double
    var label: String
    var createdAt: Date
    var updatedAt: Date
    var notes: String

    var kind: RoadAssetKind {
        get { RoadAssetKind(rawValue: kindRaw) ?? .signalHead }
        set { kindRaw = newValue.rawValue }
    }

    var direction: Direction {
        get { Direction(rawValue: directionRaw) ?? .unknown }
        set { directionRaw = newValue.rawValue }
    }

    var movement: Movement {
        get { Movement(rawValue: movementRaw) ?? .unknown }
        set { movementRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var stopLineCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stopLineLatitude, longitude: stopLineLongitude)
    }

    init(kind: RoadAssetKind,
         coordinate: CLLocationCoordinate2D,
         direction: Direction = .unknown,
         movement: Movement = .unknown) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.directionRaw = direction.rawValue
        self.movementRaw = movement.rawValue
        let stopLine = RoadAsset.defaultStopLine(from: coordinate, direction: direction)
        self.stopLineLatitude = stopLine.latitude
        self.stopLineLongitude = stopLine.longitude
        self.zoneRadiusMeters = kind.defaultZoneRadiusMeters
        self.railWarningSeconds = 20
        self.railGateDownSeconds = 12
        self.label = kind.defaultLabel
        self.createdAt = .now
        self.updatedAt = .now
        self.notes = ""
    }

    func move(to coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        stopLineLatitude = coordinate.latitude
        stopLineLongitude = coordinate.longitude
        updatedAt = .now
    }

    func resetStopLineForDirection() {
        let stopLine = RoadAsset.defaultStopLine(from: coordinate, direction: direction)
        stopLineLatitude = stopLine.latitude
        stopLineLongitude = stopLine.longitude
        updatedAt = .now
    }

    static func defaultStopLine(from coordinate: CLLocationCoordinate2D,
                                direction: Direction,
                                meters: CLLocationDistance = 12) -> CLLocationCoordinate2D {
        guard direction != .unknown else { return coordinate }
        let earthRadius = 6_378_137.0
        let bearing = direction.stopLineBearingRadians
        let angularDistance = meters / earthRadius
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(angularDistance) +
                        cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1),
                                cos(angularDistance) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}

enum RoadAssetKind: String, Codable, CaseIterable, Identifiable {
    case signalHead
    case stopSign
    case yieldSign
    case railroadCrossing
    case laneZone
    case roadMarking

    var id: String { rawValue }

    var label: String {
        switch self {
        case .signalHead: return "Light"
        case .stopSign: return "Stop"
        case .yieldSign: return "Yield"
        case .railroadCrossing: return "Rail"
        case .laneZone: return "Lane"
        case .roadMarking: return "Marking"
        }
    }

    var defaultLabel: String { label.uppercased() }

    var systemImage: String {
        switch self {
        case .signalHead: return "trafficlight"
        case .stopSign: return "octagon.fill"
        case .yieldSign: return "triangleshape.fill"
        case .railroadCrossing: return "tram.fill"
        case .laneZone: return "road.lanes"
        case .roadMarking: return "paintbrush.pointed.fill"
        }
    }

    var defaultZoneRadiusMeters: Double {
        switch self {
        case .signalHead: return 10
        case .stopSign, .yieldSign: return 8
        case .railroadCrossing: return 30
        case .laneZone: return 18
        case .roadMarking: return 12
        }
    }
}

private extension Direction {
    var stopLineBearingRadians: Double {
        switch self {
        case .north: return 0
        case .east: return .pi / 2
        case .south: return .pi
        case .west: return 3 * .pi / 2
        case .unknown: return 0
        }
    }
}
