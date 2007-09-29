//
//  ZoomPlugInManager.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 15/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomPlugIn.h>

//
// Class that manages the plugins installed with Zoom
//
@interface ZoomPlugInManager : NSObject {
	NSLock* pluginLock;										// The plugin lock
	id delegate;											// The delegate for this class
	
	NSMutableArray* pluginBundles;							// The bundles containing the loaded plugins
	NSMutableArray* pluginClasses;							// The ZoomPlugIn classes from the bundles
	NSMutableDictionary* pluginsToVersions;					// Array mapping plugin versions to names
	
	NSString* lastPlistPlugin;								// The path of the last plugin we retrieved a plist for
	NSDictionary* lastPlist;								// The plist retrieved from the lastPlistPlugin
}

+ (ZoomPlugInManager*) sharedPlugInManager;					// The shared plug-in manager

// Setting the delegate
- (void) setDelegate: (id) delegate;						// Sets a new plug-in delegate

// Dealing with existing plugins
- (void) loadPlugIns;										// Causes this class to load all of the plugins
- (Class) plugInForFile: (NSString*) fileName;				// Gets the plugin for the specified file
- (ZoomPlugIn*) instanceForFile: (NSString*) filename;		// Gets a plug-in instance for the specified file

- (NSArray*) pluginBundles;									// The loaded plugin bundles
- (NSArray*) loadedPlugIns;									// Array of strings indicating the names of the loaded plugins
- (NSString*) versionForPlugIn: (NSString*) plugin;			// Returns the version of the plugin with the specified name
- (BOOL) version: (NSString*) oldVersion					// Compares 
	 isNewerThan: (NSString*) newVerison;

// Installing new plugins
- (void) installPlugIn: (NSString*) pluginBundle;			// Requests that the specified plugin be installed
- (void) finishUpdatingPlugins;								// Causes Zoom to finish updating any plugins after a restart

- (NSDictionary*) plistForBundle: (NSString*) pluginBundle;	// Retrieves the plist dictionary for the specified plugin bundle
- (NSString*) nameForBundle: (NSString*) pluginBundle;		// Retrieves the display name of the specified plugin bundle
- (NSString*) authorForBundle: (NSString*) pluginBundle;	// Retrieves the author of the specified plugin
- (NSString*) terpAuthorForBundle: (NSString*) pluginBundle;	// Retrieves the author of the interpreter of the specified plugin
- (NSString*) versionForBundle: (NSString*) pluginBundle;	// Retrieves the version number of the specified plugin bundle

@end

//
// Delegate methods
//
@interface NSObject(ZoomPlugInManagerDelegate)

- (void) needsRestart;										// Indicates that the plug-in manager needs a restart before it can continue

@end