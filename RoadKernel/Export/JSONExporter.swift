import Foundation

/// Pure-function JSON export — a clear example of logic living in plain Swift,
/// fully decoupled from SwiftUI. Maps SwiftData models to a stable, portable
/// DTO shape (matches docs/ARCHITECTURE.md / the JSON example in the concept).
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

    static func export(signals: [Signal]) -> String {
        let formatter = ISO8601DateFormatter()
        let dtos = signals.map { s in
            SignalDTO(
                id: s.id.uuidString,
                name: s.name,
                intersectionName: s.intersectionName,
                latitude: s.latitude,
                longitude: s.longitude,
                confidence: s.confidence.rawValue,
                source: s.source.rawValue,
                notes: s.notes,
                createdAt: formatter.string(from: s.createdAt),
                updatedAt: formatter.string(from: s.updatedAt)
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Payload(signals: dtos)),
              let string = String(data: data, encoding: .utf8) else {
            return "{\n  \"signals\" : []\n}"
        }
        return string
    }
}
