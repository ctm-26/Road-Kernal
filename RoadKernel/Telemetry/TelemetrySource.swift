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

/// Which producer drives telemetry. The selection architecture is a single enum
/// so GPS, Mock, and the future OBD source are interchangeable everywhere.
enum TelemetrySourceKind: String, CaseIterable, Identifiable {
    case gps, mock, obd

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gps: return "GPS"
        case .mock: return "Mock"
        case .obd: return "OBD (soon)"
        }
    }

    var isImplemented: Bool { self != .obd }
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
        // Use Timer(...) + add(.common) so the mock fires during scroll tracking too.
        // scheduledTimer would double-schedule when combined with add(.common).
        let newTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
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

/// Stub for real vehicle data. Conforms to TelemetrySource so it slots into the
/// existing source selection and the iPhone↔iPad link with no other changes.
/// Produces no samples yet — the dashboard simply shows "—" until implemented.
///
/// TODO: connect to an OBD-II adapter over BLE (e.g. ELM327) using CoreBluetooth
///       (system framework, no dependency) — scan, connect, open the ELM327 channel.
/// TODO: poll OBD-II PIDs and map them onto TelemetryData
///       (speed 0x0D, rpm 0x0C, throttle 0x11, fuel level 0x2F) via subject.send.
/// TODO: optionally decode manufacturer CAN frames for gear/brake where exposed.
@MainActor
final class OBDTelemetrySource: TelemetrySource {
    private let subject = PassthroughSubject<TelemetryData, Never>()

    var samples: AnyPublisher<TelemetryData, Never> { subject.eraseToAnyPublisher() }

    func start() {
        // TODO: begin BLE scan / OBD handshake, then publish decoded samples.
        // No-op until implemented so the app keeps working with OBD selected.
    }

    func stop() {
        // TODO: tear down the BLE connection.
    }
}
