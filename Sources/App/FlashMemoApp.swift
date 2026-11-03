import SwiftUI
import SwiftData

@main
struct FlashMemoApp: App {
    private let container: ModelContainer

    init() {
        _ = SyncMonitor.shared
        container = CloudSync.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
