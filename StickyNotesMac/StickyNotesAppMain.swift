import SwiftUI

@main
struct StickyNotesApp: App {
    init() {
        // Activate app as early as possible
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Force activation and bring window to front
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        if let window = NSApp.windows.first {
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                        }
                        // Also try to activate the running app
                        let app = NSRunningApplication.current
                        app.activate(options: [.activateAllWindows])
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
    }
}
