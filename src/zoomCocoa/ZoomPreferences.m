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
	}
	
	return self;
}

- (void) dealloc {
	[prefs release];
	
	[super dealloc];
}

@end
