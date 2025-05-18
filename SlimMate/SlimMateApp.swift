import SwiftUI
import AppKit // Import AppKit for NSApplication

@main
struct SlimMateApp: App {
    var body: some Scene {
        // HUD window scene
        WindowGroup("VolumeHUD") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .handlesExternalEvents(matching: []) // Prevent showing in the dock
    }
}
