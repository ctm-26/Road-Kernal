import SwiftUI

/// iPad-friendly racing dashboard. Pure view driven by a TelemetryData value.
/// Fields a phone can't measure show "—" unless a source supplies them.
struct DashboardView: View {
    let telemetry: TelemetryData
    let useMetric: Bool

    private var speed: Double { useMetric ? telemetry.speedKilometersPerHour : telemetry.speedMilesPerHour }
    private var speedUnit: String { useMetric ? "km/h" : "mph" }
    private var speedMax: Double { useMetric ? 320 : 200 }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                HStack(spacing: Theme.Spacing.lg) {
                    Gauge(value: speed, maxValue: speedMax, label: "Speed", unit: speedUnit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                    Gauge(value: telemetry.rpm ?? 0, maxValue: 9000, label: "RPM", unit: "rpm",
                          tint: Theme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.md)],
                          spacing: Theme.Spacing.md) {
                    TelemetryCard(label: "Gear", value: telemetry.gear.map(String.init) ?? "—")
                    TelemetryCard(label: "Throttle", value: percent(telemetry.throttle), tint: Theme.Colors.primary)
                    TelemetryCard(label: "Brake", value: percent(telemetry.brake), tint: Theme.Colors.accent)
                    TelemetryCard(label: "Fuel", value: telemetry.fuelPercent.map { String(format: "%.0f%%", $0) } ?? "—")
                    TelemetryCard(label: "Lap", value: telemetry.currentLap.map(String.init) ?? "—")
                    TelemetryCard(label: "Position", value: telemetry.position.map { "P\($0)" } ?? "—")
                    TelemetryCard(label: "Heading", value: heading)
                    TelemetryCard(label: "GPS ±", value: accuracy)
                }
            }
            .padding(Theme.Spacing.md)
        }
    }

    private var heading: String {
        telemetry.headingDegrees >= 0 ? String(format: "%.0f°", telemetry.headingDegrees) : "—"
    }
    private var accuracy: String {
        telemetry.horizontalAccuracy >= 0 ? String(format: "%.0f m", telemetry.horizontalAccuracy) : "—"
    }
    private func percent(_ value: Double?) -> String {
        value.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
    }
}
