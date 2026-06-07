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
                Section("Telemetry source") {
                    Picker("Source", selection: $settings.sourceKind) {
                        ForEach(TelemetrySourceKind.allCases) { Text($0.label).tag($0) }
                    }
                    Text(sourceHint)
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

    private var sourceHint: String {
        switch settings.sourceKind {
        case .gps: return "Real speed/heading from the phone's GPS."
        case .mock: return "Fake racing data so the dashboard works without GPS or a paired device."
        case .obd: return "Vehicle data over OBD-II isn't implemented yet — produces no data for now."
        }
    }
}
