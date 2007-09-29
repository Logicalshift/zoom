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
	newInfo->status = status;
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

@end
