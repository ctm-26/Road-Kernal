import Foundation

/// A snapshot of user preferences (the spec's AppSettings type).
struct AppSettings: Equatable {
    var useMetric: Bool
    var mockMode: Bool
}

/// Persisted settings the views observe — the equivalent of the spec's
/// `useSettings` hook. Backed by UserDefaults so changes survive relaunch.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var useMetric: Bool { didSet { defaults.set(useMetric, forKey: Keys.useMetric) } }
    @Published var mockMode: Bool { didSet { defaults.set(mockMode, forKey: Keys.mockMode) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.useMetric = defaults.bool(forKey: Keys.useMetric)
        self.mockMode = defaults.bool(forKey: Keys.mockMode)
    }

    var settings: AppSettings { AppSettings(useMetric: useMetric, mockMode: mockMode) }

    private enum Keys {
        static let useMetric = "settings.useMetric"
        static let mockMode = "settings.mockMode"
    }
}
