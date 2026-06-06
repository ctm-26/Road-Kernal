import Foundation
import CoreLocation

/// CoreLocation wrapper following the canonical pattern (docs/ARCHITECTURE.md §1.4):
/// an NSObject + CLLocationManagerDelegate + ObservableObject, with a strong
/// reference to the manager and authorization requested on the main thread.
///
/// Delegate callbacks are marked `nonisolated` and hop to the main actor before
/// touching published state, which keeps it correct under Swift strict concurrency.
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()   // strong reference is required

    @Published var location: CLLocation?
    @Published var authorization: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorization = manager.authorizationStatus
    }

    /// Triggers the system permission prompt. Requires
    /// NSLocationWhenInUseUsageDescription in Info.plist or the app crashes.
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.location = last }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // v0.1: intentionally ignored. Debug Mode (later phase) will surface this.
    }
}
