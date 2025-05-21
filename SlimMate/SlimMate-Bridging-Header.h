//
//  SlimMate-Bridging-Header.h
//  SlimMate
//

#import <IOKit/IOKitLib.h>
#import <Foundation/Foundation.h>
#import "DisplayHelper.h"

#ifndef SlimMate_Bridging_Header_h
#define SlimMate_Bridging_Header_h

// Import DisplayHelper which now includes CoreDisplay declarations
#import "DisplayHelper.h"

// CoreDisplay framework path
#if __has_include(<CoreDisplay/CoreDisplay.h>)
#import <CoreDisplay/CoreDisplay.h>
#endif

#endif /* SlimMate_Bridging_Header_h */

