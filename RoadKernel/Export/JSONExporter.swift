import Foundation

/// Pure-function JSON export — a clear example of logic living in plain Swift,
/// fully decoupled from SwiftUI. Produces either a plain JSON dump or a *signed,
/// verifiable bundle* (the first step toward the data network — docs/NETWORK.md).
enum JSONExporter {
    struct SignalDTO: Codable {
        let id: String
        let name: String
        let intersectionName: String
        let latitude: Double
        let longitude: Double
        let confidence: String
        let source: String
        let notes: String
        let createdAt: String
        let updatedAt: String
    }

    struct Payload: Codable {
        let signals: [SignalDTO]
    }

    /// A portable bundle of signed, content-addressed records. Each record can be
    /// verified offline by any recipient; identical records dedupe by `contentHash`.
    struct SignedBundle: Codable {
        let version: Int
        let kind: String
        let exportedAt: String
        let records: [SignedRecord<SignalDTO>]
    }

    // MARK: - Plain export

    static func export(signals: [Signal]) -> String {
        let formatter = ISO8601DateFormatter()
        let dtos = signals.map { dto(for: $0, formatter: formatter) }
        return encode(Payload(signals: dtos)) ?? "{\n  \"signals\" : []\n}"
    }

    // MARK: - Signed export

    static func signedBundle(signals: [Signal], identity: SigningIdentity) throws -> SignedBundle {
        let formatter = ISO8601DateFormatter()
        let records = try signals.map {
            try RecordSigner.make(payload: dto(for: $0, formatter: formatter), identity: identity)
        }
        return SignedBundle(version: 1,
                            kind: "roadkernel.signals.v1",
                            exportedAt: formatter.string(from: .now),
                            records: records)
    }

    static func signedBundleJSON(signals: [Signal], identity: SigningIdentity) throws -> String {
        encode(try signedBundle(signals: signals, identity: identity)) ?? "{}"
    }

    // MARK: - Helpers

    static func dto(for signal: Signal, formatter: ISO8601DateFormatter) -> SignalDTO {
        SignalDTO(
            id: signal.id.uuidString,
            name: signal.name,
            intersectionName: signal.intersectionName,
            latitude: signal.latitude,
            longitude: signal.longitude,
            confidence: signal.confidence.rawValue,
            source: signal.source.rawValue,
            notes: signal.notes,
            createdAt: formatter.string(from: signal.createdAt),
            updatedAt: formatter.string(from: signal.updatedAt)
        )
    }

    private static func encode<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
