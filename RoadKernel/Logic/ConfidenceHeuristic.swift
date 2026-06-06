import Foundation

/// Maps observation sample count to a *suggested* confidence. Deliberately never
/// returns `.verified` — verification stays a human act, and we never overclaim
/// (docs/CRITIQUE.md §3). This is the seed of the later timing-confidence engine.
enum ConfidenceHeuristic {
    static func suggested(sampleCount: Int) -> Confidence {
        switch sampleCount {
        case ..<4: return .low
        case 4..<10: return .medium
        default: return .high
        }
    }
}
