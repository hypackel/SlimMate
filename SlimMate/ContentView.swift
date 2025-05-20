//
//  ContentView.swift
//  SlimMate
//
//

import SwiftUI
import CoreAudio // Import CoreAudio framework
import Foundation // Import Foundation for Timer
import AppKit // Import AppKit

// Struct to wrap NSVisualEffectView for AppKit-based visual effects
struct VisualEffectView: NSViewRepresentable {
    // Remove @Environment colorScheme from here as we'll try a different approach
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // Configure the visual effect view
        view.material = .hudWindow // Use .hudWindow material for a HUD-specific dark blur
        view.state = .active // Apply the effect actively
        view.blendingMode = .behindWindow // Important for layering within the window
        view.isEmphasized = true // May help in ensuring a distinct appearance
        // Do NOT set appearance explicitly here; rely on material + blendingMode + isEmphasized
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // No explicit appearance setting needed here with this approach
    }
}

// Keep the WindowController class but remove the StateObject in ContentView
// class WindowController: ObservableObject {
// ... existing code ...
// }

struct ContentView: View {
    // VolumeMonitor and WindowController are now provided via the environment
    @EnvironmentObject private var volumeMonitor: VolumeMonitor
    @EnvironmentObject private var windowController: WindowController
    @EnvironmentObject private var brightnessMonitor: BrightnessMonitor // Add BrightnessMonitor environment object
    @Environment(\.colorScheme) var colorScheme // Add environment variable to detect color scheme
    
    // State to control the visibility of the HUD content
    @State private var isHUDVisible = false
    @State private var isBrightnessHUDVisible = false // State for brightness HUD visibility
    
    private let hideDelay: Double = 2.0 // Seconds to keep visible after volume change
    @State private var hideTask: DispatchWorkItem? = nil // To keep track of the hide task
    
    private let hideBrightnessDelay: Double = 2.0 // Seconds to keep visible after brightness change
    @State private var hideBrightnessTask: DispatchWorkItem? = nil // To keep track of the hide brightness task

    var body: some View {
        // The ZStack contains the HUD content
        ZStack {
            if isHUDVisible { // Volume HUD
                ZStack { // Use ZStack to layer background and content
                    RoundedRectangle(cornerRadius: 20)
                        .background(VisualEffectView()) // Use NSVisualEffectView for background
                        .frame(width: 220, height: 50) // Apply frame to the background shape
                    
                    // Add a semi-transparent black overlay to force dark appearance
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.5)) // Adjust opacity for darker and more translucent effect
                        .frame(width: 220, height: 50) // Apply frame to the overlay
                    
                    HStack(spacing: 8) {
                        Image(systemName: volumeMonitor.volumeLevel == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                        ProgressView(value: volumeMonitor.volumeLevel)
                            .progressViewStyle(LinearProgressViewStyle(tint: .primary))
                            .frame(width: 140)
                    }
                    .foregroundStyle(.primary) // Apply foreground style to the HStack
                    .frame(width: 160)
                }
                .transition(.opacity) // Apply transition to the ZStack
                .foregroundStyle(.primary) // Explicitly set foreground style for the ZStack content
                .onAppear { // Add onAppear to log color scheme
                    print("Volume HUD appeared. Detected color scheme: \(colorScheme)")
                }
                .onChange(of: colorScheme) { oldScheme, newScheme in // Add onChange to log color scheme changes
                    print("Volume HUD color scheme changed from \(oldScheme) to \(newScheme)")
                }
            } else if isBrightnessHUDVisible { // Brightness HUD
                ZStack { // Use ZStack to layer background and content
                    RoundedRectangle(cornerRadius: 20)
                        .background(VisualEffectView()) // Use NSVisualEffectView for background
                        .frame(width: 220, height: 50) // Apply frame to the background shape
                    
                    // Add a semi-transparent black overlay to force dark appearance
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.5)) // Adjust opacity for darker and more translucent effect
                        .frame(width: 220, height: 50) // Apply frame to the overlay
                    
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill") // Brightness icon
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                        ProgressView(value: brightnessMonitor.brightnessLevel)
                            .progressViewStyle(LinearProgressViewStyle(tint: .primary))
                            .frame(width: 140)
                    }
                    .foregroundStyle(.primary) // Apply foreground style to the HStack
                    .frame(width: 160)
                }
                .transition(.opacity) // Apply transition to the ZStack
                .foregroundStyle(.primary) // Explicitly set foreground style for the ZStack content
                .onAppear { // Add onAppear to log color scheme
                    print("Brightness HUD appeared. Detected color scheme: \(colorScheme)")
                }
                .onChange(of: colorScheme) { oldScheme, newScheme in // Add onChange to log color scheme changes
                    print("Brightness HUD color scheme changed from \(oldScheme) to \(newScheme)")
                }
            }
        }
        // Remove the WindowAccessor background modifier
        // .background(
        //      // Use WindowAccessor to get the NSWindow and pass it to the controller
        //     WindowAccessor {
        //         self.windowController.window = $0
        //         // Initially hide the window
        //         self.windowController.hideWindow()
        //     }
        // )
        .animation(.easeInOut(duration: 0.3), value: isHUDVisible || isBrightnessHUDVisible) // Animate based on either HUD being visible
        // Use the isHUDVisible state to control the window visibility via the controller
        // Explicitly animate volume decrease
        .onChange(of: volumeMonitor.volumeLevel) { oldVolume, newVolume in
            // Only trigger visibility change if volume actually changes to avoid showing on initial load
            if abs(newVolume - oldVolume) > 0.001 { 
                isHUDVisible = true // Show volume HUD
                isBrightnessHUDVisible = false // Hide brightness HUD
                
                // Cancel the previous hide task if it exists
                hideTask?.cancel()
                hideBrightnessTask?.cancel() // Cancel brightness hide task as well
                
                // Schedule a new hide task for volume HUD
                let task = DispatchWorkItem { 
                    isHUDVisible = false // Hide volume HUD
                }
                hideTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: task)
                
                // Conditionally apply animation for volume decrease
                if newVolume < oldVolume {
                    withAnimation(.easeInOut(duration: volumeMonitor.interpolationDuration)) {
                         // This block is needed to implicitly animate the change to volumeMonitor.volumeLevel
                         // which is already handled by the VolumeMonitor's interpolation timer.
                         // However, keeping it here makes the intent clear, although the actual animation
                         // smoothing comes from the Timer-based interpolation in VolumeMonitor.
                         // There isn't a direct way in SwiftUI onChange to observe and animate a value
                         // whose updates are driven by a separate Timer. The VolumeMonitor's role
                         // is to update volumeLevel over time during decrease. The SwiftUI view
                         // observes the final or intermediate values of volumeLevel and updates.
                         // Removing the .animation modifier means SwiftUI will update the ProgressView
                         // instantly *unless* the state change is already animated (like from the Timer).
                         // So, the VolumeMonitor's Timer updates will appear animated, while direct
                         // updates (volume up) will be instant.
                    }
                }
                 // For volume increase (newVolume >= oldVolume), volumeLevel is updated instantly
                 // in handleVolumeUpdate, and SwiftUI will reflect this instantly without the .animation modifier.
            }
        }
        // Observe changes in brightness level
        .onChange(of: brightnessMonitor.brightnessLevel) { oldBrightness, newBrightness in
             // Only trigger visibility change if brightness actually changes
             if abs(newBrightness - oldBrightness) > 0.001 {
                 isBrightnessHUDVisible = true // Show brightness HUD
                 isHUDVisible = false // Hide volume HUD
                 
                 // Cancel existing hide tasks
                 hideTask?.cancel() // Cancel volume hide task as well
                 hideBrightnessTask?.cancel()
                 
                 // Schedule a new hide task for brightness HUD
                 let task = DispatchWorkItem {
                     isBrightnessHUDVisible = false // Hide brightness HUD
                 }
                 hideBrightnessTask = task
                 DispatchQueue.main.asyncAfter(deadline: .now() + hideBrightnessDelay, execute: task)
                 
                 // No specific animation interpolation for brightness needed currently, 
                 // as setBrightness updates the level directly.
             }
        }
        // Observe the HUD visibility states and tell the controller to show/hide the window
        .onChange(of: isHUDVisible || isBrightnessHUDVisible) { _, newValue in
            windowController.setVisibility(newValue)
        }
    }
}

// Remove the SettingsView preview for now, as it relies on environment objects
/*
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
*/
