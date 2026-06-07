import Foundation
import MultipeerConnectivity

/// Live device-to-device telemetry over the local network — no server, no
/// dependencies. The controller advertises and sends; the dashboard browses and
/// receives. This is the roadmap's Phase 3 (local sync over MultipeerConnectivity)
/// transport pulled forward. Requires NSLocalNetworkUsageDescription +
/// NSBonjourServices in Info.plist (set in project.yml).
@MainActor
final class TelemetryLink: NSObject, ObservableObject {
    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var received: TelemetryData?

    private let serviceType = "rk-telemetry"
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private let encoder = JSONEncoder()

    private lazy var session: MCSession = {
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }()
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    func startBroadcasting() {
        stop()
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        status = .searching
    }

    func startReceiving() {
        stop()
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        status = .searching
    }

    func send(_ telemetry: TelemetryData) {
        guard !session.connectedPeers.isEmpty, let data = try? encoder.encode(telemetry) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }

    func stop() {
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.stopBrowsingForPeers(); browser = nil
        session.disconnect()
        status = .disconnected
        received = nil
    }

    private var isSearching: Bool { advertiser != nil || browser != nil }
}

extension TelemetryLink: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected: self.status = .connected
            case .connecting: self.status = .searching
            case .notConnected: self.status = self.isSearching ? .searching : .disconnected
            @unknown default: break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let telemetry = try? JSONDecoder().decode(TelemetryData.self, from: data) else { return }
        Task { @MainActor in self.received = telemetry }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension TelemetryLink: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in invitationHandler(true, self.session) }
    }
}

extension TelemetryLink: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
