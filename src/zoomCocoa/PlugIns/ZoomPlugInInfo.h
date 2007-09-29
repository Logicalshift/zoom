//
//  ZoomPlugInInfo.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum ZoomPlugInStatus {
	ZoomPlugInInstalled,									// Installed plugin
	ZoomPlugInDisabled,										// Installed plugin that has been disabled
	ZoomPlugInUpdated,										// Installed plugin, update to be installed
	ZoomPlugInDownloaded,									// Downloaded plugin available to install
	ZoomPluginUpdateAvailable,								// Update available to download
	ZoomPlugInNew,											// Not yet installed, available to download
	ZoomPlugInNotKnown,										// Unknown status
} ZoomPlugInStatus;

///
/// Class representing information about a known plugin
///
@interface ZoomPlugInInfo : NSObject<NSCopying> {
	NSString* image;										// The filename of an image for this plugin
	NSString* name;											// The name of the plugin
	NSString* author;										// The author of the plugin
	NSString* interpreterAuthor;							// The author of the interpreter
	NSString* version;										// The version number of the plugin
	NSString* interpreterVersion;							// The version number of the interpreter contained in the plugin
	ZoomPlugInStatus status;								// The status for this plugin
}

// Initialisation
- (id) initWithBundleFilename: (NSString*) bundle;			// Initialise with an existing plugin bundle

// Retrieving the information
- (NSString*) name;											// The name of this plugin
- (NSString*) author;										// The author of the plugin bundle
- (NSString*) version;										// The version of the plugin bundle
- (NSString*) interpreterAuthor;							// The author of the interpreter in the plugin
- (NSString*) interpreterVersion;							// The version of the interpreter in the plugin
- (NSString*) imagePath;									// The path to an image that represents this plugin
- (ZoomPlugInStatus) status;								// The status for this plugin
- (void) setStatus: (ZoomPlugInStatus) status;				// Updates the status for this plugin

@end
