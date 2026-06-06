import Foundation
import CoreLocation

/// Pure nearest-signal logic. Returns *ranked candidates* rather than silently
/// auto-attaching: GPS error near dense intersections makes a single "nearest"
/// guess unreliable, so the user confirms which signal an observation belongs to
/// (docs/CRITIQUE.md §4).
enum SignalMatcher {
    static func distance(from coordinate: CLLocationCoordinate2D, to signal: Signal) -> CLLocationDistance {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let there = CLLocation(latitude: signal.latitude, longitude: signal.longitude)
        return here.distance(from: there)
    }

    /// Signals within `radius` meters of `coordinate`, nearest first.
    static func candidates(near coordinate: CLLocationCoordinate2D,
                           in signals: [Signal],
                           radius: CLLocationDistance = 60) -> [Signal] {
        signals
            .map { (signal: $0, distance: distance(from: coordinate, to: $0)) }
            .filter { $0.distance <= radius }
            .sorted { $0.distance < $1.distance }
            .map { $0.signal }
    }
}
