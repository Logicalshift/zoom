//
//  ZoomPreferences.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Dec 21 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomPreferences.h"


@implementation ZoomPreferences

// == Preference keys ==

static NSString* displayWarnings = @"DisplayWarnings";
static NSString* fatalWarnings   = @"FatalWarnings";
static NSString* speakGameText   = @"SpeakGameText";

static NSString* gameTitle       = @"GameTitle";
static NSString* interpreter     = @"Interpreter";
static NSString* revision        = @"Revision";

static NSString* fonts           = @"Fonts";
static NSString* colours		 = @"Colours";

// == Global preferences ==

static ZoomPreferences* globalPreferences = nil;

+ (ZoomPreferences*) globalPreferences {
	if (globalPreferences == nil) globalPreferences = [[ZoomPreferences alloc] initWithDefaultPreferences];
	
	return globalPreferences;
}

// == Initialisation ==

- (id) init {
	self = [super init];
	
	if (self) {
		prefs = [[NSMutableDictionary allocWithZone: [self zone]] init];		
	}
	
	return self;
}

- (id) initWithDefaultPreferences {
	self = [self init];
	
	if (self) {
		NSString* defaultFont = @"Gill Sans";
		NSString* fixedFont = @"Courier";
		NSFontManager* mgr = [NSFontManager sharedFontManager];
		
		NSMutableArray* defaultFonts = [[NSMutableArray alloc] init];
		
		int x;
		for (x=0; x<16; x++) {
			NSFont* thisFont = [NSFont fontWithName: defaultFont
											   size: 12];
			NSFontTraitMask mask = 0;
			if ((x&4)) thisFont = [NSFont fontWithName: fixedFont
												  size: 12];
			
			if ((x&1)) mask|=NSBoldFontMask;
			if ((x&2)) mask|=NSItalicFontMask;
			if ((x&4)) mask|=NSFixedPitchFontMask;
			
			if (mask != 0)
				thisFont = [mgr convertFont: thisFont
								toHaveTrait: mask];
			
			[defaultFonts addObject: thisFont];
		}
		
		NSMutableArray* defaultColours = [[NSArray arrayWithObjects:
			[NSColor colorWithDeviceRed: 0 green: 0 blue: 0 alpha: 1],
			[NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1],
			[NSColor colorWithDeviceRed: 0 green: 1 blue: 0 alpha: 1],
			[NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha: 1],
			[NSColor colorWithDeviceRed: 0 green: 0 blue: 1 alpha: 1],
			[NSColor colorWithDeviceRed: 1 green: 0 blue: 1 alpha: 1],
			[NSColor colorWithDeviceRed: 0 green: 1 blue: 1 alpha: 1],
			[NSColor colorWithDeviceRed: 1 green: 1 blue: .8 alpha: 1],
			
			[NSColor colorWithDeviceRed: .73 green: .73 blue: .73 alpha: 1],
			[NSColor colorWithDeviceRed: .53 green: .53 blue: .53 alpha: 1],
			[NSColor colorWithDeviceRed: .26 green: .26 blue: .26 alpha: 1],
			nil] retain];		
		
		// Defaults
		[prefs setObject: [NSNumber numberWithBool: NO]
				  forKey: displayWarnings];
		[prefs setObject: [NSNumber numberWithBool: NO]
				  forKey: fatalWarnings];
		[prefs setObject: [NSNumber numberWithBool: NO]
				  forKey: speakGameText];
		
		[prefs setObject: @"%s (%i.%.6s.%04x)"
				  forKey: gameTitle];
		[prefs setObject: [NSNumber numberWithInt: 3]
				  forKey: interpreter];
		[prefs setObject: [NSNumber numberWithInt: 'Z']
				  forKey: revision];
		
		[prefs setObject: [defaultFonts autorelease]
				  forKey: fonts];
		[prefs setObject: [defaultColours autorelease]
				  forKey: colours];
	}
	
	return self;
}

- (void) dealloc {
	[prefs release];
	
	[super dealloc];
}

// Getting preferences
- (BOOL) displayWarnings {
	return [[prefs objectForKey: displayWarnings] boolValue];
}

- (BOOL) fatalWarnings {
	return [[prefs objectForKey: fatalWarnings] boolValue];
}

- (BOOL) speakGameText {
	return [[prefs objectForKey: speakGameText] boolValue];
}

- (NSString*) gameTitle {
	return [prefs objectForKey: gameTitle];
}

- (int) interpreter {
	return [[prefs objectForKey: interpreter] intValue];
}

- (unsigned char) revision {
	return [[prefs objectForKey: revision] intValue];
}

- (NSArray*) fonts {
	return [prefs objectForKey: fonts];
}

- (NSArray*) colours {
	return [prefs objectForKey: colours];
}

// Setting preferences
- (void) setDisplayWarnings: (BOOL) flag {
	[prefs setObject: [NSNumber numberWithBool: flag]
			  forKey: displayWarnings];
}

- (void) setFatalWarnings: (BOOL) flag {
	[prefs setObject: [NSNumber numberWithBool: flag]
			  forKey: fatalWarnings];
}

- (void) setSpeakGameText: (BOOL) flag {
	[prefs setObject: [NSNumber numberWithBool: flag]
			  forKey: speakGameText];
}

- (void) setGameTitle: (NSString*) title {
	[prefs setObject: [[title copy] autorelease]
			  forKey: gameTitle];
}

- (void) setInterpreter: (int) inter {
	[prefs setObject: [NSNumber numberWithInt: inter]
			  forKey: interpreter];
}

- (void) setRevision: (int) rev {
	[prefs setObject: [NSNumber numberWithInt: rev]
			  forKey: revision];
}

- (void) setFonts: (NSArray*) fts {
	[prefs setObject: [NSArray arrayWithArray: fts]
			  forKey: fonts];
}

- (void) setColours: (NSArray*) cols {
	[prefs setObject: [NSArray arrayWithArray: cols]
			  forKey: colours];
}

@end
