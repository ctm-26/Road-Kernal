import SwiftUI

/// Pill showing the live-link state.
struct ConnectionStatusBadge: View {
    let status: ConnectionStatus

    private var color: Color {
        switch status {
        case .connected: return Theme.Colors.primary
        case .searching: return .yellow
        case .mock: return .blue
        case .disconnected: return Theme.Colors.textSecondary
        }
    }

    private var text: String {
        switch status {
        case .connected: return "Connected"
        case .searching: return "Searching…"
        case .mock: return "Mock"
        case .disconnected: return "Disconnected"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text).font(Theme.Typography.label).foregroundStyle(Theme.Colors.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.Colors.surface, in: Capsule())
    }
}
