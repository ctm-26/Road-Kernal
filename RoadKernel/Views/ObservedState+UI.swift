import SwiftUI

/// UI presentation for observed states. Kept out of Support/Enums.swift so the
/// enum stays Foundation-only (and reusable in non-UI contexts like export).
extension ObservedState {
    var displayColor: Color {
        switch self {
        case .red, .redArrow: return .red
        case .yellow: return .yellow
        case .green, .greenArrow: return .green
        case .unknown: return .gray
        }
    }

    var displayLabel: String {
        switch self {
        case .red: return "Red"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .greenArrow: return "Green Arrow"
        case .redArrow: return "Red Arrow"
        case .unknown: return "Unknown"
        }
    }
}
