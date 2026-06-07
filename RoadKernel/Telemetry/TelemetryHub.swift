import Foundation
import Combine

/// Orchestrates role + source + link into one observable the views bind to —
/// the equivalent of the spec's `useTelemetry` hook. Exposes telemetry,
/// connectionStatus, connect(), disconnect(), and isMockMode.
@MainActor
final class TelemetryHub: ObservableObject {
    @Published var role: AppRole
    @Published var useMock: Bool
    @Published private(set) var telemetry: TelemetryData = .empty
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected

    private let link = TelemetryLink()
    private var source: TelemetrySource?
    private var cancellables = Set<AnyCancellable>()

    init(role: AppRole = .deviceDefault, useMock: Bool = false) {
        self.role = role
        self.useMock = useMock
    }

    var isMockMode: Bool { useMock }

    func connect() {
        disconnect()
        link.$status.sink { [weak self] in self?.connectionStatus = $0 }.store(in: &cancellables)

        switch role {
        case .controller:
            let source = makeSource()
            self.source = source
            link.startBroadcasting()
            source.samples.sink { [weak self] sample in
                self?.telemetry = sample
                self?.link.send(sample)
            }.store(in: &cancellables)
            source.start()

        case .dashboard:
            if useMock {
                let source = makeSource()
                self.source = source
                source.samples.sink { [weak self] in self?.telemetry = $0 }.store(in: &cancellables)
                source.start()
                connectionStatus = .mock
            } else {
                link.startReceiving()
                link.$received.compactMap { $0 }.sink { [weak self] in self?.telemetry = $0 }.store(in: &cancellables)
            }
        }
    }

    func disconnect() {
        cancellables.removeAll()
        source?.stop()
        source = nil
        link.stop()
        telemetry = .empty
        connectionStatus = .disconnected
    }

    private func makeSource() -> TelemetrySource {
        useMock ? MockTelemetrySource() : GPSTelemetrySource()
    }
}
