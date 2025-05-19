import Cocoa
import SwiftUI
import AppKit
import Foundation // For getuid()
// import SlimMate.Services // Import the Services module where VolumeMonitor and WindowController reside

// Create a global reference to the settings window controller
// This is a simple way to manage the settings window lifecycle
// In a more complex app, you might use a dedicated AppCoordinator or similar pattern.
private var settingsWindowController: NSWindowController? = nil

class AppDelegate: NSObject, NSApplicationDelegate {
    // Keep VolumeMonitor and WindowController instances
    var volumeMonitor: VolumeMonitor! // Initialized in applicationDidFinishLaunching
    var windowController: WindowController! // Initialized in applicationDidFinishLaunching
    
    // Keep a reference to the status item
    private var statusItem: NSStatusItem?
    
    // Keep a reference to the HUD window
    private var hudWindow: NSWindow? // Add property for the HUD window

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the application is activated to receive key presses and menubar interactions
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Initialize VolumeMonitor and WindowController
        volumeMonitor = VolumeMonitor() // Initialize VolumeMonitor
        windowController = WindowController() // Initialize WindowController

        // Create and configure the HUD window
        let contentView = ContentView()
            .environmentObject(volumeMonitor) // Provide VolumeMonitor to ContentView
            .environmentObject(windowController) // Provide WindowController to ContentView
        let hostingController = NSHostingController(rootView: contentView)
        
        hudWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 80), // Match ContentView HUD size
            styleMask: [.hudWindow, .nonactivatingPanel, .borderless], // Set styleMask for HUD
            backing: .buffered,
            defer: false
        )
        
        if let window = hudWindow {
            window.contentViewController = hostingController
            window.level = .floating // Make the window appear above normal windows
            window.collectionBehavior = [.canJoinAllSpaces, .managed] // Keep it on all spaces and hide from Mission Control/Dock
            window.isOpaque = false // Make it transparent
            window.backgroundColor = .clear // Clear background
            window.center() // Center initially, positioning will be handled by WindowController
            window.orderOut(nil) // Hide initially
            
            // Pass the created HUD window directly to the WindowController owned by AppDelegate
            windowController.window = window
            
            // Enforce the initial hidden state - this should now work reliably
            windowController.hideWindow() // Ensure it's hidden on launch
        }

        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Set the button title or image
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "Volume") // Use a system icon
        }
        
        // Create and assign the menu
        let menu = NSMenu()
        let settingsMenuItem = NSMenuItem(title: "Settings...", action: #selector(StatusBarController.openSettings), keyEquivalent: ",")
        settingsMenuItem.target = StatusBarController.shared // Explicitly set the target
        menu.addItem(settingsMenuItem)
        menu.addItem(NSMenuItem.separator()) // Add a separator
        menu.addItem(NSMenuItem(title: "Quit SlimMate", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        // Set the shared instance for AppKit actions to call into SwiftUI context
        StatusBarController.shared.setAppObjects(volumeMonitor: volumeMonitor, windowController: windowController)
        
        // Ensure the HUD window is hidden on launch
        hudWindow?.orderOut(nil)
        
        // Attempt to stop the default macOS volume HUD
        stopDefaultHUD()
    }
    
    // Optional: Implement this to clean up resources before the application terminates
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources if necessary
        // You might want to re-enable the default HUD here if needed
        startDefaultHUD()
    }
    
    // Function to stop the default macOS volume HUD (OSDUIHelper)
    private func stopDefaultHUD() {
        print("Attempting to stop default macOS HUD (OSDUIHelper)...")
        do {
            let kickstartTask = Process()
            kickstartTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            // Kickstart the OSDUIHelper in the current user's GUI session
            // Using getuid() to find the correct session for the current user
            kickstartTask.arguments = ["kickstart", "gui/\(getuid())/com.apple.OSDUIHelper"]
            try kickstartTask.run()
            kickstartTask.waitUntilExit()
            
            // Give it a moment to start before trying to stop it
            usleep(500000) // Sleep for 0.5 seconds
            
            let stopTask = Process()
            stopTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            // Send SIGSTOP signal to pause the process
            stopTask.arguments = ["-STOP", "OSDUIHelper"]
            try stopTask.run()
            stopTask.waitUntilExit()
            print("Default macOS HUD (OSDUIHelper) should now be stopped.")
        } catch {
            NSLog("Error trying to stop OSDUIHelper: \(error)")
            print("Failed to stop default macOS HUD. Error: \(error)")
        }
    }
    
    // Function to re-enable the default macOS volume HUD (OSDUIHelper)
    private func startDefaultHUD() {
         print("Attempting to re-enable default macOS HUD (OSDUIHelper)...")
         do {
             let killTask = Process()
             killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
             // Send SIGKILL signal to terminate the paused process, which should allow it to restart normally
             killTask.arguments = ["-9", "OSDUIHelper"]
             try killTask.run()
             killTask.waitUntilExit()
              print("Default macOS HUD (OSDUIHelper) should now be re-enabled.")
         } catch {
             NSLog("Error trying to re-enable OSDUIHelper: \(error)")
             print("Failed to re-enable default macOS HUD. Error: \(error)")
         }
     }
}

// Helper class to bridge AppKit actions to SwiftUI StateObjects/ObservableObjects
@objc class StatusBarController: NSObject {
    static let shared = StatusBarController()
    
    // Keep weak references to avoid retain cycles
    private weak var volumeMonitor: VolumeMonitor?
    private weak var windowController: WindowController? // Keep a weak reference

    func setAppObjects(volumeMonitor: VolumeMonitor, windowController: WindowController) {
        self.volumeMonitor = volumeMonitor
        self.windowController = windowController
    }
    
    // Action to open the settings window
    @objc func openSettings() {
        // Ensure volumeMonitor is available before proceeding
        guard let monitor = volumeMonitor else {
            print("VolumeMonitor is nil, cannot open settings.")
            return
        }
        
        if settingsWindowController == nil {
            let settingsView = SettingsView().environmentObject(monitor)
            let hostingController = NSHostingController(rootView: settingsView)
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), // Initial size
                styleMask: [.titled, .closable, .resizable], // Window style
                backing: .buffered,
                defer: false
            )
            settingsWindow.contentViewController = hostingController
            settingsWindow.center()
            settingsWindow.title = "SlimMate Settings"
            settingsWindowController = NSWindowController(window: settingsWindow)
        }
        
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil) // Bring to front
        NSApplication.shared.activate(ignoringOtherApps: true) // Activate the application
    }
}

// VolumeMonitor and WindowController definitions should ideally be in their own files
// or accessible from here if they remain in ContentView.swift. For this structure,
// they need to be accessible at the AppDelegate level.
// Assuming VolumeMonitor and WindowController are defined in ContentView.swift
// and that file is part of the target, they should be visible here. 