import Foundation
import CryptoKit

/// Authenticates a pairing using the device's signing identity (the crypto
/// foundation's Curve25519 key). Each side signs a fresh nonce; the other side
/// verifies it before connecting, proving the peer truly holds the private key
/// for the public key it presents — pseudonymous, no central authority.
///
/// Mutual: the advertiser publishes a signed proof in its Bonjour discovery info
/// (verified by the browser before it invites), and the browser returns a signed
/// proof as the invitation context (verified by the advertiser before it accepts).
///
/// TODO: bind the proof to the specific peer/session to prevent replay, and add
///       a trusted-key store (TOFU prompt) so only known peers connect.
enum PeerPairing {
    private static let keyField = "pk"
    private static let nonceField = "n"
    private static let signatureField = "sig"

    /// A signed proof of key possession, as a string dictionary (for discovery info).
    static func proof(identity: SigningIdentity) -> [String: String]? {
        let nonce = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        guard let signature = try? identity.sign(nonce) else { return nil }
        return [
            keyField: identity.publicKey.rawRepresentation.base64EncodedString(),
            nonceField: nonce.base64EncodedString(),
            signatureField: signature.base64EncodedString()
        ]
    }

    /// The same proof encoded as Data (for the invitation context).
    static func proofData(identity: SigningIdentity) -> Data? {
        proof(identity: identity).flatMap { try? JSONEncoder().encode($0) }
    }

    /// Returns the verified public key (base64) if the proof is valid, else nil.
    static func verifiedKey(from info: [String: String]?) -> String? {
        guard let info,
              let keyB64 = info[keyField],
              let nonce = info[nonceField].flatMap({ Data(base64Encoded: $0) }),
              let signature = info[signatureField].flatMap({ Data(base64Encoded: $0) }),
              let keyData = Data(base64Encoded: keyB64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              key.isValidSignature(signature, for: nonce)
        else { return nil }
        return keyB64
    }

    static func verifiedKey(fromContext data: Data?) -> String? {
        guard let data,
              let info = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }
        return verifiedKey(from: info)
    }

    /// Short, human-readable fingerprint of a base64 public key.
    static func fingerprint(_ keyBase64: String) -> String {
        String(keyBase64.prefix(8))
    }
}
