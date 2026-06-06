import Foundation
import CryptoKit

/// An identity that can sign records. Pseudonymous by design — it is just a
/// keypair, with no name or personal data attached. See docs/NETWORK.md.
protocol SigningIdentity {
    var publicKey: Curve25519.Signing.PublicKey { get }
    func sign(_ data: Data) throws -> Data
}

/// The persistent per-install identity. The Ed25519 private key is generated
/// once and kept in the Keychain (this-device-only). This is the foundation the
/// future data network builds on: every shared record is signed by this key.
struct KeychainIdentity: SigningIdentity {
    let privateKey: Curve25519.Signing.PrivateKey

    var publicKey: Curve25519.Signing.PublicKey { privateKey.publicKey }
    func sign(_ data: Data) throws -> Data { try privateKey.signature(for: data) }

    private static let service = "com.roadkernel.identity"
    private static let account = "device-signing-key"

    static func loadOrCreate() throws -> KeychainIdentity {
        if let data = Keychain.load(account: account, service: service),
           let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) {
            return KeychainIdentity(privateKey: key)
        }
        let key = Curve25519.Signing.PrivateKey()
        try Keychain.save(key.rawRepresentation, account: account, service: service)
        return KeychainIdentity(privateKey: key)
    }
}

/// In-memory identity for tests and SwiftUI previews — never persisted.
struct EphemeralIdentity: SigningIdentity {
    let privateKey = Curve25519.Signing.PrivateKey()
    var publicKey: Curve25519.Signing.PublicKey { privateKey.publicKey }
    func sign(_ data: Data) throws -> Data { try privateKey.signature(for: data) }
}
