//
//  ZoomResourceDrop.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 28 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface ZoomResourceDrop : NSView {
	NSString* droppedFilename;
	NSData*   droppedData;
	
	int willOrganise;
	BOOL enabled;
}

- (void) setWillOrganise: (BOOL) willOrganise;
- (BOOL) willOrganise;

- (void) setEnabled: (BOOL) enabled;
- (BOOL) enabled;

@end
