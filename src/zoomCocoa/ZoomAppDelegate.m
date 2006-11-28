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
#import "ZoomStoryOrganiser.h"

NSString* ZoomOpenPanelLocation = @"ZoomOpenPanelLocation";

@implementation ZoomAppDelegate

// = Initialisation =
+ (void) initialization {
	
}

- (id) init {
	self = [super init];
	
	if (self) {
		// Ensure the plugins are available
		NSLog(@"= Loading plugins");
		[ZoomPlugIn loadPlugins];
		
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
	// 'Opening an untitled file' is an action that occurs when the user clicks on the 'Z' icon...
    return YES;
}

- (BOOL) applicationOpenUntitledFile:(NSApplication *)theApplication {
	// ... which we want to have the effect of showing the iFiction window
	[[[ZoomiFictionController sharediFictionController] window] makeKeyAndOrderFront: self];
	
	return YES;
}

- (BOOL)application: (NSApplication *)theApplication 
		   openFile: (NSString *)filename {
	// See if there's a plug-in that can handle this file. This gives plug-ins first shot at handling blorb files.
	Class pluginClass = [ZoomPlugIn pluginForFile: filename];
	
	if (pluginClass) {
		// TODO: work out when to release this class
		ZoomPlugIn* pluginInstance = [[pluginClass alloc] initWithFilename: filename];
		
		if (pluginInstance) {
			// Register this game with iFiction
			ZoomStoryID* ident = [pluginInstance idForStory];
			ZoomStory* story = [pluginInstance defaultMetadata];
				
			if (ident != nil && story != nil) {
				if ([self findStory: ident] == nil) {
					[[self userMetadata] copyStory: story
											  toId: ident];
				} 
				
				[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: filename
														  withIdent: ident
														   organise: [[ZoomPreferences globalPreferences] keepGamesOrganised]];					
			}
			
			// ... we've managed to load this file with the given plug-in, so display it
			NSDocument* pluginDocument = [pluginInstance gameDocumentWithMetadata: story];
			
			[[NSDocumentController sharedDocumentController] addDocument: pluginDocument];
			[pluginDocument makeWindowControllers];
			[pluginDocument showWindows];
			
			[pluginInstance autorelease];
			
			return YES;
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

- (IBAction) fixedOpenDocument: (id) sender {
	// The standard open dialog does not go through the applicationOpenFile: mechanism, or know about plugins.
	// This version does.
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	
	NSString* directory = [[NSUserDefaults standardUserDefaults] objectForKey: ZoomOpenPanelLocation];
	if (directory == nil) {
		directory = [@"~" stringByStandardizingPath];
	} else {
		directory = [directory stringByStandardizingPath];
	}
	
	// Set up the open panel
	[openPanel setDelegate: self];
	[openPanel setCanChooseFiles: YES];
	[openPanel setResolvesAliases: YES];
	[openPanel setTitle: @"Open Story"];
	[openPanel setDirectory: directory];
	[openPanel setAllowsMultipleSelection: YES];
	
	// Run the panel
	int result = [openPanel runModal];
	if (result != NSFileHandlingPanelOKButton) return;
	
	// Remember the directory
	[[NSUserDefaults standardUserDefaults] setObject: [openPanel directory]
											  forKey: ZoomOpenPanelLocation];
	
	// Open the file(s)
	NSArray* files = [openPanel filenames];
	NSEnumerator* fileEnum = [files objectEnumerator];
	NSString* file;
	while (file = [fileEnum nextObject]) {
		[self application: NSApp
				 openFile: file];
	}
}

- (BOOL)		panel:(id)sender 
   shouldShowFilename:(NSString *)filename {
	BOOL exists;
	BOOL isDirectory;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: filename
												  isDirectory: &isDirectory];
	if (!exists) return NO;
	
	// Show directories that are not packages
	if (isDirectory) {
		if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: filename]) {
			return NO;
		} else {
			return YES;
		}
	}
	
	// Don't show non-readable files
	if (![[NSFileManager defaultManager] isReadableFileAtPath: filename]) {
		return NO;
	}
	
	// Show files that have a valid plugin
	Class pluginClass = [ZoomPlugIn pluginForFile: filename];
	
	if (pluginClass != nil) {
		return YES;
	}
	
	// Show files that we can open with the ZoomClient document type
	NSArray* extensions = [[NSDocumentController sharedDocumentController] fileExtensionsFromType: @"ZCode story"];
	NSEnumerator* extnEnum = [extensions objectEnumerator];
	NSString* extn;
	NSString* fileExtension = [[filename pathExtension] lowercaseString];
	while (extn = [extnEnum nextObject]) {
		if ([extn isEqualToString: fileExtension]) return YES;
	}

	extensions = [NSArray arrayWithObjects: @"zblorb", @"zlb", nil];
	extnEnum = [extensions objectEnumerator];
	while (extn = [extnEnum nextObject]) {
		if ([extn isEqualToString: fileExtension]) return YES;
	}
	
	extensions = [[NSDocumentController sharedDocumentController] fileExtensionsFromType: @"Blorb resource file"];
	extnEnum = [extensions objectEnumerator];
	while (extn = [extnEnum nextObject]) {
		if ([extn isEqualToString: fileExtension]) return YES;
	}
	
	return NO;
}

- (BOOL)        panel:(id)sender
	  isValidFilename:(NSString *)filename {
	if (![self panel: sender shouldShowFilename: filename]) return NO; 

	BOOL exists;
	BOOL isDirectory;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: filename
												  isDirectory: &isDirectory];
	
	if (!exists) return NO;
	if (isDirectory) return NO;
	
	return YES;
}

@end
