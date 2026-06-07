import SwiftUI

/// Compact iPhone controller: the device supplying GPS telemetry. Shows what it
/// is sending without the full dashboard.
struct ControllerView: View {
    let telemetry: TelemetryData
    let useMetric: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Gauge(value: useMetric ? telemetry.speedKilometersPerHour : telemetry.speedMilesPerHour,
                  maxValue: useMetric ? 320 : 200,
                  label: "Speed",
                  unit: useMetric ? "km/h" : "mph")
                .frame(width: 220, height: 220)

            HStack(spacing: Theme.Spacing.md) {
                TelemetryCard(label: "Heading", value: heading)
                TelemetryCard(label: "GPS ±", value: accuracy)
            }
        }
    }

    private var heading: String {
        telemetry.headingDegrees >= 0 ? String(format: "%.0f°", telemetry.headingDegrees) : "—"
    }
    private var accuracy: String {
        telemetry.horizontalAccuracy >= 0 ? String(format: "%.0f m", telemetry.horizontalAccuracy) : "—"
    }
}
