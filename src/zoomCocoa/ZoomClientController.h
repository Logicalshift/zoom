//
//  ZoomClientController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomView.h"
#import "ZoomClient.h"


@interface ZoomClientController : NSWindowController {
    IBOutlet ZoomView* zoomView;
	BOOL isFullscreen;
	BOOL finished;
	BOOL closeConfirmed;
	
	NSRect oldWindowFrame;
}

- (IBAction) recordGameInfo: (id) sender;
- (IBAction) updateGameInfo: (id) sender;

- (IBAction) playInFullScreen: (id) sender;

- (ZoomView*) zoomView;

@end
