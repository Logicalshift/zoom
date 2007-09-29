//
//  ZoomPlugInManager.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 15/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugInManager.h"
#import <ZoomPlugIns/ZoomPlugInInfo.h>

NSString* ZoomPlugInInformationChangedNotification = @"ZoomPlugInInformationChangedNotification";

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
	
	[pluginInformation release];
	
	[super dealloc];
}

// = Setting the delegate =

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}

// = Dealing with existing plugins =

- (void) loadPluginsFrom: (NSString*) pluginPath {
	[pluginBundles release];
	[pluginClasses release];
	[pluginsToVersions release];
	
	pluginBundles = [[NSMutableArray alloc] init];
	pluginClasses = [[NSMutableArray alloc] init];
	pluginsToVersions = [[NSMutableDictionary alloc] init];
	
	[pluginInformation release];
	pluginInformation = nil;
	
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

			NSString* version = [self versionForBundle: pluginBundlePath];
			NSString* name = [self nameForBundle: pluginBundlePath];
			
			if (pluginBundlePath != nil && name == nil) {
				NSLog(@"== Not a valid plugin: %@", pluginBundlePath);
			}

			if (pluginBundle != nil && name != nil) {
				if ([pluginBundle load]) {
#if VERBOSITY >= 1
					NSLog(@"== Plugin loaded: %@", [plugin stringByDeletingPathExtension]);
#endif
					[pluginBundles addObject: pluginBundle];
					
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
	
	[self pluginInformationChanged];
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
	if (pluginBundle == nil) return nil;
	
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
	NSString* plistPath = [[pluginBundle stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"Info.plist"];
	
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

// = Getting information about plugins =

- (void) pluginInformationChanged {
	if (delegate && [delegate respondsToSelector: @selector(pluginInformationChanged)]) {
		[delegate pluginInformationChanged];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomPlugInInformationChangedNotification
														object: self];
}

static int RankForStatus(ZoomPlugInStatus status) {
	if (status == ZoomPlugInDownloadFailed) {
		return 6;
	}
	if (status == ZoomPluginUpdateAvailable 
		|| status == ZoomPlugInNew 
		|| status == ZoomPlugInDownloaded
		|| status == ZoomPlugInDownloading) {
		return 5;
	}
	if (status == ZoomPlugInUpdated) {
		return 4;
	}
	if (status == ZoomPlugInNotKnown || status == ZoomPlugInDisabled) {
		return 0;
	}
	
	return 1;
}

static int SortPlugInInfo(id a, id b, void* context) {
	ZoomPlugInInfo* first = a;
	ZoomPlugInInfo* second = b;
	
	// First sort by status: unknown at the bottom, new and updated at the top
	ZoomPlugInStatus firstStatus = [first status];
	ZoomPlugInStatus secondStatus = [second status];
	
	if (RankForStatus(firstStatus) < RankForStatus(secondStatus))
		return 1;
	else if (RankForStatus(firstStatus) > RankForStatus(secondStatus))
		return -1;
	else
		return 0;
	
	// Then sort by the name of the plugin
	return [[first name] caseInsensitiveCompare: [second name]];
}

- (void) sortInformation {
	// Sorts the plugin information array
	[pluginInformation sortUsingFunction: SortPlugInInfo
								 context: self];
}

- (void) addPlugInsFromDirectory: (NSString*) directory
						  status: (ZoomPlugInStatus) status {
	BOOL exists;
	BOOL isDir;
	exists = [[NSFileManager defaultManager] fileExistsAtPath: directory
												  isDirectory: &isDir];
	
	if (exists && isDir) {
		NSArray* plugins = [[NSFileManager defaultManager] directoryContentsAtPath: 
			directory];
		NSEnumerator* pluginEnum = [plugins objectEnumerator];
		NSString* pluginName;
		while (pluginName = [pluginEnum nextObject]) {
			NSString* fullPath = [directory stringByAppendingPathComponent: pluginName];
			
			// Get the info object
			ZoomPlugInInfo* information = [[ZoomPlugInInfo alloc] initWithBundleFilename: fullPath];
			if (information == nil) continue;
			[information setStatus: status];
			
			// Store in the array
			[pluginInformation addObject: [information autorelease]];
		}
	}	
}

- (void) setupInformation {
	// Sets up the initial plugin information array
	[pluginInformation release];
	pluginInformation = [[NSMutableArray alloc] init];
	
	// Get the information for all of the loaded plugins
	NSEnumerator* pluginEnum = [pluginBundles objectEnumerator];
	NSBundle* bundle;
	while (bundle = [pluginEnum nextObject]) {
		// Get the info object
		ZoomPlugInInfo* information = [[ZoomPlugInInfo alloc] initWithBundleFilename: [bundle bundlePath]];
		if (information == nil) continue;
		
		// Store in the array
		[pluginInformation addObject: [information autorelease]];
	}
	
	// Get the information for any plugins that are installed but disabled
	NSString* disabledPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"PlugIns Disabled"];
	[self addPlugInsFromDirectory: disabledPath
						   status: ZoomPlugInDisabled];
	
	// Get the information for any plugins that are waiting to be installed
	NSString* waitingPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"Contents"] stringByAppendingPathComponent: @"PlugIns Upgraded"];
	[self addPlugInsFromDirectory: waitingPath
						   status: ZoomPlugInUpdated];
	
	// Sort the plugin array
	[self sortInformation];
}

- (NSArray*) informationForPlugins {
	if (pluginInformation == nil) [self setupInformation];
	
	return pluginInformation;
}

- (void) startNextCheck {
	if (lastRequest != nil) return;
	
	// Get the next URL to check
	NSURL* nextUrl = nil;
	if ([checkUrls count] > 0) {
		nextUrl = [[[checkUrls lastObject] retain] autorelease];
		[checkUrls removeLastObject];
	}
	
	// We've finished if the next URL is nil
	if (nextUrl == nil) {
		[checkUrls release];
		checkUrls = nil;
		
		if (delegate && [delegate respondsToSelector: @selector(finishedCheckingForUpdates)]) {
			[delegate finishedCheckingForUpdates];
		}
		return;
	}
	
	// Create a new request
	NSLog(@"Checking for plug-in updates from %@", nextUrl);
	lastRequest = [[NSURLRequest requestWithURL: nextUrl
									cachePolicy: NSURLRequestReloadIgnoringCacheData
								timeoutInterval: 20] retain];
	[checkConnection release];
	checkConnection = [[NSURLConnection connectionWithRequest: lastRequest
													 delegate: self] retain];
}

- (void) checkForUpdatesFrom: (NSArray*) urls {
	// Get the set of URLs to check
	NSSet* uniqueUrls = [NSSet setWithArray: urls];
	
	// Store the set of URLs to check
	[checkUrls release];
	checkUrls = [[uniqueUrls allObjects] mutableCopy];
	
	// Notify the delegate that we're starting to check for updates
	if (delegate && [delegate respondsToSelector: @selector(checkingForUpdates)]) {
		[delegate checkingForUpdates];
	}
	
	// Start the next check for updates request
	[self startNextCheck];
}

- (void) checkForUpdates {
	// Build the list of places to check
	NSMutableArray* whereToCheck = [[NSMutableArray alloc] init];
	
	if (checkUrls != nil) {
		[whereToCheck addObjectsFromArray: checkUrls];
	}
	
#ifdef DEVELOPMENT
	[whereToCheck addObject: [NSURL URLWithString: [[NSBundle mainBundle] objectForInfoDictionaryKey: @"ZoomPluginFeedTestURL"]]];
#endif
	[whereToCheck addObject: [NSURL URLWithString: [[NSBundle mainBundle] objectForInfoDictionaryKey: @"ZoomPluginFeedURL"]]];
	
	// Start the check
	[self checkForUpdatesFrom: whereToCheck];
	[whereToCheck release];
}

- (BOOL) addUpdatedPlugin: (ZoomPlugInInfo*) plugin {
	// Find the old plugin that matches this one
	ZoomPlugInInfo* oldPlugIn = nil;
	
	NSEnumerator* pluginEnum = [[self informationForPlugins] objectEnumerator];
	ZoomPlugInInfo* maybePlugin;
	while (maybePlugin = [pluginEnum nextObject]) {
		if ([[plugin name] isEqualToString: [maybePlugin name]]) {
			oldPlugIn = [[maybePlugin retain] autorelease];
		}
	}
	
	// If there is no old plugin, then this plugin is new
	if (oldPlugIn == nil) {
		[plugin setStatus: ZoomPlugInNew];
		[pluginInformation addObject: plugin];
		[self sortInformation];
		return YES;
	}
	
	// If there is an old plugin, then compare the versions and mark the old plugin as updated if there's a new version available
	if ([self version: [plugin version]
		  isNewerThan: [oldPlugIn version]]) {
		[oldPlugIn setUpdateInfo: plugin];
		[oldPlugIn setStatus: ZoomPluginUpdateAvailable];
		[self sortInformation];
		return YES;
	}
	
	return NO;
}

// = Handling URL events =

- (void)  connection:(NSURLConnection *)connection 
  didReceiveResponse:(NSURLResponse *)response {
	if (connection == checkConnection) {
		// Got a response to the last check for updates URL
		[checkResponse release];
		checkResponse = [response retain];
		[checkData release];
		checkData = [[NSMutableData alloc] init];
	}
}

- (void)connection:(NSURLConnection *)connection 
  didFailWithError:(NSError *)error {
	if (connection == checkConnection) {
		// Got a response to the last check for updates URL
		[checkResponse release];
		checkResponse = nil;
		
		NSLog(@"Error while checking for updates: %@", error);
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if (connection == checkConnection) {
		[checkData appendData: data];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if (connection == checkConnection) {
		NSDictionary* result = nil;
		
		if (checkResponse != nil && checkData != nil) {
			// Handle the response
			result = [NSPropertyListSerialization propertyListFromData: checkData
													  mutabilityOption: NSPropertyListImmutable
																format: nil
													  errorDescription: nil];
		}
		
		if (result != nil) {
			// Iterate through the values in the result to get the current versions of the plugins specified in the XML file
			NSEnumerator* valueEnum = [[result allValues] objectEnumerator];
			NSDictionary* value;
			BOOL updated = NO;
			while (value = [valueEnum nextObject]) {
				// The entries must be dictionaries
				if (![value isKindOfClass: [NSDictionary class]])
					continue;
				
				// Work out the plugin information for this entry
				ZoomPlugInInfo* info = [[[ZoomPlugInInfo alloc] initFromPList: value] autorelease];
				if (info == nil)
					continue;
				
				// Work out what to do with this plugin
				if ([self addUpdatedPlugin: info]) {
					updated = YES;
				}
			}
			
			if (updated) {
				// Notify the delegate of the change
				if (delegate && [delegate respondsToSelector: @selector(pluginInformationChanged)]) {
					[delegate pluginInformationChanged];
				}
			}
		}
		
		// Move on to the next URL
		[lastRequest release]; lastRequest = nil;
		[checkConnection autorelease]; checkConnection = nil;
		[checkResponse autorelease]; checkResponse = nil;
		[checkData autorelease]; checkData = nil;
		
		[self startNextCheck];
	}	
}

// = Installing new plugins =

- (void) installPlugIn: (NSString*) pluginBundle {
	
}

- (void) finishUpdatingPlugins {
	
}

@end
