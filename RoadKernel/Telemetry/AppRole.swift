import UIKit

/// How this device behaves in the companion setup. One codebase, two roles:
/// the iPhone supplies GPS telemetry (controller), the iPad renders the big
/// dashboard. Either can run standalone; both default by device but are overridable.
enum AppRole: String, CaseIterable, Identifiable {
    case dashboard
    case controller

    var id: String { rawValue }
    var label: String { self == .dashboard ? "Dashboard" : "Controller" }

    static var deviceDefault: AppRole {
        UIDevice.current.userInterfaceIdiom == .pad ? .dashboard : .controller
    }
}
