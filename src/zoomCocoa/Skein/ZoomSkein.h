//
//  ZoomSkein.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZoomSkeinItem.h"

extern NSString* ZoomSkeinChangedNotification;

@interface ZoomSkein : NSObject {
	ZoomSkeinItem* rootItem;
	
	NSMutableString* currentOutput;
	ZoomSkeinItem* activeItem;
}

// Retrieving the root skein item
- (ZoomSkeinItem*) rootItem;
- (ZoomSkeinItem*) activeItem;

// Acting as a Zoom output receiver
- (void) inputCommand:   (NSString*) command;
- (void) inputCharacter: (NSString*) character;
- (void) outputText:     (NSString*) outputText;
- (void) zoomWaitingForInput;
- (void) zoomInterpreterRestart;

// Notifying of changed
- (void) zoomSkeinChanged;

@end
