import SwiftUI
import SwiftData

@main
struct ShinianApp: App {
    private let container: ModelContainer

    init() {
        _ = SyncMonitor.shared
        container = CloudSync.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ThemedRoot {
                RootView()
            }
        }
        .modelContainer(container)
    }
}
