import Foundation

/// Pure-function JSON export — logic in plain Swift, decoupled from SwiftUI.
/// Produces either a plain JSON dump or a *signed, verifiable bundle* where each
/// observation block links to its signal block as a Merkle parent (docs/NETWORK.md).
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

    struct ObservationDTO: Codable {
        let id: String
        let signalID: String
        let timestamp: String
        let state: String
        let latitude: Double
        let longitude: Double
        let speed: Double
        let heading: Double
        let horizontalAccuracy: Double
        let confidence: String
        let source: String
        let notes: String
    }

    struct Payload: Codable {
        let signals: [SignalDTO]
        let observations: [ObservationDTO]
    }

    /// A portable bundle of signed, content-addressed records. Observations carry
    /// their signal's `contentHash` as a parent, linking the two into a DAG.
    struct SignedBundle: Codable {
        let version: Int
        let kind: String
        let exportedAt: String
        let signals: [SignedRecord<SignalDTO>]
        let observations: [SignedRecord<ObservationDTO>]
    }

    // MARK: - Plain export

    static func export(signals: [Signal], observations: [SignalObservation] = []) -> String {
        let formatter = ISO8601DateFormatter()
        let payload = Payload(
            signals: signals.map { dto(for: $0, formatter: formatter) },
            observations: observations.map { dto(for: $0, formatter: formatter) }
        )
        return encode(payload) ?? "{}"
    }

    // MARK: - Signed export

    static func signedBundle(signals: [Signal],
                             observations: [SignalObservation] = [],
                             identity: SigningIdentity) throws -> SignedBundle {
        let formatter = ISO8601DateFormatter()

        let signalRecords = try signals.map {
            try RecordSigner.make(payload: dto(for: $0, formatter: formatter), identity: identity)
        }

        // signalID -> content hash, so observations can link to their parent block.
        var parentHashBySignalID: [String: String] = [:]
        for (signal, record) in zip(signals, signalRecords) {
            parentHashBySignalID[signal.id.uuidString] = record.contentHash
        }

        let observationRecords = try observations.map { observation -> SignedRecord<ObservationDTO> in
            let parents = parentHashBySignalID[observation.signalID.uuidString].map { [$0] } ?? []
            return try RecordSigner.make(payload: dto(for: observation, formatter: formatter),
                                         parents: parents, identity: identity)
        }

        return SignedBundle(version: 1,
                            kind: "roadkernel.bundle.v1",
                            exportedAt: formatter.string(from: .now),
                            signals: signalRecords,
                            observations: observationRecords)
    }

    static func signedBundleJSON(signals: [Signal],
                                 observations: [SignalObservation] = [],
                                 identity: SigningIdentity) throws -> String {
        encode(try signedBundle(signals: signals, observations: observations, identity: identity)) ?? "{}"
    }

    // MARK: - DTO mapping

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

    static func dto(for observation: SignalObservation, formatter: ISO8601DateFormatter) -> ObservationDTO {
        ObservationDTO(
            id: observation.id.uuidString,
            signalID: observation.signalID.uuidString,
            timestamp: formatter.string(from: observation.timestamp),
            state: observation.observedState.rawValue,
            latitude: observation.latitude,
            longitude: observation.longitude,
            speed: observation.speed,
            heading: observation.heading,
            horizontalAccuracy: observation.horizontalAccuracy,
            confidence: observation.confidence.rawValue,
            source: observation.source.rawValue,
            notes: observation.notes
        )
    }

    private static func encode<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
