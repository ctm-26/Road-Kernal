import SwiftUI
import SwiftData

@main
struct RoadKernelApp: App {
    var body: some Scene {
        WindowGroup {
            MapScreen()
        }
        // SwiftData persists to SQLite under the hood. v0.1 stores only Signal.
        .modelContainer(for: [Signal.self])
    }
}
