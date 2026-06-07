import SwiftUI

/// Dark racing-dashboard styling. The Swift equivalent of the spec's
/// colors/spacing/typography modules, kept as one namespace to avoid sprawl.
enum Theme {
    enum Colors {
        static let background = Color.black
        static let surface = Color(white: 0.12)
        static let primary = Color(red: 0.0, green: 0.85, blue: 0.45)   // racing green
        static let accent = Color(red: 1.0, green: 0.27, blue: 0.0)     // redline
        static let text = Color.white
        static let textSecondary = Color(white: 0.62)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Typography {
        static let value = Font.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()
        static let label = Font.system(size: 14, weight: .medium, design: .rounded)
    }
}
