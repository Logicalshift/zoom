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
static NSString* keepGamesOrganised = @"KeepGamesOrganised";
static NSString* autosaveGames = @"autosaveGames";

static NSString* gameTitle       = @"GameTitle";
static NSString* interpreter     = @"Interpreter";
static NSString* revision        = @"Revision";

static NSString* fonts           = @"Fonts";
static NSString* colours		 = @"Colours";

static NSString* organiserDirectory = @"organiserDirectory";

// == Global preferences ==

static ZoomPreferences* globalPreferences = nil;
static NSLock*          globalLock = nil;

+ (void)initialize {
	NSAutoreleasePool* apool = [[NSAutoreleasePool alloc] init];
	
    NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];
	ZoomPreferences* defaultPrefs = [[[self class] alloc] initWithDefaultPreferences];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject: [defaultPrefs dictionary]
															forKey: @"ZoomGlobalPreferences"];
	
	[defaultPrefs release];
	
    [defaults registerDefaults: appDefaults];
	
	globalLock = [[NSLock alloc] init];
	
	[apool release];
}

+ (ZoomPreferences*) globalPreferences {
	[globalLock lock];
	
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
	
	[globalLock unlock];
	
	return globalPreferences;
}

// == Initialisation ==

- (id) init {
	self = [super init];
	
	if (self) {
		prefLock = [[NSLock alloc] init];
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
	
	return [defaultColours autorelease];
}

- (id) initWithDefaultPreferences {
	self = [self init];
	
	if (self) {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
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
		
		[pool release];
	}
	
	return self;
}

- (id) initWithDictionary: (NSDictionary*) dict {
	self = [super init];
	
	if (self) {
		prefLock = [[NSLock alloc] init];
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
			NSLog(@"Unable to decode font block completely: using defaults");
			[prefs setObject: DefaultFonts()
					  forKey: fonts];
		}
		
		if (newColours && [newColours count] != 11) {
			NSLog(@"Unable to decode colour block completely: using defaults");
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
	[prefLock release];
	
	[super dealloc];
}

// Getting preferences
- (BOOL) displayWarnings {
	[prefLock lock];
	BOOL result = [[prefs objectForKey: displayWarnings] boolValue];
	[prefLock unlock];
	
	return result;
}

- (BOOL) fatalWarnings {
	[prefLock lock];
	BOOL result = [[prefs objectForKey: fatalWarnings] boolValue];
	[prefLock unlock];
	
	return result;
}

- (BOOL) speakGameText {
	[prefLock lock];
	BOOL result =  [[prefs objectForKey: speakGameText] boolValue];
	[prefLock unlock];
	
	return result;
}

- (NSString*) gameTitle {
	[prefLock lock];
	NSString* result =  [prefs objectForKey: gameTitle];
	[prefLock unlock];
	
	return result;
}

- (int) interpreter {
	[prefLock lock];
	BOOL result = [[prefs objectForKey: interpreter] intValue];
	[prefLock unlock];
	
	return result;
}

- (unsigned char) revision {
	[prefLock lock];
	unsigned char result = [[prefs objectForKey: revision] intValue];
	[prefLock unlock];
	
	return result;
}

- (NSArray*) fonts {
	[prefLock lock];
	NSArray* result = [prefs objectForKey: fonts];
	[prefLock unlock];
	
	return result;
}

- (NSArray*) colours {
	[prefLock lock];
	NSArray* result = [prefs objectForKey: colours];
	[prefLock unlock];
	
	return result;
}

- (NSString*) organiserDirectory {
	[prefLock lock];
	NSString* res = [prefs objectForKey: organiserDirectory];
	
	if (res == nil) {
		NSArray* docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		
		res = [[docDir objectAtIndex: 0] stringByAppendingPathComponent: @"Interactive Fiction"];
		
		NSLog(@"Can't find organiser directory preference: using default");
	}
	[prefLock unlock];
	
	return res;
}

- (BOOL) keepGamesOrganised {
	[prefLock lock];
	BOOL result = [[prefs objectForKey: keepGamesOrganised] boolValue];
	[prefLock unlock];
	
	return result;
}

- (BOOL) autosaveGames {
	[prefLock lock];
	NSNumber* autosave = [prefs objectForKey: autosaveGames];
	
	BOOL result = YES;
	if (autosave) result = [autosave boolValue];
	[prefLock unlock];
	
	return result;
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

- (void) setOrganiserDirectory: (NSString*) directory {
	if (directory != nil) {
		[prefs setObject: directory
				  forKey: organiserDirectory];
	} else {
		[prefs removeObjectForKey: organiserDirectory];
	}
	[self preferencesHaveChanged];
}

- (void) setKeepGamesOrganised: (BOOL) value {
	[prefs setObject: [NSNumber numberWithBool: value]
			  forKey: keepGamesOrganised];
	[self preferencesHaveChanged];
}

- (void) setAutosaveGames: (BOOL) value {
	[prefs setObject: [NSNumber numberWithBool: value]
			  forKey: autosaveGames];
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
