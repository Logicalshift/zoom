//
//  ZoomiFictionController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomiFButton.h"
#import "ZoomStory.h"
#import "ZoomCollapsableView.h"
#import "ZoomSavePreviewView.h"

@interface ZoomiFictionController : NSWindowController {
	IBOutlet ZoomiFButton* addButton;
	IBOutlet ZoomiFButton* newgameButton;
	IBOutlet ZoomiFButton* continueButton;	
	IBOutlet ZoomiFButton* drawerButton;
	IBOutlet ZoomiFButton* infoButton;
	
	IBOutlet ZoomCollapsableView* collapseView;
	
	NSTextView*   commentView;
	NSTextView*   teaserView;
	
	IBOutlet NSDrawer* drawer;
	IBOutlet NSView*   drawerView;
	
	IBOutlet NSTableView* mainTableView;
	IBOutlet NSTableView* filterTable1;
	IBOutlet NSTableView* filterTable2;
	
	IBOutlet NSTextField* searchField;
	
	IBOutlet NSMenu* storyMenu;
	IBOutlet NSMenu* saveMenu;
	
	BOOL showDrawer;
	
	BOOL needsUpdating;
	
	BOOL queuedUpdate;
	
	// Save game previews
	ZoomSavePreviewView* previewView;
	
	// Data source information
	NSMutableArray* filterSet1;
	NSMutableArray* filterSet2;
	
	NSMutableArray* storyList;
	NSString*       sortColumn;
}

+ (ZoomiFictionController*) sharediFictionController;

- (IBAction) addButtonPressed: (id) sender;
- (IBAction) drawerButtonPressed: (id) sender;
- (IBAction) startNewGame: (id) sender;
- (IBAction) restoreAutosave: (id) sender;
- (IBAction) searchFieldChanged: (id) sender;
- (IBAction) changeFilter1: (id) sender;
- (IBAction) changeFilter2: (id) sender;
- (IBAction) deleteSavegame: (id) sender;

- (ZoomStory*) storyForID: (ZoomStoryID*) ident;
- (void) configureFromMainTableSelection;
- (void) reloadTableData;

- (void) mergeiFictionFromFile: (NSString*) filename;

@end
