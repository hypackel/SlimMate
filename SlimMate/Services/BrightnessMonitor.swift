import Foundation
import Combine

class BrightnessMonitor: ObservableObject {
    @Published var brightnessLevel: Float = 0.5 // Default brightness

    init() {
        // Get initial brightness from DisplayHelper
        getInitialBrightness()
    }

    // Function to get the current brightness using DisplayHelper
    private func getInitialBrightness() {
        let currentBrightness = DisplayHelper.getDisplayBrightness()
        DispatchQueue.main.async {
            self.brightnessLevel = currentBrightness
        }
    }

    // Function to set the brightness using DisplayHelper
    func setBrightness(level: Float) {
        let clampedLevel = max(0.0, min(1.0, level)) // Clamp level between 0.0 and 1.0
        print("Setting brightness to: \(clampedLevel)")
        
        DisplayHelper.setDisplayBrightness(clampedLevel)
        
        // Update the published property
        DispatchQueue.main.async {
            self.brightnessLevel = clampedLevel
        }
    }

    // Basic functions to increase and decrease brightness
    func increaseBrightness() {
        DisplayHelper.simulateBrightnessUpKey()
        // Update brightness level after a short delay to allow the system to process the key event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newBrightness = DisplayHelper.getDisplayBrightness()
            self.brightnessLevel = newBrightness
        }
    }

    func decreaseBrightness() {
        DisplayHelper.simulateBrightnessDownKey()
        // Update brightness level after a short delay to allow the system to process the key event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newBrightness = DisplayHelper.getDisplayBrightness()
            self.brightnessLevel = newBrightness
        }
    }
} 