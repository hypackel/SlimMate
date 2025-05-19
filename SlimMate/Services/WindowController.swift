import SwiftUI
import AppKit // Import AppKit

// Keep the WindowController class but remove the StateObject in ContentView
class WindowController: ObservableObject {
    weak var window: NSWindow? {
        didSet {
            if let window = window {
                // Configure the window
                window.level = .floating // Make the window appear above normal windows
                window.collectionBehavior = [.canJoinAllSpaces, .managed] // Keep it on all spaces and hide from Mission Control/Dock
                window.styleMask = .borderless // Remove window borders and traffic lights
                // We\'ll center it later when it becomes visible
                window.isOpaque = false // Make it transparent
                window.backgroundColor = .clear // Clear background
                
                // Ensure the window\'s content view is set if it wasn\'t already
                // This might be redundant if NSHostingController sets it, but as a safeguard:
                // if window.contentViewController == nil {
                //     // This case is unlikely with current setup, but included for completeness
                // }
            }
        }
    }
    
    func showWindow() {
        window?.orderFront(nil)
        centerWindow()
    }
    
    func hideWindow() {
        window?.orderOut(nil)
    }
    
    private func centerWindow() {
        if let window = window {
            let screenFrame = NSScreen.main?.frame ?? .zero
            let windowSize = window.frame.size
            // Calculate position to place the window centered horizontally and higher above the dock
            let bottomPadding: CGFloat = 80 // Increased padding from the bottom
            // Adjust horizontal position with an offset
            let horizontalAdjustment: CGFloat = 150 // Subtract this to move left, add to move right
            let x = screenFrame.midX - windowSize.width / 2 - horizontalAdjustment // Apply the adjustment
            let y = screenFrame.minY + bottomPadding
            window.setFrameOrigin(CGPoint(x: x, y: y))
        }
    }
    
    // Method to toggle visibility (can be used by the ContentView logic)
    func setVisibility(_ isVisible: Bool) {
        if isVisible {
            showWindow()
        } else {
            hideWindow()
        }
    }
    
    // This method might not be needed anymore if initial hiding is handled in AppDelegate
    // func enforceInitialVisibility(isVisible: Bool) {
    //     if !isVisible {
    //         hideWindow()
    //     }
    // }
} 