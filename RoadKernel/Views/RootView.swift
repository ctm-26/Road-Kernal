import SwiftUI

/// App entry: the existing map plus the signal list, telemetry dashboard, and
/// settings, in a dark racing theme. Settings are shared across tabs.
struct RootView: View {
    @StateObject private var settings = SettingsStore()

    var body: some View {
        TabView {
            MapScreen()
                .tabItem { Label("Map", systemImage: "map") }
            SignalListView()
                .tabItem { Label("Signals", systemImage: "trafficlight") }
            TelemetryRootView()
                .tabItem { Label("Telemetry", systemImage: "gauge.with.dots.needle.67percent") }
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environmentObject(settings)
        .tint(Theme.Colors.primary)
        .preferredColorScheme(.dark)
    }
}
