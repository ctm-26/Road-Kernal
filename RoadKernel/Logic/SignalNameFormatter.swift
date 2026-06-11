import CoreLocation
import Foundation

/// Builds compact map labels for marked signals from geocoder/address text.
enum SignalNameFormatter {
    static func condensedName(from placemark: CLPlacemark) -> String? {
        let candidates = [
            placemark.name,
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality
        ]
        return condensedName(from: candidates.compactMap { $0 })
    }

    static func condensedName(from parts: [String]) -> String? {
        let tokens = parts
            .flatMap { $0.components(separatedBy: CharacterSet(charactersIn: "&/@,|-")) }
            .map(normalize)
            .filter { !$0.isEmpty }

        var unique: [String] = []
        for token in tokens where !unique.contains(token) {
            unique.append(token)
        }

        guard !unique.isEmpty else { return nil }
        return unique.prefix(2).joined(separator: " & ").uppercased()
    }

    static func fallbackName(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "SIGNAL %.4F %.4F", coordinate.latitude, coordinate.longitude).uppercased()
    }

    private static func normalize(_ text: String) -> String {
        let words = text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .map { trimStreetSuffix($0) }
            .filter { !$0.isEmpty }

        return words.joined(separator: " ")
    }

    private static func trimStreetSuffix(_ word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
        let lowercased = trimmed.lowercased()
        let suffixes: Set<String> = [
            "street", "st", "avenue", "ave", "road", "rd", "boulevard", "blvd",
            "drive", "dr", "lane", "ln", "court", "ct", "place", "pl", "parkway", "pkwy",
            "highway", "hwy", "way", "circle", "cir", "terrace", "ter"
        ]
        return suffixes.contains(lowercased) ? "" : trimmed
    }
}
