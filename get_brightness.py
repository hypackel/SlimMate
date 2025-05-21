#!/usr/bin/env python3
import time
from Quartz import *

def get_display_brightness():
    # Get all active displays
    main = CGMainDisplayID()
    
    # Get the brightness
    brightness = CGDisplayGetBrightness(main)
    return brightness

while True:
    brightness = get_display_brightness()
    print(f"Current brightness: {brightness:.2f}")
    time.sleep(2)  # Check every 2 seconds 