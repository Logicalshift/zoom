//
//  ZoomPlugIn.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugIn.h"


@implementation ZoomPlugIn

// = Informational functions (subclasses should normally override) =

+ (NSString*) pluginVersion {
	NSLog(@"Warning: loaded a plugin which does not provide pluginVersion");
	
	return @"Unknown";
}

+ (NSString*) pluginDescription {
	NSLog(@"Warning: loaded a plugin which does not provide pluginDescription");
	
	return @"Unknown plugin";
}

+ (NSString*) pluginAuthor {
	NSLog(@"Warning: loaded a plugin which does not provide pluginAuthor");
	
	return @"Joe Anonymous";
}

+ (BOOL) canLoadSavegames {
	return NO;
}

+ (BOOL) canRunPath: (NSString*) path {
	return NO;
}

// = Designated initialiser =

- (id) init {
	[NSException raise: @"ZoomNoPluginFilename"
				format: @"An attempt was made to construct a plugin object without providing a filename"];
	
	return nil;
}

- (id) initWithFilename: (NSString*) filename {
	self = [super init];
	
	if (self) {
		gameFile = [filename copy];
		gameData = nil;
	}
	
	return self;
}

- (void) dealloc {
	[gameData release]; gameData = nil;
	[gameFile release]; gameFile = nil;
	
	[super dealloc];
}

// = Getting information about what this plugin should be doing =

- (NSString*) gameFilename {
	return gameFile;
}

- (NSData*) gameData {
	if (gameData == nil) {
		gameData = [[NSData alloc] initWithContentsOfFile: gameFile];
	}
	
	return gameData;
}

// = The game window =

- (NSWindowController*) gameWindowController {
	[NSException raise: @"ZoomNoPlugInWindow" 
				format: @"An attempt was made to load a game whose plugin does not provide a window"];
	
	return nil;
}

// = Dealing with game metadata =

- (ZoomStoryID*) idForStory {
	// Generate an MD5-based ID
	return [[[ZoomStoryID alloc] initWithData: [self gameData]] autorelease];
}

- (ZoomStory*) defaultMetadata {
	// Just use the default metadata-establishing routine
	return [ZoomStory defaultMetadataForFile: gameFile]; 
}

@end
