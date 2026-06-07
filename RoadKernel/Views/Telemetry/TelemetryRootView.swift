import SwiftUI

/// Role-switched telemetry screen: pick Dashboard or Controller, connect/start,
/// and view live data. Reads units/source from settings. Includes a debug panel
/// for discovery/invitation/accept/reject visibility while bringing the app up.
struct TelemetryRootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var hub = TelemetryHub()

    private var isLive: Bool {
        switch hub.connectionStatus {
        case .searching, .connected, .mock: return true
        case .disconnected, .failed: return false
        }
    }

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
                debugPanel
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

            if let latest = hub.events.first {
                Text(latest)
                    .font(.caption2)
                    .foregroundStyle(hub.connectionStatus == .failed ? Theme.Colors.accent : Theme.Colors.textSecondary)
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

    private var debugPanel: some View {
        DisclosureGroup("Debug") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Role: \(hub.role.label)   Source: \(settings.sourceKind.label)   Status: \(hub.connectionStatus.rawValue)")
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(hub.events.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            .font(.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.sm)
        }
        .tint(Theme.Colors.textSecondary)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var connectTitle: String {
        if settings.sourceKind == .mock { return "Start Mock" }
        return hub.role == .dashboard ? "Connect to Controller" : "Start Broadcasting"
    }
}
