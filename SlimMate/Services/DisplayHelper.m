//
//  DisplayHelper.m
//  SlimMate
//

#import "DisplayHelper.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CGEvent.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/graphics/IOGraphicsLib.h>

@implementation DisplayHelper

+ (float)getDisplayBrightness {
    float brightness = 0.0;
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iterator);
    
    if (result == kIOReturnSuccess) {
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &brightness);
            IOObjectRelease(service);
            break;
        }
        IOObjectRelease(iterator);
    }
    
    NSLog(@"Current brightness: %f", brightness);
    return brightness;
}

+ (void)setDisplayBrightness:(float)brightness {
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iterator);
    
    if (result == kIOReturnSuccess) {
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            IODisplaySetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), brightness);
            IOObjectRelease(service);
            break;
        }
        IOObjectRelease(iterator);
    }
    NSLog(@"Set brightness to: %f", brightness);
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