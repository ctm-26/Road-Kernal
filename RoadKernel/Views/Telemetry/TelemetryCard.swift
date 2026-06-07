import SwiftUI

/// A labeled value tile used across the dashboard.
struct TelemetryCard: View {
    let label: String
    let value: String
    var tint: Color = Theme.Colors.text

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label.uppercased())
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(Theme.Typography.value)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
