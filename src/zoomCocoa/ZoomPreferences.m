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

NSString* ZoomPreferencesHaveChangedNotification = @"ZoomPreferencesHaveChangedNotification";

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

+ (void)initialize {
    NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];
	ZoomPreferences* defaultPrefs = [[[[self class] alloc] initWithDefaultPreferences] autorelease];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject: [defaultPrefs dictionary]
															forKey: @"ZoomGlobalPreferences"];
	
    [defaults registerDefaults: appDefaults];
}

+ (ZoomPreferences*) globalPreferences {
	if (globalPreferences == nil) {
		NSDictionary* globalDict = [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomGlobalPreferences"];
		
		if (globalDict== nil) 
			globalPreferences = [[ZoomPreferences alloc] initWithDefaultPreferences];
		else
			globalPreferences = [[ZoomPreferences alloc] initWithDictionary: globalDict];
		
		// Must contain valid fonts and colours
		if ([globalPreferences fonts] == nil || [globalPreferences colours] == nil) {
			NSLog(@"Missing element in global preferences: replacing");
			[globalPreferences release];
			globalPreferences = [[ZoomPreferences alloc] initWithDefaultPreferences];
		}
	}
	
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

static NSArray* DefaultFonts(void) {
	NSString* defaultFontName = @"Gill Sans";
	NSString* fixedFontName = @"Courier";
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	NSMutableArray* defaultFonts = [[NSMutableArray alloc] init];
	
	NSFont* variableFont = [NSFont fontWithName: defaultFontName
										   size: 12];
	NSFont* fixedFont = [NSFont fontWithName: fixedFontName
										size: 12];
	
	if (variableFont == nil) variableFont = [NSFont systemFontOfSize: 12];
	if (fixedFont == nil) fixedFont = [NSFont userFixedPitchFontOfSize: 12];
	
	int x;
	for (x=0; x<16; x++) {
		NSFont* thisFont = variableFont;
		if ((x&4)) thisFont = fixedFont;
		
		if ((x&1)) thisFont = [mgr convertFont: thisFont
								   toHaveTrait: NSBoldFontMask];
		if ((x&2)) thisFont = [mgr convertFont: thisFont
								   toHaveTrait: NSItalicFontMask];
		if ((x&4)) thisFont = [mgr convertFont: thisFont
								   toHaveTrait: NSFixedPitchFontMask];
		
		[defaultFonts addObject: thisFont];
	}
	
	return [defaultFonts autorelease];
}

static NSArray* DefaultColours(void) {
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
	
	return defaultColours;
}

- (id) initWithDefaultPreferences {
	self = [self init];
	
	if (self) {
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
		
		[prefs setObject: DefaultFonts()
				  forKey: fonts];
		[prefs setObject: DefaultColours()
				  forKey: colours];
	}
	
	return self;
}

- (id) initWithDictionary: (NSDictionary*) dict {
	self = [super init];
	
	if (self) {
		prefs = [dict mutableCopy];
		
		// Fonts and colours will be archived if they exist
		NSData* fts = [prefs objectForKey: fonts];
		NSData* cols = [prefs objectForKey: colours];

		if ([fts isKindOfClass: [NSData class]]) {
			[prefs setObject: [NSUnarchiver unarchiveObjectWithData: fts]
					  forKey: fonts];
		}
		
		if ([cols isKindOfClass: [NSData class]]) {
			[prefs setObject: [NSUnarchiver unarchiveObjectWithData: cols]
					  forKey: colours];
		}
		
		// Verify that things are intact
		NSArray* newFonts = [prefs objectForKey: fonts];
		NSArray* newColours = [prefs objectForKey: colours];
		
		if (newFonts && [newFonts count] != 16) {
			NSLog(@"Unable to decode font block: using defaults");
			[prefs setObject: DefaultFonts()
					  forKey: fonts];
		}
		
		if (newColours && [newColours count] != 11) {
			NSLog(@"Unable to decode colour block: using defaults");
			[prefs setObject: DefaultColours()
					  forKey: colours];
		}
	}
	
	return self;
}

- (NSDictionary*) dictionary {
	// Fonts and colours need encoding
	NSMutableDictionary* newDict = [prefs mutableCopy];
	
	NSArray* fts = [newDict objectForKey: fonts];
	NSArray* cols = [newDict objectForKey: colours];
	
	if (fts != nil) {
		[newDict setObject: [NSArchiver archivedDataWithRootObject: fts]
					forKey: fonts];
	}
	
	if (cols != nil) {
		[newDict setObject: [NSArchiver archivedDataWithRootObject: cols]
					forKey: colours];
	}

	
	return [newDict autorelease];
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
	[self preferencesHaveChanged];
}

- (void) setFatalWarnings: (BOOL) flag {
	[prefs setObject: [NSNumber numberWithBool: flag]
			  forKey: fatalWarnings];
	[self preferencesHaveChanged];
}

- (void) setSpeakGameText: (BOOL) flag {
	[prefs setObject: [NSNumber numberWithBool: flag]
			  forKey: speakGameText];
	[self preferencesHaveChanged];
}

- (void) setGameTitle: (NSString*) title {
	[prefs setObject: [[title copy] autorelease]
			  forKey: gameTitle];
	[self preferencesHaveChanged];
}

- (void) setInterpreter: (int) inter {
	[prefs setObject: [NSNumber numberWithInt: inter]
			  forKey: interpreter];
	[self preferencesHaveChanged];
}

- (void) setRevision: (int) rev {
	[prefs setObject: [NSNumber numberWithInt: rev]
			  forKey: revision];
	[self preferencesHaveChanged];
}

- (void) setFonts: (NSArray*) fts {
	[prefs setObject: [NSArray arrayWithArray: fts]
			  forKey: fonts];
	[self preferencesHaveChanged];
}

- (void) setColours: (NSArray*) cols {
	[prefs setObject: [NSArray arrayWithArray: cols]
			  forKey: colours];
	[self preferencesHaveChanged];
}

// = Notifications =
- (void) preferencesHaveChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomPreferencesHaveChangedNotification
														object:self];
	
	if (self == globalPreferences) {
		// Save global preferences
		[[NSUserDefaults standardUserDefaults] setObject:[self dictionary] 
												  forKey:@"ZoomGlobalPreferences"];		
	}
}

// = NSCoding =
- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	
	if (self) {
		prefs = [[coder decodeObject] retain];
	}
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	[coder encodeObject: prefs];
}

@end
