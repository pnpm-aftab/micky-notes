import SwiftUI

@main
struct StickyNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
    }
}
