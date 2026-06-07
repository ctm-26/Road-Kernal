import SwiftUI

/// Simple circular gauge for the dashboard.
struct Gauge: View {
    let value: Double
    let maxValue: Double
    let label: String
    let unit: String
    var tint: Color = Theme.Colors.primary

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.Colors.surface, lineWidth: 14)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.15), value: fraction)
            VStack(spacing: 2) {
                Text(value, format: .number.precision(.fractionLength(0)))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.Colors.text)
                Text(unit).font(Theme.Typography.label).foregroundStyle(Theme.Colors.textSecondary)
                Text(label.uppercased()).font(Theme.Typography.label).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}
