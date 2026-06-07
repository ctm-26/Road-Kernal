import SwiftUI
import SwiftData

@main
struct RoadKernelApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // SwiftData persists to SQLite under the hood.
        .modelContainer(for: [Signal.self, SignalObservation.self])
    }
}
