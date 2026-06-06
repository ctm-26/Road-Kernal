import SwiftUI
import SwiftData

@main
struct RoadKernelApp: App {
    var body: some Scene {
        WindowGroup {
            MapScreen()
        }
        // SwiftData persists to SQLite under the hood.
        .modelContainer(for: [Signal.self, SignalObservation.self])
    }
}
