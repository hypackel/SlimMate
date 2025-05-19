import Cocoa
import SwiftUI
import AppKit // Import AppKit for NSWindow and related types

class HUDWindowController: NSWindowController {
    
    private var volumeMonitor: VolumeMonitor? // Placeholder for VolumeMonitor
    private var windowController: WindowController? // Placeholder for WindowController
    
    init(volumeMonitor: VolumeMonitor, windowController: WindowController) {
        self.volumeMonitor = volumeMonitor
        self.windowController = windowController
        
        // Create the SwiftUI content view
        let contentView = ContentView()
            .environmentObject(volumeMonitor) // Provide VolumeMonitor
            .environmentObject(windowController) // Provide WindowController
        
        // Create the hosting controller
        let hostingController = NSHostingController(rootView: contentView)
        
        // Create the NSWindow with HUD style mask
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 50), // Match ContentView HUD size
            styleMask: [.hudWindow, .nonactivatingPanel, .borderless], // Set styleMask for HUD
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating // Make the window appear above normal windows
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient] // Keep it on all spaces and ignore Mission Control/Dock
        window.appearance = NSAppearance(named: .darkAqua) // Force dark appearance
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Add methods to control the window
    func showWindow() {
        window?.orderFront(nil)
        centerWindow()
    }
    
    func hideWindow() {
        window?.orderOut(nil)
    }
    
    private func centerWindow() {
        if let window = window, let screen = NSScreen.main {
            let screenFrame = screen.frame
            let visibleFrame = screen.visibleFrame
            let windowSize = window.frame.size
            
            // Horizontal positioning: centered on the screen with a visual adjustment
            // Standard centering: screenFrame.midX - windowSize.width / 2
            // Add a negative adjustment to shift left, positive to shift right
            let horizontalVisualAdjustment: CGFloat = -120 // Adjust this value for fine-tuning
            let x = screenFrame.midX - windowSize.width / 2 + horizontalVisualAdjustment
            
            // Vertical positioning: above the dock using visibleFrame.minY and the window's height
            let verticalOffsetAboveDock: CGFloat = windowSize.height + 10 // Dock height + height of the horizontal bar + small padding
            let y = visibleFrame.minY + verticalOffsetAboveDock
            
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
} 