//
//  ZoomPlugInManager.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 15/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugInManager.h"


@implementation ZoomPlugInManager

// = Initialisation =

+ (ZoomPlugInManager*) sharedPlugInManager {
	static ZoomPlugInManager* sharedManager = nil;
	
	if (!sharedManager) {
		sharedManager = [[ZoomPlugInManager alloc] init];
	}
	
	return sharedManager;
}

- (id) init {
	self = [super init];
	
	if (self) {
		pluginLock = [[NSLock alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[pluginLock release];
	[pluginBundles release];
	[pluginClasses release];
	[pluginsToVersions release];
	
	[lastPlist release];
	[lastPlistPlugin release];
	
	[super dealloc];
}

// = Setting the delegate =

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}

// = Dealing with existing plugins =

- (void) loadPluginsFrom: (NSString*) pluginPath {
	pluginBundles = [[NSMutableArray alloc] init];
	pluginClasses = [[NSMutableArray alloc] init];
	pluginsToVersions = [[NSMutableDictionary alloc] init];
	
#if VERBOSITY >= 2
	NSLog(@"= Loading plugins from: %@", pluginPath);
#endif
	NSEnumerator* pluginEnum = [[[NSFileManager defaultManager] directoryContentsAtPath: pluginPath] objectEnumerator];
	
	NSString* plugin;
	while (plugin = [pluginEnum nextObject]) {
#if VERBOSITY >= 2
		NSLog(@"= Found file: %@", plugin);
#endif
		if ([[[plugin pathExtension] lowercaseString] isEqualToString: @"bundle"]
			|| [[[plugin pathExtension] lowercaseString] isEqualToString: @"plugin"]
			|| [[[plugin pathExtension] lowercaseString] isEqualToString: @"zoomplugin"]) {
			NSString* pluginBundlePath = [pluginPath stringByAppendingPathComponent: plugin];
			NSBundle* pluginBundle = [NSBundle bundleWithPath: pluginBundlePath];
			
			if (pluginBundle != nil) {
				if ([pluginBundle load]) {
#if VERBOSITY >= 1
					NSLog(@"== Plugin loaded: %@", [plugin stringByDeletingPathExtension]);
#endif
					[pluginBundles addObject: pluginBundle];
					
					NSString* version = [self versionForBundle: pluginBundlePath];
					NSString* name = [self nameForBundle: pluginBundlePath];
					
					[pluginsToVersions setObject: version
										  forKey: name];
					
					Class primaryClass = [pluginBundle principalClass];
					[pluginClasses addObject: primaryClass];
#if VERBOSITY >= 2
					NSLog(@"=== Principal class: %@", [primaryClass description]);
#endif
				}
			}
		}
	}	
}

- (void) loadPlugIns {
	if (pluginBundles == nil) {
#if VERBOSITY >= 2
		NSLog(@"= Will load plugin bundles now");
#endif
		
		// Load the plugins
		NSString* pluginPath = [[NSBundle mainBundle] builtInPlugInsPath];
		[self loadPluginsFrom: pluginPath];
		
		if ([pluginClasses count] == 0) {
			NSString* pluginPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents/PlugIns"];
#if VERBOSITY >=1
			NSLog(@"= Trying harder to load plugins");
#endif
			[self loadPluginsFrom: pluginPath];
		}
	}	
}

- (Class) plugInForFile: (NSString*) filename {
#if VERBOSITY >= 3
	NSLog(@"= Seeking a plugin for %@", filename);
#endif
	
	[self loadPlugIns];
	
	NSEnumerator* pluginClassEnum = [pluginClasses objectEnumerator];
	Class pluginClass;
	
	while (pluginClass = [pluginClassEnum nextObject]) {
		if ([pluginClass canRunPath: filename]) {
#if VERBOSITY >=3
			NSLog(@"= Found %@", [pluginClass description]);
#endif
			return pluginClass;
		}
	}
	
#if VERBOSITY >= 3
	NSLog(@"= No plugins found (will try z-code)", filename);
#endif
	return nil;
}

- (ZoomPlugIn*) instanceForFile: (NSString*) filename {
	[pluginLock lock];
	
	Class pluginClass = [self plugInForFile: filename];
	if (pluginClass == nil) {
		[pluginLock unlock];
		return nil;
	}
	
#if VERBOSITY >= 3
	NSLog(@"= Instantiating %@ for %@", [pluginClass description], filename);
#endif
	ZoomPlugIn* instance = [[[pluginClass alloc] initWithFilename: filename] autorelease];
	
	[pluginLock unlock];
	return instance;	
}

- (NSArray*) pluginBundles {
	return pluginBundles;
}

- (NSArray*) loadedPlugIns {
	return [pluginsToVersions allKeys];
}

- (NSString*) versionForPlugIn: (NSString*) plugin {
	return [pluginsToVersions objectForKey: plugin];
}

- (NSArray*) arrayForVersion: (NSString*) version {
	NSMutableArray* result = [NSMutableArray array];
	
	unichar chr;
	int lastPos = 0;
	int x;
	for (x=0; x<[version length]; x++) {
		chr = [version characterAtIndex: x];
		
		if (chr == '.') {
			[result addObject: [version substringWithRange: NSMakeRange(lastPos, x-lastPos)]];
			lastPos = x+1;
		}
	}
	
	return result;
}

- (BOOL) version: (NSString*) oldVersion
	 isNewerThan: (NSString*) newVersion {
	// Divide the two versions into strings separated by '.'s
	NSArray* oldVersionArray = [self arrayForVersion: oldVersion];
	NSArray* newVersionArray = [self arrayForVersion: newVersion];
	
	int length = [oldVersionArray count];
	if ([newVersionArray count] > length) length = [newVersionArray count];
	int x;
	for (x=length-1; x>=0; x--) {
		NSString* old = x<[oldVersionArray count]?[oldVersionArray objectAtIndex: x]:@"0";
		NSString* new = x<[newVersionArray count]?[newVersionArray objectAtIndex: x]:@"0";
		
		if ([old intValue] > [new intValue]) return YES;
	}
	
	return NO;
}

// = Getting information about plugins =

- (NSDictionary*) plistForBundle: (NSString*) pluginBundle {
	// Standardise the plugin path
	pluginBundle = [pluginBundle stringByStandardizingPath];
	
	// Use the cached version of the plist if we've already got it loaded
	if ([pluginBundle isEqualToString: lastPlistPlugin]) {
		return lastPlist;
	}
	
	// Clear the cache
	[lastPlistPlugin release];
	[lastPlist release];
		
	lastPlistPlugin = [pluginBundle copy];
	lastPlist = nil;
		
	// Check that the bundle exists and is a directory
	BOOL exists;
	BOOL isDir;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: pluginBundle
												  isDirectory: &isDir];
	if (!exists || !isDir) {
		return nil;
	}
	
	// Check that the plist file exists
	NSString* plistPath = [pluginBundle stringByAppendingPathComponent: @"Info.plist"];
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: plistPath
												  isDirectory: &isDir];
	if (!exists || isDir) {
		return nil;
	}
	
	// Try to load the plist file from the bundle
	NSDictionary* plistDictionary = [NSDictionary dictionaryWithContentsOfFile: plistPath];
	if (plistDictionary == nil) {
		return nil;
	}
	
	// Must contain a ZoomPlugin key
	if (![plistDictionary objectForKey: @"ZoomPlugin"]) {
		return nil;
	}
	
	if (![[plistDictionary objectForKey: @"ZoomPlugin"] isKindOfClass: [NSDictionary class]]) {
		return nil;
	}
	
	// Plugin is OK: return the result
	return lastPlist = [plistDictionary retain];
}

- (NSString*) nameForBundle: (NSString*) pluginBundle {
	// Get the plist for the plugin
	NSDictionary* plist = [self plistForBundle: pluginBundle];
	if (plist == nil) return nil;
	NSDictionary* zoomPlugins = [plist objectForKey: @"ZoomPlugin"];
	
	// Get the name for this plugin
	NSString* result;
	result = [zoomPlugins objectForKey: @"DisplayName"];
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = @"Untitled";
	}
	
	return result;
}

- (NSString*) authorForBundle: (NSString*) pluginBundle {
	// Get the plist for the plugin
	NSDictionary* plist = [self plistForBundle: pluginBundle];
	if (plist == nil) return nil;
	NSDictionary* zoomPlugins = [plist objectForKey: @"ZoomPlugin"];
	
	// Get the name for this plugin
	NSString* result;
	result = [zoomPlugins objectForKey: @"Author"];
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = [zoomPlugins objectForKey: @"InterpreterAuthor"];
	}
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = nil;
	}
	
	return result;	
}

- (NSString*) versionForBundle: (NSString*) pluginBundle {
	// Get the plist for the plugin
	NSDictionary* plist = [self plistForBundle: pluginBundle];
	if (plist == nil) return nil;
	NSDictionary* zoomPlugins = [plist objectForKey: @"ZoomPlugin"];
	
	// Get the name for this plugin
	NSString* result;
	result = [zoomPlugins objectForKey: @"Version"];
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = nil;
	}
	
	return result;		
}

- (NSString*) terpAuthorForBundle: (NSString*) pluginBundle {
	// Get the plist for the plugin
	NSDictionary* plist = [self plistForBundle: pluginBundle];
	if (plist == nil) return nil;
	NSDictionary* zoomPlugins = [plist objectForKey: @"ZoomPlugin"];
	
	// Get the name for this plugin
	NSString* result;
	result = [zoomPlugins objectForKey: @"InterpreterAuthor"];
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = [zoomPlugins objectForKey: @"Author"];
	}
	if (result == nil || ![result isKindOfClass: [NSString class]]) {
		result = nil;
	}
	
	return result;		
}

// = Installing new plugins =

- (void) installPlugIn: (NSString*) pluginBundle {
	
}

- (void) finishUpdatingPlugins {
	
}

@end
