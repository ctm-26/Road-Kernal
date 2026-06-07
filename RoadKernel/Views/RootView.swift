import SwiftUI

/// App entry: the existing map plus the telemetry dashboard and settings, in a
/// dark racing theme. Settings are shared across tabs.
struct RootView: View {
    @StateObject private var settings = SettingsStore()

    var body: some View {
        TabView {
            MapScreen()
                .tabItem { Label("Map", systemImage: "map") }
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
