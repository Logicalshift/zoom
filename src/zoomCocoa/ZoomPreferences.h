//
//  ZoomPreferences.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Dec 21 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface ZoomPreferences : NSObject {
	NSMutableDictionary* prefs;
}

// init is the designated initialiser for this class

+ (ZoomPreferences*) globalPreferences;
- (id) initWithDefaultPreferences;

@end
