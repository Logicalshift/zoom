//
//  ZoomStoryOrganiser.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomStoryOrganiser.h"

NSString* ZoomStoryOrganiserChangedNotification = @"ZoomStoryOrganiserChangedNotification";
static NSString* defaultName = @"ZoomStoryOrganiser";

@implementation ZoomStoryOrganiser

// = Internal functions =
- (NSDictionary*) dictionary {
	NSMutableDictionary* defaultDictionary = [NSMutableDictionary dictionary];
	
	NSEnumerator* filenameEnum = [filenamesToIdents keyEnumerator];
	NSString* filename;
	
	while (filename = [filenameEnum nextObject]) {
		NSData* encodedId = [NSArchiver archivedDataWithRootObject: [filenamesToIdents objectForKey: filename]];
		
		[defaultDictionary setObject: encodedId
							  forKey: filename];
	}
	
	return defaultDictionary;
}

- (void) storePreferences {
	[[NSUserDefaults standardUserDefaults] setObject:[self dictionary] 
											  forKey:defaultName];
}

- (void) loadPreferences {
	NSDictionary* prefs = [[NSUserDefaults standardUserDefaults] objectForKey: defaultName];
	
	NSEnumerator* filenameEnum = [prefs keyEnumerator];
	NSString* filename;
	
	while (filename = [filenameEnum nextObject]) {
		NSData* storyData = [prefs objectForKey: filename];
		ZoomStoryID* fileID = [NSUnarchiver unarchiveObjectWithData: storyData];
		
		if (fileID != nil) {
			[self addStory: filename 
				 withIdent: fileID 
				  organise: NO];
		}
	}
}

- (void) organiserChanged {
	[self storePreferences];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryOrganiserChangedNotification
														object: self];
}

// = Initialisation =
+ (void) initialize {
	// User defaults
    NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];
	ZoomStoryOrganiser* defaultPrefs = [[[[self class] alloc] init] autorelease];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject: [defaultPrefs dictionary]
															forKey: defaultName];
	
    [defaults registerDefaults: appDefaults];	
}

- (id) init {
	self = [super init];
	
	if (self) {
		storyFilenames = [[NSMutableArray alloc] init];
		storyIdents = [[NSMutableArray alloc] init];
		
		filenamesToIdents = [[NSMutableDictionary alloc] init];
		identsToFilenames = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[storyFilenames release];
	[storyIdents release];
	[filenamesToIdents release];
	[identsToFilenames release];
	
	[super dealloc];
}

// = The shared organiser =
static ZoomStoryOrganiser* sharedOrganiser = nil;

+ (ZoomStoryOrganiser*) sharedStoryOrganiser {
	if (!sharedOrganiser) {
		sharedOrganiser = [[ZoomStoryOrganiser alloc] init];
		[sharedOrganiser loadPreferences];
	}
	
	return sharedOrganiser;
}

// = Storing stories =
- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident {
	[self addStory: filename
		 withIdent: ident
		  organise: NO];
}

- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident
		 organise: (BOOL) organise {
	// FIXME: Organise not supported yet
	if (organise) {
		// Move to a standard directory, change the filename we're using
	}
	
	NSString* oldFilename;
	ZoomStoryID* oldIdent;
	
	oldFilename = [identsToFilenames objectForKey: ident];
	oldIdent = [filenamesToIdents objectForKey: filename];
	
	if (oldFilename && oldIdent && [oldFilename isEqualToString: filename] && [oldIdent isEqualTo: ident]) {
		// Nothing to do
		NSLog(@"ZZzz");
		return;
	}
	
	if (oldFilename) {
		[identsToFilenames removeObjectForKey: ident];
		[storyFilenames removeObject: oldFilename];
	}
	
	if (oldIdent) {
		[filenamesToIdents removeObjectForKey: filename];
		[storyIdents removeObject: oldIdent];
	}
	
	NSString* newFilename = [[filename copy] autorelease];
	NSString* newIdent    = [[ident copy] autorelease];
	
	[storyFilenames addObject: newFilename];
	[storyIdents addObject: newIdent];
	
	[identsToFilenames setObject: newFilename forKey: newIdent];
	[filenamesToIdents setObject: newIdent forKey: newFilename];
	
	[self organiserChanged];
}

// = Retrieving story information =
- (NSString*) filenameForIdent: (ZoomStoryID*) ident {
	return [filenamesToIdents objectForKey: ident];
}

- (ZoomStoryID*) identForFilename: (NSString*) filename {
	return [identsToFilenames objectForKey: filename];
}

- (NSArray*) storyFilenames {
	return storyFilenames;
}

- (NSArray*) storyIdents {
	return storyIdents;
}

@end
