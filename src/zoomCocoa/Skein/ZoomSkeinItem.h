//
//  ZoomSkeinItem.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ZoomSkeinItem : NSObject {
	ZoomSkeinItem* parent;
	NSMutableSet* children;
	
	NSString*     command;
	NSString*     result;
	
	BOOL temporary;
	int  tempScore;
	
	BOOL played, changed;
	
	NSString* annotation;
}

// Initialisation
+ (ZoomSkeinItem*) skeinItemWithCommand: (NSString*) command;

- (id) initWithCommand: (NSString*) command;

// Data accessors

// Skein tree
- (ZoomSkeinItem*) parent;
- (NSSet*)         children;
- (ZoomSkeinItem*) childWithCommand: (NSString*) command;

- (ZoomSkeinItem*) addChild: (ZoomSkeinItem*) childItem;
- (void)		   removeChild: (ZoomSkeinItem*) childItem;
- (void)		   removeFromParent;

// Item data
- (NSString*)      command; // Command input
- (NSString*)      result;  // Command result

- (void) setCommand: (NSString*) command;
- (void) setResult:  (NSString*) result;

// Item state
- (BOOL) temporary;			// Whether or not this item has been made permanent by saving
- (int)  temporaryScore;	// Lower values are more likely to be removed
- (BOOL) played;			// Whether or not this item has actually been played
- (BOOL) changed;			// Whether or not this item's result has changed since this was last played
							// (Automagically updated by setResult:)

- (void) setTemporary: (BOOL) isTemporary;
- (void) setTemporaryScore: (int) score;
- (void) increaseTemporaryScore;
- (void) setPlayed: (BOOL) played;
- (void) setChanged: (BOOL) changed;

// Annotation

// Allows the player to designate certain areas of the skein as having specific annotations and colours
// (So, for example an area can be called 'solution to the maximum mouse melee puzzle')
// Each 'annotation' colours a new area of the skein. Maybe the UI could allow annotations to 
- (NSString*) annotation;
- (void)      setAnnotation: (NSString*) newAnnotation;

@end
