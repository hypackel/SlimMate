import SwiftUI
import CoreAudio // Import CoreAudio framework
import Foundation // Import Foundation for Timer

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
    private let interpolationDuration: TimeInterval = 0.1 // Slightly reduced duration for quicker response
    private let interpolationSteps = 10 // Slightly reduced steps

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
            
            let timeInterval = interpolationDuration / Double(interpolationSteps)
            let volumeDifference = newVolume - self.volumeLevel
            let volumeStep = volumeDifference / Float(interpolationSteps)
            
            // If the difference is very small, just set the value directly to avoid unnecessary timer
            if abs(volumeDifference) < volumeStep { // Compare absolute difference to step size
                 self.volumeLevel = newVolume
                 return
            }

            self.interpolationTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                
                // Move volume level towards the target volume
                let nextVolume = self.volumeLevel + volumeStep
                
                // Check if we have reached or passed the target volume using the sign of the step
                if (volumeStep > 0 && nextVolume >= self.targetVolume) || (volumeStep < 0 && nextVolume <= self.targetVolume) {
                    self.volumeLevel = self.targetVolume // Ensure we land exactly on the target
                    timer.invalidate()
                    self.interpolationTimer = nil
                } else {
                     self.volumeLevel = nextVolume
                }
            }
        } else {
             // If change is insignificant or no change, just ensure the timer is stopped
            self.interpolationTimer?.invalidate()
            self.interpolationTimer = nil
            // Also, ensure the volume level is exactly the target if very close
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

struct ContentView: View {
    @StateObject private var volumeMonitor = VolumeMonitor()
    @State private var isVisible = false
    private let hideDelay: Double = 2.0 // Seconds to keep visible after volume change
    @State private var hideTask: DispatchWorkItem? = nil // To keep track of the hide task

    var body: some View {
        ZStack {
            if isVisible {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 250, height: 80) // Made wider
                    .transition(.opacity)
                
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    ProgressView(value: volumeMonitor.volumeLevel)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 140)
                        .animation(.easeInOut(duration: 0.2), value: volumeMonitor.volumeLevel)
                }
                .frame(width: 160)
                .transition(.opacity) // Add transition to the HStack as well
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onChange(of: volumeMonitor.volumeLevel) { oldVolume, newVolume in
            // Only trigger visibility change if volume actually changes to avoid showing on initial load
            if abs(newVolume - oldVolume) > 0.001 { 
                isVisible = true
                
                // Cancel the previous hide task if it exists
                hideTask?.cancel()
                
                // Schedule a new hide task
                let task = DispatchWorkItem { 
                    isVisible = false
                }
                hideTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: task)
            }
        }
    }
}
