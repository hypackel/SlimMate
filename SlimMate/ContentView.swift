//
//  ContentView.swift
//  SlimMate
//
//

import SwiftUI
import CoreAudio // Import CoreAudio framework
import Foundation // Import Foundation for Timer
import AppKit // Import AppKit

class VolumeMonitor: ObservableObject {
    @Published var volumeLevel: Float = 0.0
    private var audioDeviceID = AudioObjectID(kAudioObjectUnknown)
    private let volumePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMaster
    )
    private var volumeChangeListener: AudioObjectPropertyListenerBlock?

    private var interpolationTimer: Timer? // Timer for manual interpolation
    private var targetVolume: Float = 0.0 // The volume we are animating towards
    internal let interpolationDuration: TimeInterval = 0.08 // Duration for volume decrease interpolation
    private let interpolationSteps = 8 // Steps for volume decrease interpolation
    
    // Parameters for volume increase interpolation
    private let increaseInterpolationDuration: TimeInterval = 0.03 // Shorter duration for increase
    private let increaseInterpolationSteps = 3 // Fewer steps for quicker increase

    init() {
        setupVolumeObservation()
    }

    private func setupVolumeObservation() {
        var defaultOutputDeviceID = AudioObjectID(kAudioObjectUnknown)
        var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )

        // Get the default output device ID
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )

        if status != noErr {
            print("Error getting default output device ID: \(status)")
            return
        }

        self.audioDeviceID = defaultOutputDeviceID

        // Define the listener block
        let listenerBlock: AudioObjectPropertyListenerBlock = { [weak self] (inObjectID: AudioObjectID, inAddresses: UnsafePointer<AudioObjectPropertyAddress>) in
            guard let self = self else { return }
            var volume: Float32 = 0.0
            var dataSize = UInt32(MemoryLayout<Float32>.size)
            var volumeAddr = self.volumePropertyAddress // Create a mutable copy
            
            // Get the updated volume
            let status = AudioObjectGetPropertyData(
                self.audioDeviceID,
                &volumeAddr, // Use the mutable copy
                0,
                nil,
                &dataSize,
                &volume
            )

            if status == noErr {
                // Dispatch to main queue to handle volume update
                DispatchQueue.main.async {
                    self.handleVolumeUpdate(newVolume: volume)
                }
            } else {
                print("Error getting volume property data in listener: \(status)")
            }
        }
        // Assign the block to the retained property
        self.volumeChangeListener = listenerBlock

        // Add the listener
        if var volumeAddr = Optional(self.volumePropertyAddress) { // Use a mutable variable for the address
            let addListenerStatus = AudioObjectAddPropertyListenerBlock(
                self.audioDeviceID,
                &volumeAddr, // Pass the address by reference
                nil, // Use a default dispatch queue for the listener callbacks
                listenerBlock // Pass the listener block
            )

            if addListenerStatus != noErr {
                print("Error adding volume listener: \(addListenerStatus)")
            }
        }
        
        // Get the initial volume
        var initialVolume: Float32 = 0.0
        var initialVolumeSize = UInt32(MemoryLayout<Float32>.size)
        var volumeAddr = self.volumePropertyAddress // Create a mutable copy
        let initialStatus = AudioObjectGetPropertyData(
            self.audioDeviceID,
            &volumeAddr,
            0,
            nil,
            &initialVolumeSize,
            &initialVolume
        )
        
        if initialStatus == noErr {
            self.handleVolumeUpdate(newVolume: initialVolume)
        } else {
             print("Error getting initial volume: \(initialStatus)")
        }
    }
    
    // Custom handler for volume updates to perform interpolation
    private func handleVolumeUpdate(newVolume: Float) {
        // Always invalidate the existing timer on a new update
        self.interpolationTimer?.invalidate()
        self.interpolationTimer = nil

        // Only start interpolation if the change is significant
        if abs(newVolume - self.volumeLevel) > 0.001 {
            self.targetVolume = newVolume
            
            let timeInterval: TimeInterval
            let volumeDifference = newVolume - self.volumeLevel
            let volumeStep: Float
            let totalSteps: Int

            if newVolume > self.volumeLevel {
                // Volume is increasing, use faster interpolation parameters
                timeInterval = increaseInterpolationDuration / Double(increaseInterpolationSteps)
                volumeStep = volumeDifference / Float(increaseInterpolationSteps)
                totalSteps = increaseInterpolationSteps
            } else {
                // Volume is decreasing, use regular interpolation parameters
                timeInterval = interpolationDuration / Double(interpolationSteps)
                volumeStep = volumeDifference / Float(interpolationSteps)
                totalSteps = interpolationSteps
            }
            
            // If the difference is very small, just set the value directly to avoid unnecessary timer
            if abs(volumeDifference) < abs(volumeStep) { // Compare absolute difference to absolute step size
                self.volumeLevel = newVolume
                return
            }
            
            // Ensure volumeStep has the correct sign for the direction of change
            let effectiveVolumeStep = (newVolume > self.volumeLevel) ? abs(volumeStep) : -abs(volumeStep)

            self.interpolationTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] timer in
                guard let self = self else { return }

                // Move volume level towards the target volume using the effective step
                let nextVolume = self.volumeLevel + effectiveVolumeStep

                // Check if we have reached or passed the target volume
                if (newVolume > self.volumeLevel && nextVolume >= self.targetVolume) || (newVolume <= self.volumeLevel && nextVolume <= self.targetVolume) {
                    self.volumeLevel = self.targetVolume // Ensure we land exactly on the target
                    timer.invalidate()
                    self.interpolationTimer = nil
                } else {
                     self.volumeLevel = nextVolume
                }
            }
        } else {
             // If change is insignificant or no change, just ensure the timer is stopped and level is set
            self.interpolationTimer?.invalidate()
            self.interpolationTimer = nil
            self.volumeLevel = newVolume
        }
    }

    deinit {
        // Remove the listener when the object is deallocated
        if let listener = volumeChangeListener, audioDeviceID != kAudioObjectUnknown {
            var volumeAddr = self.volumePropertyAddress // Create a mutable copy
             AudioObjectRemovePropertyListenerBlock(
                self.audioDeviceID,
                &volumeAddr,
                nil, // Use the same dispatch queue as when adding (nil defaults to main)
                listener
            )
        }
        // Invalidate the timer on deinit
        interpolationTimer?.invalidate()
    }
}

// Keep the WindowController class but remove the StateObject in ContentView
class WindowController: ObservableObject {
    weak var window: NSWindow? {
        didSet {
            if let window = window {
                // Configure the window
                window.level = .floating // Make the window appear above normal windows
                window.collectionBehavior = [.canJoinAllSpaces, .managed] // Keep it on all spaces and hide from Mission Control/Dock
                window.styleMask = .borderless // Remove window borders and traffic lights
                // We'll center it later when it becomes visible
                window.isOpaque = false // Make it transparent
                window.backgroundColor = .clear // Clear background
                
                // Ensure the window's content view is set if it wasn't already
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
            // Calculate position to place the window at the bottom, slightly above the dock
            let padding: CGFloat = 30 // Adjust padding from the bottom as needed
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.minY + padding
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

struct ContentView: View {
    // VolumeMonitor and WindowController are now provided via the environment
    @EnvironmentObject private var volumeMonitor: VolumeMonitor
    @EnvironmentObject private var windowController: WindowController
    
    // State to control the visibility of the HUD content
    @State private var isHUDVisible = false
    private let hideDelay: Double = 2.0 // Seconds to keep visible after volume change
    @State private var hideTask: DispatchWorkItem? = nil // To keep track of the hide task

    var body: some View {
        // The ZStack contains the HUD content
        ZStack {
            if isHUDVisible {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 250, height: 80) // Made wider
                    .transition(.opacity)
                
                HStack(spacing: 8) {
                    Image(systemName: volumeMonitor.volumeLevel == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    ProgressView(value: volumeMonitor.volumeLevel)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 140)
                }
                .frame(width: 160)
                .transition(.opacity) // Add transition to the HStack as well
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
        .animation(.easeInOut(duration: 0.3), value: isHUDVisible)
        // Use the isHUDVisible state to control the window visibility via the controller
        // Explicitly animate volume decrease
        .onChange(of: volumeMonitor.volumeLevel) { oldVolume, newVolume in
            // Only trigger visibility change if volume actually changes to avoid showing on initial load
            if abs(newVolume - oldVolume) > 0.001 { 
                isHUDVisible = true // Update the state to show the HUD
                
                // Cancel the previous hide task if it exists
                hideTask?.cancel()
                
                // Schedule a new hide task
                let task = DispatchWorkItem { 
                    isHUDVisible = false // Update the state to hide the HUD
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
        // Observe the isHUDVisible state and tell the controller to show/hide the window
        .onChange(of: isHUDVisible) { _, newValue in
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
