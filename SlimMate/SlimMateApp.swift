//
//  SlimMateApp.swift
//  SlimMate
//
//  Created by Aarav Mehra on 7/20/24.
//

import SwiftUI
import AppKit

// Create a global reference to the settings window controller
// This is a simple way to manage the settings window lifecycle
// In a more complex app, you might use a dedicated AppCoordinator or similar pattern.
private var settingsWindowController: NSWindowController? = nil

@main
struct SlimMateApp: App {
    // Use NSApplicationDelegateAdaptor to connect to our AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // An empty WindowGroup is needed to satisfy the App protocol, but it won't be visible.
        // The menubar item and settings window are managed by the AppDelegate.
        WindowGroup {}
    }
}
