//
//  ZoomPixmapWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomView.h"

@interface ZoomPixmapWindow : NSObject<ZPixmapWindow, NSCoding> {
	NSImage* pixmap;
	ZoomView* zView;
}

// Initialisation
- (id) initWithZoomView: (ZoomView*) view;

// Getting the pixmap
- (NSImage*) pixmap;

@end
