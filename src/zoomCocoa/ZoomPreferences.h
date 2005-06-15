//
//  ZoomPreferences.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Dec 21 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

extern NSString* ZoomPreferencesHaveChangedNotification;

@interface ZoomPreferences : NSObject<NSCoding> {
	NSMutableDictionary* prefs;
	NSLock* prefLock;
}

// init is the designated initialiser for this class

+ (ZoomPreferences*) globalPreferences;
- (id) initWithDefaultPreferences;

- (id) initWithDictionary: (NSDictionary*) preferences;

// Getting preferences
+ (NSString*) defaultOrganiserDirectory;

- (BOOL)  displayWarnings;
- (BOOL)  fatalWarnings;
- (BOOL)  speakGameText;
- (BOOL)  confirmGameClose;
- (float) scrollbackLength;	// 0-100

- (NSString*)     gameTitle;
- (int)           interpreter;
- (unsigned char) revision;

- (NSArray*)      fonts;   // 16 fonts
- (NSArray*)      colours; // 13 colours

- (NSString*) proportionalFontFamily;
- (NSString*) fixedFontFamily;
- (NSString*) symbolicFontFamily;
- (float) fontSize;

- (NSDictionary*) dictionary;

- (NSString*) organiserDirectory;
- (BOOL)	  keepGamesOrganised;
- (BOOL)      autosaveGames;

// Setting preferences
- (void) setDisplayWarnings: (BOOL) flag;
- (void) setFatalWarnings: (BOOL) flag;
- (void) setSpeakGameText: (BOOL) flag;
- (void) setConfirmGameClose: (BOOL) flag;
- (void) setScrollbackLength: (float) value;

- (void) setGameTitle: (NSString*) title;
- (void) setInterpreter: (int) interpreter;
- (void) setRevision: (int) revision;

- (void) setFonts: (NSArray*) fonts;
- (void) setColours: (NSArray*) colours;

- (void) setProportionalFontFamily: (NSString*) fontFamily;
- (void) setFixedFontFamily: (NSString*) fontFamily;
- (void) setSymbolicFontFamily: (NSString*) fontFamily;
- (void) setFontSize: (float) size;

- (void) setOrganiserDirectory: (NSString*) directory;
- (void) setKeepGamesOrganised: (BOOL) value;
- (void) setAutosaveGames: (BOOL) value;

// Notifications
- (void) preferencesHaveChanged;

@end
