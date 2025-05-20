//
//  DisplayHelper.m
//  SlimMate
//

#import "DisplayHelper.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CGEvent.h>

@implementation DisplayHelper

+ (float)getDisplayBrightness {
    // For now, return a default value since we can't reliably get brightness without private APIs
    return 0.5;
}

+ (void)setDisplayBrightness:(float)brightness {
    // Simulate brightness change using key events instead of direct API calls
    float currentBrightness = [self getDisplayBrightness];
    float targetBrightness = fmax(0.0, fmin(1.0, brightness));
    
    if (targetBrightness > currentBrightness) {
        [self simulateBrightnessUpKey];
    } else if (targetBrightness < currentBrightness) {
        [self simulateBrightnessDownKey];
    }
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

+ (void)simulateBrightnessUpKey {
    [self simulateBrightnessKey:0x30]; // NX_KEYTYPE_BRIGHTNESS_UP
    NSLog(@"Simulated Brightness Up key");
}

+ (void)simulateBrightnessDownKey {
    [self simulateBrightnessKey:0x2E]; // NX_KEYTYPE_BRIGHTNESS_DOWN
    NSLog(@"Simulated Brightness Down key");
}

@end