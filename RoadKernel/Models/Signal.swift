import Foundation
import SwiftData
import CoreLocation

/// The only model that ships in v0.1: a traffic signal you have personally marked.
///
/// Enum values are stored as their raw `String` (`*Raw`) because SwiftData stores
/// primitives most reliably; typed accessors wrap them for ergonomic call sites.
/// Every record carries the shared traceability fields (id/createdAt/updatedAt/
/// source/confidence/notes) — see docs/ARCHITECTURE.md §4.
@Model
final class Signal {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var name: String
    var intersectionName: String
    var createdAt: Date
    var updatedAt: Date
    var confidenceRaw: String
    var sourceRaw: String
    var notes: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var confidence: Confidence {
        get { Confidence(rawValue: confidenceRaw) ?? .low }
        set { confidenceRaw = newValue.rawValue }
    }

    var source: Source {
        get { Source(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(coordinate: CLLocationCoordinate2D, source: Source = .manual) {
        self.id = UUID()
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.name = ""
        self.intersectionName = ""
        self.createdAt = .now
        self.updatedAt = .now
        self.confidenceRaw = Confidence.low.rawValue
        self.sourceRaw = source.rawValue
        self.notes = ""
    }
}
