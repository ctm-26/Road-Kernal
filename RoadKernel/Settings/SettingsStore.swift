import Foundation

/// A snapshot of user preferences (the spec's AppSettings type).
struct AppSettings: Equatable {
    var useMetric: Bool
    var sourceKind: TelemetrySourceKind
}

/// Persisted settings the views observe — the equivalent of the spec's
/// `useSettings` hook. Backed by UserDefaults so changes survive relaunch.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var useMetric: Bool { didSet { defaults.set(useMetric, forKey: Keys.useMetric) } }
    @Published var sourceKind: TelemetrySourceKind { didSet { defaults.set(sourceKind.rawValue, forKey: Keys.sourceKind) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.useMetric = defaults.bool(forKey: Keys.useMetric)
        self.sourceKind = TelemetrySourceKind(rawValue: defaults.string(forKey: Keys.sourceKind) ?? "") ?? .gps
    }

    var settings: AppSettings { AppSettings(useMetric: useMetric, sourceKind: sourceKind) }

    private enum Keys {
        static let useMetric = "settings.useMetric"
        static let sourceKind = "settings.sourceKind"
    }
}
