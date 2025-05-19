import SwiftUI
import CoreAudio // Import CoreAudio framework
import Foundation // Import Foundation for Timer

class VolumeMonitor: ObservableObject {
    @Published var volumeLevel: Float = 0.0
    private var audioDeviceID = AudioObjectID(kAudioObjectUnknown)
    private let volumePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
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