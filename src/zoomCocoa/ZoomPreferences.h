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

// Getting preferences
- (BOOL) displayWarnings;
- (BOOL) fatalWarnings;
- (BOOL) speakGameText;

- (NSString*)     gameTitle;
- (int)           interpreter;
- (unsigned char) revision;

- (NSArray*)      fonts;   // 16 fonts
- (NSArray*)      colours; // 13 colours

// Setting preferences
- (void) setDisplayWarnings: (BOOL) flag;
- (void) setFatalWarnings: (BOOL) flag;
- (void) setSpeakGameText: (BOOL) flag;

- (void) setGameTitle: (NSString*) title;
- (void) setInterpreter: (int) interpreter;
- (void) setRevision: (int) revision;

- (void) setFonts: (NSArray*) fonts;
- (void) setColours: (NSArray*) colours;

@end
