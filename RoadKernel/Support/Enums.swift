import Foundation

/// Shared enums used across the data model.
///
/// v0.1 actively uses `Source` and `Confidence` (on `Signal`). The remaining
/// enums are defined now because later phases attach them to observations and
/// approaches — see docs/ARCHITECTURE.md §4. Keeping them here avoids churn
/// when those phases land.

enum Source: String, Codable, CaseIterable {
    case manual, imported, observed, estimated
}

enum Confidence: String, Codable, CaseIterable {
    case low, medium, high, verified
}

/// Bound travel direction at a signal (phase 3+).
enum Direction: String, Codable, CaseIterable {
    case north, south, east, west, unknown
}

/// Movement an approach controls (phase 3+).
enum Movement: String, Codable, CaseIterable {
    case straight, left, right, uTurn, pedestrian, unknown
}

/// Observed light state (v0.2+).
enum ObservedState: String, Codable, CaseIterable {
    case red, yellow, green, greenArrow, redArrow, unknown
}
