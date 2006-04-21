//
//  ZoomAppDelegate.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#include <unistd.h>

#import "ZoomAppDelegate.h"
#import "ZoomGameInfoController.h"
#import "ZoomSkeinController.h"

#import "ZoomMetadata.h"
#import "ZoomiFictionController.h"

#import "ZoomPlugIn.h"

@implementation ZoomAppDelegate

// = Initialisation =
+ (void) initialization {
	
}

- (id) init {
	self = [super init];
	
	if (self) {
		gameIndices = [[NSMutableArray alloc] init];

		NSString* configDir = [self zoomConfigDirectory];

		// Load the metadata
		NSData* userData = [NSData dataWithContentsOfFile: [configDir stringByAppendingPathComponent: @"metadata.iFiction"]];
		NSData* gameData = [NSData dataWithContentsOfFile: [configDir stringByAppendingPathComponent: @"gamedata.iFiction"]];
		NSData* infocomData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"infocom" ofType: @"iFiction"]];
		NSData* archiveData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"archive" ofType: @"iFiction"]];
		
		if (userData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: userData] autorelease]];
		else
			[gameIndices addObject: [[[ZoomMetadata alloc] init] autorelease]];

		if (gameData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: gameData] autorelease]];
		else
			[gameIndices addObject: [[[ZoomMetadata alloc] init] autorelease]];
		
		if (infocomData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: infocomData] autorelease]];
		if (archiveData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: archiveData] autorelease]];
		
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
						NSLog(@"Loaded %@", [plugin stringByDeletingPathExtension]);
						[pluginBundles addObject: pluginBundle];
						
						NSString* primaryClassName = [[pluginBundle infoDictionary] objectForKey: @"ZoomPluginClass"];
						Class primaryClass = [pluginBundle classNamed: primaryClassName];
						
						[pluginClasses addObject: primaryClass];
					}
				}
			}
		}
	}
	
	return self;
}

- (void) dealloc {
	if (preferencePanel) [preferencePanel release];
	[gameIndices release];
	
	[super dealloc];
}

// = Opening files =

- (BOOL) applicationShouldOpenUntitledFile: (NSApplication*) sender {
    return YES;
}

- (BOOL) applicationOpenUntitledFile:(NSApplication *)theApplication {
	[[[ZoomiFictionController sharediFictionController] window] makeKeyAndOrderFront: self];
	
	return YES;
}

- (BOOL)application: (NSApplication *)theApplication 
		   openFile: (NSString *)filename {
	// See if there's a plug-in that can handle this file. This gives plug-ins first shot at handling blorb files.
	NSEnumerator* pluginClassEnum = [pluginClasses objectEnumerator];
	Class pluginClass;
	
	while (pluginClass = [pluginClassEnum nextObject]) {
		if ([pluginClass canRunPath: filename]) {
			// TODO: work out when to release this class
			ZoomPlugIn* pluginInstance = [[pluginClass alloc] initWithFilename: filename];
			
			if (pluginInstance) {
				// ... we've managed to load this file with the given plug-in, so display it
				NSDocument* pluginDocument = [pluginInstance gameDocument];
				
				[[NSDocumentController sharedDocumentController] addDocument: pluginDocument];
				[pluginDocument makeWindowControllers];
				[pluginDocument showWindows];
				
				[pluginInstance autorelease];
				
				return YES;
			}
		}
	}

	// See if there's a built-in document handler for this file type (basically, this means z-code files)
	// TODO: we should probably do this with a plug-in now
	if ([[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: filename
																				display: YES]) {
		return YES;
	}
	
	if ([[[filename pathExtension] lowercaseString] isEqualToString: @"ifiction"]) {
		// Load extra iFiction data (not a 'real' file in that it's displayed in the iFiction window)
		[[ZoomiFictionController sharediFictionController] mergeiFictionFromFile: filename];
		return YES;
	}
		
	return NO;
}

// = General actions =
- (IBAction) showPreferences: (id) sender {
	if (!preferencePanel) {
		preferencePanel = [[ZoomPreferenceWindow alloc] init];
	}
	
	[[preferencePanel window] center];
	[preferencePanel setPreferences: [ZoomPreferences globalPreferences]];
	[[preferencePanel window] makeKeyAndOrderFront: self];
}

- (IBAction) displayGameInfoWindow: (id) sender {
	[[ZoomGameInfoController sharedGameInfoController] showWindow: self];
	
	// Blank out the game info window
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == nil) {
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
	}
}

- (IBAction) displaySkein: (id) sender {
	[[ZoomSkeinController sharedSkeinController] showWindow: self];

	[NSApp sendAction: @selector(updateSkein:)
				   to: nil
				 from: self];
}

- (IBAction) displayNoteWindow: (id) sender {
}

- (IBAction) showiFiction: (id) sender {
	[[[ZoomiFictionController sharediFictionController] window] makeKeyAndOrderFront: self];
}

// = Application-wide data =
- (NSArray*) gameIndices {
	return gameIndices;
}

- (ZoomStory*) findStory: (ZoomStoryID*) gameID {
	NSEnumerator* indexEnum = [gameIndices objectEnumerator];
	ZoomMetadata* repository;
	
	while (repository = [indexEnum nextObject]) {
		if (![repository containsStoryWithIdent: gameID]) continue;
		
		ZoomStory* res = [repository findOrCreateStory: gameID];
		return res;
	}
	
	return nil;
}

- (ZoomMetadata*) userMetadata {
	return [gameIndices objectAtIndex: 0];
}

- (NSString*) zoomConfigDirectory {
	// The app delegate may not be the best place for this routine... Maybe a function somewhere
	// would be better?
	NSArray* libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	
	NSEnumerator* libEnum;
	NSString* libDir;

	libEnum = [libraryDirs objectEnumerator];
	
	while (libDir = [libEnum nextObject]) {
		BOOL isDir;
		
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] fileExistsAtPath: zoomLib isDirectory: &isDir]) {
			if (isDir) {
				return zoomLib;
			}
		}
	}
	
	libEnum = [libraryDirs objectEnumerator];
	
	while (libDir = [libEnum nextObject]) {
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] createDirectoryAtPath: zoomLib
													   attributes:nil]) {
			return zoomLib;
		}
	}
	
	return nil;
}

@end
