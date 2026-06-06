import Foundation
import CryptoKit

/// A signed, content-addressed record — the atomic "block" in Road Kernel's
/// verifiable data network.
///
/// - `contentHash` is the address: SHA-256 over the canonical payload + parents.
///   Identical data ⇒ identical hash ⇒ automatic dedupe when merging peers.
/// - `parentHashes` link blocks into a Merkle DAG (the "blocks connect to other
///   blocks" structure). Empty for independent v0.1 signals.
/// - `signature` proves authorship offline, with no central authority.
///
/// This is NOT a blockchain: there is no consensus, no coin, no global ledger —
/// just signed, tamper-evident, mergeable records. See docs/NETWORK.md.
struct SignedRecord<Payload: Codable>: Codable {
    let payload: Payload
    let contentHash: String
    let parentHashes: [String]
    let authorPublicKey: String   // base64 raw Curve25519 (Ed25519) public key
    let signature: String         // base64
}

enum RecordSigner {
    /// Deterministic bytes that both hashing and signing operate on. Must be
    /// identical when signing and when verifying, or signatures won't match.
    static func signingInput<P: Encodable>(payload: P, parents: [String]) throws -> Data {
        var data = try Canonical.encode(payload)
        let parentString = parents.sorted().joined(separator: "\n")
        data.append(Data(parentString.utf8))
        return data
    }

    static func make<P: Codable>(payload: P,
                                 parents: [String] = [],
                                 identity: SigningIdentity) throws -> SignedRecord<P> {
        let input = try signingInput(payload: payload, parents: parents)
        let signature = try identity.sign(input)
        return SignedRecord(
            payload: payload,
            contentHash: Data(SHA256.hash(data: input)).hexString,
            parentHashes: parents.sorted(),
            authorPublicKey: identity.publicKey.rawRepresentation.base64EncodedString(),
            signature: signature.base64EncodedString()
        )
    }

    /// True only if the content hash matches the payload AND the signature is
    /// valid for the claimed author key. Anyone can run this offline.
    static func verify<P: Codable>(_ record: SignedRecord<P>) -> Bool {
        guard let input = try? signingInput(payload: record.payload,
                                            parents: record.parentHashes) else { return false }
        guard Data(SHA256.hash(data: input)).hexString == record.contentHash else { return false }
        guard let keyData = Data(base64Encoded: record.authorPublicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              let signature = Data(base64Encoded: record.signature) else { return false }
        return key.isValidSignature(signature, for: input)
    }
}

/// Stable, compact JSON for hashing/signing: sorted keys, no whitespace, no
/// slash escaping — so the same content always produces the same bytes.
enum Canonical {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

private extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
