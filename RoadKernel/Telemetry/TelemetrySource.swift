import Foundation
import Combine
import CoreLocation

/// A replaceable producer of telemetry samples. Keeping this behind a protocol
/// means real GPS now and a vehicle/OBD source later are interchangeable.
@MainActor
protocol TelemetrySource: AnyObject {
    var samples: AnyPublisher<TelemetryData, Never> { get }
    func start()
    func stop()
}

/// Real telemetry from the phone's GPS, reusing the app's LocationManager.
@MainActor
final class GPSTelemetrySource: TelemetrySource {
    private let location = LocationManager()
    private let subject = PassthroughSubject<TelemetryData, Never>()
    private var cancellable: AnyCancellable?

    var samples: AnyPublisher<TelemetryData, Never> { subject.eraseToAnyPublisher() }

    func start() {
        location.requestAuthorization()
        location.start()
        cancellable = location.$location.compactMap { $0 }.sink { [weak self] fix in
            self?.subject.send(TelemetryData(
                timestamp: fix.timestamp,
                speedMetersPerSecond: fix.speed >= 0 ? fix.speed : -1,
                headingDegrees: fix.course >= 0 ? fix.course : -1,
                horizontalAccuracy: fix.horizontalAccuracy
            ))
        }
    }

    func stop() { cancellable = nil }
}

/// Plausible fake telemetry so the dashboard works without GPS or a paired
/// device — covers the GT7-style fields a phone can't actually measure.
@MainActor
final class MockTelemetrySource: TelemetrySource {
    private let subject = PassthroughSubject<TelemetryData, Never>()
    private var timer: Timer?
    private var t: Double = 0

    var samples: AnyPublisher<TelemetryData, Never> { subject.eraseToAnyPublisher() }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        t += 0.1
        let speed = (sin(t / 3) * 0.5 + 0.5) * 65   // 0...65 m/s
        var sample = TelemetryData(
            timestamp: .now,
            speedMetersPerSecond: speed,
            headingDegrees: (t * 18).truncatingRemainder(dividingBy: 360),
            horizontalAccuracy: 5
        )
        sample.rpm = 1200 + (sin(t / 1.4) * 0.5 + 0.5) * 7300
        sample.gear = max(1, min(6, Int(speed / 11) + 1))
        sample.throttle = max(0, sin(t / 2))
        sample.brake = max(0, -sin(t / 2))
        sample.fuelPercent = max(0, 100 - t.truncatingRemainder(dividingBy: 100))
        sample.currentLap = Int(t / 60) + 1
        sample.position = 3
        subject.send(sample)
    }
}
