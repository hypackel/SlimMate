//
//  DisplayHelper.h
//  SlimMate
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DisplayHelper : NSObject

+ (float)getDisplayBrightness;
+ (void)setDisplayBrightness:(float)brightness;
+ (void)simulateBrightnessUpKey;
+ (void)simulateBrightnessDownKey;

@end

NS_ASSUME_NONNULL_END