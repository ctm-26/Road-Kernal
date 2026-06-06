import Foundation
import SwiftData
import CoreLocation

/// A single observed light state at a signal (v0.2). References its `Signal` by
/// stable UUID — not a SwiftData relationship — so records stay portable across
/// devices and map cleanly onto signed network blocks (docs/NETWORK.md).
///
/// GPS quality (speed/heading/accuracy) is stored with every observation so a
/// later pass can re-attribute samples that were attached to the wrong signal
/// (docs/CRITIQUE.md §4). Unknown values are stored as -1.
@Model
final class SignalObservation {
    @Attribute(.unique) var id: UUID
    var signalID: UUID
    var timestamp: Date
    var observedStateRaw: String
    var latitude: Double
    var longitude: Double
    var speed: Double               // m/s; -1 when unknown
    var heading: Double             // degrees; -1 when unknown
    var horizontalAccuracy: Double  // meters; -1 when unknown
    var createdAt: Date
    var updatedAt: Date
    var sourceRaw: String
    var confidenceRaw: String
    var notes: String

    var observedState: ObservedState {
        get { ObservedState(rawValue: observedStateRaw) ?? .unknown }
        set { observedStateRaw = newValue.rawValue }
    }
    var source: Source {
        get { Source(rawValue: sourceRaw) ?? .observed }
        set { sourceRaw = newValue.rawValue }
    }
    var confidence: Confidence {
        get { Confidence(rawValue: confidenceRaw) ?? .low }
        set { confidenceRaw = newValue.rawValue }
    }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(signalID: UUID,
         state: ObservedState,
         coordinate: CLLocationCoordinate2D,
         timestamp: Date = .now,
         speed: Double = -1,
         heading: Double = -1,
         horizontalAccuracy: Double = -1,
         source: Source = .observed) {
        self.id = UUID()
        self.signalID = signalID
        self.timestamp = timestamp
        self.observedStateRaw = state.rawValue
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.speed = speed
        self.heading = heading
        self.horizontalAccuracy = horizontalAccuracy
        self.createdAt = .now
        self.updatedAt = .now
        self.sourceRaw = source.rawValue
        self.confidenceRaw = Confidence.low.rawValue
        self.notes = ""
    }

    /// Convenience that captures GPS metadata from a CLLocation fix.
    convenience init(signalID: UUID, state: ObservedState, location: CLLocation,
                     source: Source = .observed) {
        self.init(
            signalID: signalID,
            state: state,
            coordinate: location.coordinate,
            timestamp: location.timestamp,
            speed: location.speed >= 0 ? location.speed : -1,
            heading: location.course >= 0 ? location.course : -1,
            horizontalAccuracy: location.horizontalAccuracy,
            source: source
        )
    }
}
