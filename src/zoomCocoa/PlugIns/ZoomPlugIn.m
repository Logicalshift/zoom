//
//  ZoomPlugIn.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugIn.h"


@implementation ZoomPlugIn

// = Loading a plugin =

static NSLock* pluginLock = nil;
static NSMutableArray* pluginBundles = nil;
static NSMutableArray* pluginClasses = nil;

+ (void) initialize {
	if (pluginLock == nil) pluginLock = [[NSLock alloc] init];
}

+ (Class) pluginForFile: (NSString*) filename {
	if (pluginBundles == nil) {
		// Load the plugins
		pluginBundles = [[NSMutableArray alloc] init];
		pluginClasses = [[NSMutableArray alloc] init];
		
		NSString* pluginPath = [[NSBundle mainBundle] builtInPlugInsPath];
		NSEnumerator* pluginEnum = [[[NSFileManager defaultManager] directoryContentsAtPath: pluginPath] objectEnumerator];
		
		NSString* plugin;
		while (plugin = [pluginEnum nextObject]) {
			if ([[plugin pathExtension] isEqualToString: @"bundle"]) {
				NSBundle* pluginBundle = [NSBundle bundleWithPath: [pluginPath stringByAppendingPathComponent: plugin]];
				
				if (pluginBundle != nil) {
					if ([pluginBundle load]) {
						NSLog(@"== Plugin loaded: %@", [plugin stringByDeletingPathExtension]);
						[pluginBundles addObject: pluginBundle];
						
						NSString* primaryClassName = [[pluginBundle infoDictionary] objectForKey: @"ZoomPluginClass"];
						Class primaryClass = [pluginBundle classNamed: primaryClassName];
						
						[pluginClasses addObject: primaryClass];
					}
				}
			}
		}
	}
	
	NSEnumerator* pluginClassEnum = [pluginClasses objectEnumerator];
	Class pluginClass;
	
	while (pluginClass = [pluginClassEnum nextObject]) {
		if ([pluginClass canRunPath: filename]) {
			return pluginClass;
		}
	}
	
	return nil;
}

+ (ZoomPlugIn*) instanceForFile: (NSString*) filename {
	[pluginLock lock];
	
	Class pluginClass = [ZoomPlugIn pluginForFile: filename];
	if (pluginClass == nil) {
		[pluginLock unlock];
		return nil;
	}
	
	ZoomPlugIn* instance = [[[pluginClass alloc] initWithFilename: filename] autorelease];
	
	[pluginLock unlock];
	return instance;
}

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

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story {
	[NSException raise: @"ZoomNoPlugInInterface" 
				format: @"An attempt was made to load a game whose plugin does not provide an interface"];
	
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
