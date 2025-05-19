//
//  SlimMateApp.swift
//  SlimMate
//
//  Created by Aarav Mehra on 7/20/24.
//

import SwiftUI
import AppKit // Import AppKit for NSApplication

@main
struct SlimMateApp: App {
    // Create an instance of the VolumeMonitor as a StateObject at the application level
    // This ensures it lives as long as the application.
    @StateObject private var volumeMonitor = VolumeMonitor() // Keep VolumeMonitor here for global access if needed, but the HUD view uses its own.
    
    // Instantiate the WindowController at the application level
    @StateObject private var windowController = WindowController() // Keep WindowController here for global access and management

    var body: some Scene {
        // The main application window group, potentially invisible for a menubar app
        // We will control its visibility via the WindowController
        WindowGroup {
            ContentView() // The main HUD content view
                // Pass the application-level window controller to the ContentView
                // The ContentView will set the windowController.window property via WindowAccessor
                .environmentObject(windowController)
        }
        .commands {
            // Add a command group for Settings that appears in the app's main menu
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    // Action to show the settings window
                    // This requires a separate window scene or a way to present a window.
                    // We'll implement showing a settings window next.
                }
            }
        }
        
        // Add a new settings window scene
        Settings {
            SettingsView() // Placeholder for the settings view
        }
    }
}
