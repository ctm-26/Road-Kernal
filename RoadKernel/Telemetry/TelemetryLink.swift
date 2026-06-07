import Foundation
import UIKit
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
    @Published private(set) var peerKey: String?      // verified peer public key (base64)
    @Published private(set) var events: [String] = [] // newest first; for the debug panel

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
    private var identity: SigningIdentity?

    func startBroadcasting(identity: SigningIdentity?) {
        stop()
        events.removeAll()
        self.identity = identity
        let info = identity.flatMap { PeerPairing.proof(identity: $0) }
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        status = .searching
        note("Advertising as \(peerID.displayName) (\(info == nil ? "unsigned" : "signed"))")
    }

    func startReceiving(identity: SigningIdentity?) {
        stop()
        events.removeAll()
        self.identity = identity
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        status = .searching
        note("Browsing for peers as \(peerID.displayName)")
    }

    func send(_ telemetry: TelemetryData) {
        guard !session.connectedPeers.isEmpty, let data = try? encoder.encode(telemetry) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }

    func stop() {
        if isSearching || !session.connectedPeers.isEmpty { note("Link stopped") }
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.stopBrowsingForPeers(); browser = nil
        session.disconnect()
        status = .disconnected
        received = nil
        peerKey = nil
        identity = nil
    }

    private var isSearching: Bool { advertiser != nil || browser != nil }

    private func note(_ message: String) {
        events.insert("\(Self.timeFormatter.string(from: Date()))  \(message)", at: 0)
        if events.count > 50 { events.removeLast(events.count - 50) }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

extension TelemetryLink: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let name = peerID.displayName
        Task { @MainActor in
            switch state {
            case .connected:
                self.status = .connected
                self.note("Connected to \(name)")
            case .connecting:
                self.status = .searching
                self.note("Connecting to \(name)…")
            case .notConnected:
                self.status = self.isSearching ? .searching : .disconnected
                self.note("Disconnected from \(name)")
            @unknown default:
                break
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
        // Accept only peers that present a valid signed proof of identity.
        let name = peerID.displayName
        let verifiedKey = PeerPairing.verifiedKey(fromContext: context)
        Task { @MainActor in
            if let verifiedKey {
                self.peerKey = verifiedKey
                self.note("Accepted invitation from \(name) [\(PeerPairing.fingerprint(verifiedKey))]")
                invitationHandler(true, self.session)
            } else {
                self.note("Rejected unverified invitation from \(name)")
                invitationHandler(false, nil)
            }
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.status = .failed
            self.note("Advertising failed: \(message)")
        }
    }
}

extension TelemetryLink: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        // Invite only advertisers that present a valid signed proof of identity.
        let name = peerID.displayName
        guard let key = PeerPairing.verifiedKey(from: info) else {
            Task { @MainActor in self.note("Ignored unverified peer \(name)") }
            return
        }
        Task { @MainActor in
            self.peerKey = key
            self.note("Found verified peer \(name) [\(PeerPairing.fingerprint(key))]")
            let context = self.identity.flatMap { PeerPairing.proofData(identity: $0) }
            browser.invitePeer(peerID, to: self.session, withContext: context, timeout: 10)
            self.note("Invited \(name)")
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let name = peerID.displayName
        Task { @MainActor in self.note("Lost peer \(name)") }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.status = .failed
            self.note("Browsing failed: \(message)")
        }
    }
}
