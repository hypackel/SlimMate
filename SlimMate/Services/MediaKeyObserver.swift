//
//  MediaKeyObserver.swift
//  SlimMate
//
//  Created by Gemini on going to add media key observation.
//

import Cocoa
import MediaKeyTap
import Combine

class MediaKeyObserver: NSObject, MediaKeyTapDelegate {
    private var mediaKeyTap: MediaKeyTap?
    private let volumeMonitor: VolumeMonitor
    private let brightnessMonitor: BrightnessMonitor
    private var cancellables = Set<AnyCancellable>()

    init(volumeMonitor: VolumeMonitor, brightnessMonitor: BrightnessMonitor) {
        self.volumeMonitor = volumeMonitor
        self.brightnessMonitor = brightnessMonitor
        super.init()
        // Initialize and start MediaKeyTap based on SlimHUD's usage.
        // SlimHUD initializes with delegate and 'on' parameter.
        // We will only listen for media keys supported by this version of MediaKeyTap (playback keys).
        self.mediaKeyTap = MediaKeyTap(delegate: self, on: .keyDown) // Listen for key down events
        self.mediaKeyTap?.start()
        print("MediaKeyObserver started.")
    }

    deinit {
        // Stop MediaKeyTap when the observer is deallocated
        self.mediaKeyTap?.stop()
        cancellables.removeAll()
        print("MediaKeyObserver stopped.")
    }

    // MARK: - MediaKeyTapDelegate

    // Implement the handle method required by MediaKeyTapDelegate (v2.3.0 API).
    // This version of the library only handles media playback keys within this delegate method.
    func handle(mediaKey: MediaKey, event: KeyEvent) {
        // This method is called when a supported media key event is intercepted.
        // We will handle media playback keys here if needed in the future.

        // Example: Print intercepted key for debugging
        print("Intercepted media key: \(mediaKey)")

        // The MediaKey enum in v2.3.0 does not include volume or brightness keys.
        // These keys will need to be handled via a different event monitoring mechanism.
        switch mediaKey {
        case .playPause:
             print("Play/Pause key pressed")
            // TODO: Add logic for play/pause if needed
        case .next:
             print("Next track key pressed")
            // TODO: Add logic for next track if needed
        case .previous:
             print("Previous track key pressed")
            // TODO: Add logic for previous track if needed
        case .rewind:
             print("Rewind key pressed")
             // TODO: Add logic for rewind if needed
        case .fastForward:
             print("Fast Forward key pressed")
             // TODO: Add logic for fast forward if needed
        }
    }
    
    // We will need a separate mechanism to capture and handle volume and brightness keys
    // using lower-level system event monitoring, similar to SlimHUD's approach.
    // This is not handled by the MediaKeyTapDelegate protocol in this version.
}
