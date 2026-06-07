import Foundation
import Combine

/// Orchestrates role + source + link into one observable the views bind to —
/// the equivalent of the spec's `useTelemetry` hook. Exposes telemetry,
/// connectionStatus, connect(), disconnect(), and isMockMode.
@MainActor
final class TelemetryHub: ObservableObject {
    @Published var role: AppRole
    @Published var sourceKind: TelemetrySourceKind
    @Published private(set) var telemetry: TelemetryData = .empty
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    @Published private(set) var peerKey: String?   // verified peer identity, when paired

    private let link = TelemetryLink()
    private var source: TelemetrySource?
    private var cancellables = Set<AnyCancellable>()

    init(role: AppRole = .deviceDefault, sourceKind: TelemetrySourceKind = .gps) {
        self.role = role
        self.sourceKind = sourceKind
    }

    var isMockMode: Bool { sourceKind == .mock }

    func connect() {
        disconnect()
        link.$status.sink { [weak self] in self?.connectionStatus = $0 }.store(in: &cancellables)
        link.$peerKey.sink { [weak self] in self?.peerKey = $0 }.store(in: &cancellables)

        switch role {
        case .controller:
            let source = makeSource()
            self.source = source
            link.startBroadcasting(identity: try? KeychainIdentity.loadOrCreate())
            source.samples.sink { [weak self] sample in
                self?.telemetry = sample
                self?.link.send(sample)
            }.store(in: &cancellables)
            source.start()

        case .dashboard:
            // Mock runs locally for standalone testing; GPS/OBD live on the
            // controller, so the dashboard receives them over the link.
            if sourceKind == .mock {
                let source = makeSource()
                self.source = source
                source.samples.sink { [weak self] in self?.telemetry = $0 }.store(in: &cancellables)
                source.start()
                connectionStatus = .mock
            } else {
                link.startReceiving(identity: try? KeychainIdentity.loadOrCreate())
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
        peerKey = nil
    }

    private func makeSource() -> TelemetrySource {
        switch sourceKind {
        case .gps: return GPSTelemetrySource()
        case .mock: return MockTelemetrySource()
        case .obd: return OBDTelemetrySource()
        }
    }
}
