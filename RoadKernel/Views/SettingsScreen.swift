import SwiftUI

/// Simple preferences: units, mock telemetry mode, and a theme placeholder.
struct SettingsScreen: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Toggle("Use metric (km/h)", isOn: $settings.useMetric)
                }
                Section("Telemetry") {
                    Toggle("Mock telemetry mode", isOn: $settings.mockMode)
                    Text("Mock generates fake racing data so the dashboard works without GPS or a paired device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Appearance") {
                    LabeledContent("Theme", value: "Dark (racing)")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
