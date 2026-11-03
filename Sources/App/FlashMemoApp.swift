import SwiftUI
import SwiftData

@main
struct FlashMemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
        }
        .modelContainer(for: [Memo.self, MemoImage.self])
    }
}
