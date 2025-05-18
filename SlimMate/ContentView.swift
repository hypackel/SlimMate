import SwiftUI
import CoreAudio // Import CoreAudio framework

class VolumeMonitor: ObservableObject {
    @Published var volumeLevel: Float = 0.0
    private var audioDeviceID = AudioObjectID(kAudioObjectUnknown)
    private let volumePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMaster
    )
    private var volumeChangeListener: AudioObjectPropertyListenerBlock?

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
                &volumeAddr,
                0,
                nil,
                &dataSize,
                &volume
            )

            if status == noErr {
                DispatchQueue.main.async {
                    self.volumeLevel = volume
                }
            } else {
                print("Error getting volume property data: \(status)")
            }
        }
        self.volumeChangeListener = listenerBlock as AudioObjectPropertyListenerBlock

        // Add the listener
        if let listener = volumeChangeListener {
            var volumeAddr = self.volumePropertyAddress // Create a mutable copy
            let addListenerStatus = AudioObjectAddPropertyListenerBlock(
                self.audioDeviceID,
                &volumeAddr,
                nil, // Use a default dispatch queue
                listener
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
            self.volumeLevel = initialVolume
        } else {
             print("Error getting initial volume: \(initialStatus)")
        }
    }

    deinit {
        // Remove the listener when the object is deallocated
        if let listener = volumeChangeListener, audioDeviceID != kAudioObjectUnknown {
            var volumeAddr = self.volumePropertyAddress // Create a mutable copy
             AudioObjectRemovePropertyListenerBlock(
                self.audioDeviceID,
                &volumeAddr,
                nil, // Use the same dispatch queue as when adding
                listener
            )
        }
    }
}

struct ContentView: View {
    @StateObject private var volumeMonitor = VolumeMonitor()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
                .frame(width: 180, height: 80)
            
            VStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                ProgressView(value: volumeMonitor.volumeLevel)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 140)
            }
        }
        .onAppear {
            // Simulate volume change animation (replace later with real hook)
            // Removed simulated animation as volume is now controlled by system
        }
    }
}
