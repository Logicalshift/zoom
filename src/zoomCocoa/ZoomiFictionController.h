//
//  ZoomiFictionController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomiFButton.h"

@interface ZoomiFictionController : NSWindowController {
	IBOutlet ZoomiFButton* addButton;
	IBOutlet ZoomiFButton* drawerButton;
	
	IBOutlet NSDrawer* drawer;
	IBOutlet NSView*   drawerView;
}

+ (ZoomiFictionController*) sharediFictionController;

- (IBAction) addButtonPressed: (id) sender;
- (IBAction) drawerButtonPressed: (id) sender;

@end
