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
	IBOutlet ZoomiFButton* newgameButton;
	IBOutlet ZoomiFButton* continueButton;	
	IBOutlet ZoomiFButton* drawerButton;
	
	IBOutlet NSTextView*   commentView;
	IBOutlet NSTextView*   teaserView;
	
	IBOutlet NSDrawer* drawer;
	IBOutlet NSView*   drawerView;
	
	IBOutlet NSTableView* mainTableView;
	IBOutlet NSTableView* filterTable1;
	IBOutlet NSTableView* filterTable2;
	
	BOOL showDrawer;
	
	BOOL needsUpdating;
	
	// Data source information
	NSSet* filterSet1;
	NSSet* filterSet2;
	
	NSMutableArray* storyList;
	NSString*       sortColumn;
}

+ (ZoomiFictionController*) sharediFictionController;

- (IBAction) addButtonPressed: (id) sender;
- (IBAction) drawerButtonPressed: (id) sender;

- (void) configureFromMainTableSelection;

@end
