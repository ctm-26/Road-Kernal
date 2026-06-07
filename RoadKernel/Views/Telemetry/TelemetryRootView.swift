import SwiftUI

/// Role-switched telemetry screen: pick Dashboard or Controller, connect/start,
/// and view live data. Reads units/mock from settings.
struct TelemetryRootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var hub = TelemetryHub()

    private var isLive: Bool { hub.connectionStatus != .disconnected }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                header

                switch hub.role {
                case .dashboard:
                    DashboardView(telemetry: hub.telemetry, useMetric: settings.useMetric)
                case .controller:
                    ControllerView(telemetry: hub.telemetry, useMetric: settings.useMetric)
                }

                Spacer(minLength: 0)
                controls
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Picker("Role", selection: $hub.role) {
                    ForEach(AppRole.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(isLive)

                ConnectionStatusBadge(status: hub.connectionStatus)
            }

            if let peerKey = hub.peerKey {
                Label("Verified peer · \(PeerPairing.fingerprint(peerKey))", systemImage: "checkmark.seal.fill")
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: Theme.Spacing.md) {
            if isLive {
                Button(role: .destructive) { hub.disconnect() } label: {
                    Label("Disconnect", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    hub.sourceKind = settings.sourceKind
                    hub.connect()
                } label: {
                    Label(connectTitle, systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.primary)
            }
        }
    }

    private var connectTitle: String {
        if settings.sourceKind == .mock { return "Start Mock" }
        return hub.role == .dashboard ? "Connect to Controller" : "Start Broadcasting"
    }
}
