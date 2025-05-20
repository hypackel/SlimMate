//
//  MediaKeyObserver.swift
//  SlimMate
//
//  Created by Gemini on going to add media key observation.
//

import Cocoa
import MediaKeyTap
import Combine
import IOKit.hidsystem

class MediaKeyObserver: NSObject, MediaKeyTapDelegate {
    private var mediaKeyTap: MediaKeyTap?
    private let volumeMonitor: VolumeMonitor
    private let brightnessMonitor: BrightnessMonitor
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any? // Global event monitor

    // Constants for brightness keys
    private let NX_KEYTYPE_BRIGHTNESS_UP = Int(0x30)
    private let NX_KEYTYPE_BRIGHTNESS_DOWN = Int(0x2E)
    private let NX_KEYSTATE_DOWN = Int(0x0A)

    init(volumeMonitor: VolumeMonitor, brightnessMonitor: BrightnessMonitor) {
        self.volumeMonitor = volumeMonitor
        self.brightnessMonitor = brightnessMonitor
        super.init()
        
        // Initialize and start MediaKeyTap for media keys
        self.mediaKeyTap = MediaKeyTap(delegate: self, on: .keyDown)
        self.mediaKeyTap?.start()
        
        // Set up global event monitor for brightness keys
        setupGlobalEventMonitor()
        
        print("MediaKeyObserver started.")
    }

    deinit {
        // Stop MediaKeyTap and remove event monitor
        self.mediaKeyTap?.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        cancellables.removeAll()
        print("MediaKeyObserver stopped.")
    }

    private func setupGlobalEventMonitor() {
        // Monitor for system-defined events (includes brightness keys)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self = self else { return }
            
            // Check if it's a brightness key event
            if event.type == .systemDefined {
                let data1 = event.data1
                
                // Extract key code and key state
                let keyCode = Int((data1 & 0xFFFF0000) >> 16)
                let keyState = Int((data1 & 0x0000FF00) >> 8)
                let keyRepeat = (data1 & 0x1) == 1
                
                // Handle brightness keys
                switch keyCode {
                case self.NX_KEYTYPE_BRIGHTNESS_UP:
                    if keyState == self.NX_KEYSTATE_DOWN && !keyRepeat {
                        print("Brightness Up key pressed")
                        self.brightnessMonitor.increaseBrightness()
                    }
                case self.NX_KEYTYPE_BRIGHTNESS_DOWN:
                    if keyState == self.NX_KEYSTATE_DOWN && !keyRepeat {
                        print("Brightness Down key pressed")
                        self.brightnessMonitor.decreaseBrightness()
                    }
                default:
                    break
                }
            }
        }
    }

    // MARK: - MediaKeyTapDelegate
    func handle(mediaKey: MediaKey, event: KeyEvent) {
        // Handle media playback keys
        switch mediaKey {
        case .playPause:
            print("Play/Pause key pressed")
        case .next:
            print("Next track key pressed")
        case .previous:
            print("Previous track key pressed")
        case .rewind:
            print("Rewind key pressed")
        case .fastForward:
            print("Fast Forward key pressed")
        }
    }
}
