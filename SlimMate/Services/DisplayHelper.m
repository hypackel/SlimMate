//
//  DisplayHelper.m
//  SlimMate
//

#import "DisplayHelper.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CGEvent.h>
#import <CoreGraphics/CGDirectDisplay.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <IOKit/graphics/IOGraphicsTypes.h>
#import <IOKit/graphics/IOGraphicsInterface.h>
#import <IOKit/i2c/IOI2CInterface.h>

// CoreDisplay private API declarations
void CoreDisplay_Display_SetUserBrightness(int display, double brightness);
double CoreDisplay_Display_GetUserBrightness(int display);
int CoreDisplay_Display_GetMainDisplayID(void);

@implementation DisplayHelper

+ (void)initialize {
    if (self == [DisplayHelper class]) {
        // Log all available displays on startup
        [self logAvailableDisplays];
    }
}

+ (void)logAvailableDisplays {
    // First try built-in display
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault,
        IOServiceMatching("AppleBacklightDisplay"), &iterator);
    
    if (result == kIOReturnSuccess) {
        NSLog(@"Found AppleBacklightDisplay devices:");
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            io_name_t name;
            IORegistryEntryGetName(service, name);
            NSLog(@"Display name: %s", name);
            
            // Try to get properties
            CFMutableDictionaryRef properties;
            if (IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, kNilOptions) == KERN_SUCCESS) {
                NSLog(@"Display properties: %@", (__bridge NSDictionary *)properties);
                CFRelease(properties);
            }
            
            // Try to get brightness directly
            float brightness;
            result = IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &brightness);
            if (result == kIOReturnSuccess) {
                NSLog(@"Current brightness: %f", brightness);
            } else {
                NSLog(@"Failed to get brightness: %d", result);
            }
            
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    // Then try external displays
    result = IOServiceGetMatchingServices(kIOMasterPortDefault,
        IOServiceMatching("IODisplayConnect"), &iterator);
    
    if (result == kIOReturnSuccess) {
        NSLog(@"Found IODisplayConnect devices:");
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            io_name_t name;
            IORegistryEntryGetName(service, name);
            NSLog(@"Display name: %s", name);
            
            // Try to get properties
            CFMutableDictionaryRef properties;
            if (IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, kNilOptions) == KERN_SUCCESS) {
                NSLog(@"Display properties: %@", (__bridge NSDictionary *)properties);
                CFRelease(properties);
            }
            
            // Try to get brightness directly
            float brightness;
            result = IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &brightness);
            if (result == kIOReturnSuccess) {
                NSLog(@"Current brightness: %f", brightness);
            } else {
                NSLog(@"Failed to get brightness: %d", result);
            }
            
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    // Also try to get displays through CoreGraphics
    NSLog(@"Found CoreGraphics displays:");
    CGDirectDisplayID displays[8];
    uint32_t displayCount;
    CGGetActiveDisplayList(8, displays, &displayCount);
    
    for (uint32_t i = 0; i < displayCount; i++) {
        CGDirectDisplayID display = displays[i];
        NSLog(@"Display ID: %u", display);
        NSLog(@"Is built-in: %@", CGDisplayIsBuiltin(display) ? @"Yes" : @"No");
        NSLog(@"Width: %zu, Height: %zu", 
            CGDisplayPixelsWide(display),
            CGDisplayPixelsHigh(display));
    }
}

+ (float)getDisplayBrightness {
    float brightness = 0.0;
    
    // Get all active displays
    CGDirectDisplayID displays[8];
    uint32_t displayCount;
    CGGetActiveDisplayList(8, displays, &displayCount);
    
    for (uint32_t i = 0; i < displayCount; i++) {
        CGDirectDisplayID display = displays[i];
        
        // Try to get the IOService for this display
        io_service_t service = CGDisplayIOServicePort(display);
        if (service != IO_OBJECT_NULL) {
            float currentBrightness;
            kern_return_t result = IODisplayGetFloatParameter(service, kNilOptions, 
                CFSTR(kIODisplayBrightnessKey), &currentBrightness);
            
            if (result == kIOReturnSuccess) {
                NSLog(@"Got brightness for display %u: %f", display, currentBrightness);
                brightness = currentBrightness;
                break;  // Use the first display that works
            } else {
                NSLog(@"Failed to get brightness for display %u: %d", display, result);
            }
            
            IOObjectRelease(service);
        }
    }
    
    // If no display worked, try the old method as fallback
    if (brightness == 0.0) {
        io_iterator_t iterator;
        kern_return_t result;
        
        // First try built-in display
        result = IOServiceGetMatchingServices(kIOMasterPortDefault,
            IOServiceMatching("AppleBacklightDisplay"), &iterator);
        
        if (result == kIOReturnSuccess) {
            io_object_t service;
            while ((service = IOIteratorNext(iterator))) {
                float currentBrightness;
                result = IODisplayGetFloatParameter(service, kNilOptions, 
                    CFSTR(kIODisplayBrightnessKey), &currentBrightness);
                
                if (result == kIOReturnSuccess) {
                    NSLog(@"Got brightness from AppleBacklightDisplay: %f", currentBrightness);
                    brightness = currentBrightness;
                    IOObjectRelease(service);
                    break;
                } else {
                    NSLog(@"Failed to get brightness parameter: %d", result);
                }
                IOObjectRelease(service);
            }
            IOObjectRelease(iterator);
        }
        
        // If still no brightness, try external displays
        if (brightness == 0.0) {
            result = IOServiceGetMatchingServices(kIOMasterPortDefault,
                IOServiceMatching("IODisplayConnect"), &iterator);
            
            if (result == kIOReturnSuccess) {
                io_object_t service;
                while ((service = IOIteratorNext(iterator))) {
                    float currentBrightness;
                    result = IODisplayGetFloatParameter(service, kNilOptions, 
                        CFSTR(kIODisplayBrightnessKey), &currentBrightness);
                    
                    if (result == kIOReturnSuccess) {
                        NSLog(@"Got brightness from IODisplayConnect: %f", currentBrightness);
                        brightness = currentBrightness;
                        IOObjectRelease(service);
                        break;
                    } else {
                        NSLog(@"Failed to get brightness parameter: %d", result);
                    }
                    IOObjectRelease(service);
                }
                IOObjectRelease(iterator);
            }
        }
    }
    
    return brightness;
}

+ (void)setDisplayBrightness:(float)brightness {
    io_iterator_t iterator;
    kern_return_t result;
    
    // First try built-in display
    result = IOServiceGetMatchingServices(kIOMasterPortDefault,
        IOServiceMatching("AppleBacklightDisplay"), &iterator);
    
    if (result == kIOReturnSuccess) {
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            result = IODisplaySetFloatParameter(service, kNilOptions, 
                CFSTR(kIODisplayBrightnessKey), brightness);
            if (result == kIOReturnSuccess) {
                NSLog(@"Set brightness on AppleBacklightDisplay: %f", brightness);
            } else {
                NSLog(@"Failed to set brightness parameter: %d", result);
            }
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    // Also try external displays
    result = IOServiceGetMatchingServices(kIOMasterPortDefault,
        IOServiceMatching("IODisplayConnect"), &iterator);
    
    if (result == kIOReturnSuccess) {
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            result = IODisplaySetFloatParameter(service, kNilOptions, 
                CFSTR(kIODisplayBrightnessKey), brightness);
            if (result == kIOReturnSuccess) {
                NSLog(@"Set brightness on IODisplayConnect: %f", brightness);
            } else {
                NSLog(@"Failed to set brightness parameter: %d", result);
            }
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
}

+ (void)simulateBrightnessUpKey {
    [self simulateBrightnessKey:0x30]; // NX_KEYTYPE_BRIGHTNESS_UP
    NSLog(@"Simulated Brightness Up key");
}

+ (void)simulateBrightnessDownKey {
    [self simulateBrightnessKey:0x2E]; // NX_KEYTYPE_BRIGHTNESS_DOWN
    NSLog(@"Simulated Brightness Down key");
}

+ (void)simulateBrightnessKey:(int)key {
    void (^doKey)(BOOL) = ^(BOOL down) {
        NSEventModifierFlags flags = (down ? NSEventModifierFlagDeviceIndependentFlagsMask : 0);
        NSInteger data1 = (key << 16) | (down ? 0xa00 : 0xb00);

        NSEvent *ev = [NSEvent otherEventWithType:NSEventTypeSystemDefined
                                       location:NSZeroPoint
                                  modifierFlags:flags
                                      timestamp:0
                                   windowNumber:0
                                        context:nil
                                        subtype:8
                                          data1:data1
                                          data2:-1];

        CGEventRef cev = ev.CGEvent;
        if (cev) {
            CGEventPost(kCGHIDEventTap, cev);
            CFRelease(cev);
        }
    };

    doKey(YES);
    doKey(NO);
}

@end