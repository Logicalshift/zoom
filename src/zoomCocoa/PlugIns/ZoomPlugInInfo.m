//
//  ZoomPlugInInfo.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <ZoomPlugIns/ZoomPlugInInfo.h>
#import "ZoomPlugInManager.h"


@implementation ZoomPlugInInfo

// = Initialisation =

- (id) initWithBundleFilename: (NSString*) bundle {
	self = [super init];
	
	if (self) {
		NSDictionary* plist = [[ZoomPlugInManager sharedPlugInManager] plistForBundle: bundle];
		
		// No information available if there's no plist for this bundle
		if (plist == nil) {
			[self release];
			return nil;
		}
		
		// Get the information out of the plist
		name				= [[[ZoomPlugInManager sharedPlugInManager] nameForBundle: bundle] retain];
		author				= [[[ZoomPlugInManager sharedPlugInManager] authorForBundle: bundle] retain];
		interpreterAuthor	= [[[ZoomPlugInManager sharedPlugInManager] terpAuthorForBundle: bundle] retain];
		interpreterVersion	= [[[plist objectForKey: @"ZoomPlugin"] objectForKey: @"InterpreterVersion"] retain];
		version				= [[[ZoomPlugInManager sharedPlugInManager] versionForBundle: bundle] retain];
		image				= [[plist objectForKey: @"ZoomPlugin"] objectForKey: @"Image"];		
		
		if (image != nil) {
			image = [[bundle stringByAppendingPathComponent: image] stringByStandardizingPath];
		}
		
		[image retain];
		
		// Work out the status (installed or downloaded as we're working from a path)
		NSString* standardPath = [bundle stringByStandardizingPath];
		NSString* mainBundlePath = [[[NSBundle mainBundle] bundlePath] stringByStandardizingPath];
		
		if ([mainBundlePath characterAtIndex: [mainBundlePath length]-1] != '/') {
			mainBundlePath = [mainBundlePath stringByAppendingString: @"/"];
		}
		
		if ([standardPath hasPrefix: mainBundlePath]) {
			status = ZoomPlugInInstalled;
		} else {
			status = ZoomPlugInDownloaded;
		}
		
		location = [[NSURL fileURLWithPath: bundle] copy];
	}
	
	return self;
}

- (id) initFromPList: (NSDictionary*) plist {
	self = [super init];
	
	if (self) {
		// No information available if there's no plist for this bundle
		if (plist == nil) {
			[self release];
			return nil;
		}
		
		// Get the information out of the plist
		name				= [[plist objectForKey: @"DisplayName"] retain];
		author				= [[plist objectForKey: @"Author"] retain];
		interpreterAuthor	= [[plist objectForKey: @"InterpreterAuthor"] retain];
		interpreterVersion	= [[plist objectForKey: @"InterpreterVersion"] retain];
		version				= [[plist objectForKey: @"Version"] retain];
		image				= nil;		
		status				= ZoomPlugInNotKnown;
		
		if ([plist objectForKey: @"URL"] != nil) {
			location = [[NSURL URLWithString: [plist objectForKey: @"URL"]] copy];			
		}
		
		// Check the plist entries
		if (name == nil) {
			[self release];
			return nil;
		}
		if (author == nil) {
			if (interpreterAuthor == nil) {
				[self release];
				return nil;
			}
			author = [interpreterAuthor retain];
		}
		if (interpreterAuthor == nil) {
			interpreterAuthor = [author retain];
		}
		if (version == nil || interpreterVersion == nil) {
			[self release];
			return nil;
		}
	}
	
	return self;	
}

- (void) dealloc {
	[name release];
	[author release];
	[interpreterVersion release];
	[interpreterAuthor release];
	[version release];
	[image release];
	[location release];
	[updated release];
	[updateDownload release];
	
	[super dealloc];
}

// = Copying =

- (id) copyWithZone: (NSZone*) zone {
	ZoomPlugInInfo* newInfo = [[ZoomPlugInInfo allocWithZone: zone] init];
	
	newInfo->name = [name copy];
	newInfo->author = [author copy];
	newInfo->interpreterVersion = [interpreterVersion copy];
	newInfo->interpreterAuthor = [interpreterAuthor copy];
	newInfo->version = [version copy];
	newInfo->image = [image copy];
	newInfo->location = [location copy];
	newInfo->status = status;
	newInfo->updated = [updated copy];
}

// = Retrieving the information =

- (NSString*) name {
	return name;
}

- (NSString*) author {
	return author;
}

- (NSString*) version {
	return version;
}

- (NSString*) interpreterAuthor {
	return interpreterAuthor;
}

- (NSString*) interpreterVersion {
	return interpreterVersion;
}

- (NSString*) imagePath {
	return image;
}

- (ZoomPlugInStatus) status {
	return status;
}

- (void) setStatus: (ZoomPlugInStatus) newStatus {
	status = newStatus;
}

- (NSString*) description {
	return [NSString stringWithFormat: @"Plug in: %@, version %@", [self name], [self version]];
}

- (NSURL*) location {
	return location;
}

- (ZoomPlugInInfo*) updateInfo {
	return updated;
}

- (void) setUpdateInfo: (ZoomPlugInInfo*) info {
	[updated release];
	updated = [info copy];
}

- (ZoomDownload*) download {
	return updateDownload;
}

- (void) setDownload: (ZoomDownload*) download {
	[updateDownload release];
	updateDownload = [download retain];
}

@end
