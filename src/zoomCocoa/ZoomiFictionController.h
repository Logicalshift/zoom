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
#import "ZoomCollapsingSplitView.h"
#import "ZoomResourceDrop.h"
#import "ZoomStoryTableView.h"
#import "ZoomMetadata.h"
#import "ZoomFlipView.h"

@interface ZoomiFictionController : NSWindowController {
	IBOutlet ZoomiFButton* addButton;
	IBOutlet ZoomiFButton* newgameButton;
	IBOutlet ZoomiFButton* continueButton;	
	// IBOutlet ZoomiFButton* drawerButton;
	IBOutlet ZoomiFButton* infoButton;
	
	//IBOutlet ZoomCollapsableView* collapseView;
	
	IBOutlet ZoomFlipView* flipView;
	IBOutlet NSView* topPanelView;
	IBOutlet NSView* filterView;
	IBOutlet NSView* infoView;
	IBOutlet NSView* saveGameView;
	IBOutlet NSMatrix* flipButtonMatrix;

	IBOutlet NSWindow* picturePreview;
	IBOutlet NSImageView* picturePreviewView;
	
	IBOutlet NSProgressIndicator* progressIndicator;
	int indicatorCount;
	
	IBOutlet NSTextView* gameDetailView;
	IBOutlet NSImageView* gameImageView;
	
	//NSTextView*   commentView;
	//NSTextView*   teaserView;
	//NSTextView*	  descriptionView;
	
	//NSImageView*  pictureView;
	
	//IBOutlet NSDrawer* drawer;
	//IBOutlet NSView*   drawerView;

	IBOutlet ZoomCollapsingSplitView* splitView;

	float splitViewPercentage;
	BOOL splitViewCollapsed;
	
	IBOutlet ZoomStoryTableView* mainTableView;
	IBOutlet NSTableView* filterTable1;
	IBOutlet NSTableView* filterTable2;
	
	IBOutlet NSTextField* searchField;
	
	IBOutlet NSMenu* storyMenu;
	IBOutlet NSMenu* saveMenu;
	
	BOOL showDrawer;
	
	BOOL needsUpdating;
	
	BOOL queuedUpdate;
	BOOL isFiltered;
	BOOL saveGamesAvailable;
	
	// Save game previews
	IBOutlet ZoomSavePreviewView* previewView;
	
	// Resource drop zone
	ZoomResourceDrop* resourceDrop;
	
	// Data source information
	NSMutableArray* filterSet1;
	NSMutableArray* filterSet2;
	
	NSMutableArray* storyList;
	NSString*       sortColumn;
}

+ (ZoomiFictionController*) sharediFictionController;

- (IBAction) addButtonPressed: (id) sender;
- (IBAction) startNewGame: (id) sender;
- (IBAction) restoreAutosave: (id) sender;
- (IBAction) searchFieldChanged: (id) sender;
- (IBAction) changeFilter1: (id) sender;
- (IBAction) changeFilter2: (id) sender;
- (IBAction) deleteSavegame: (id) sender;

- (IBAction) flipToFilter: (id) sender;
- (IBAction) flipToInfo: (id) sender;
- (IBAction) flipToSaves: (id) sender;

- (ZoomStory*) storyForID: (ZoomStoryID*) ident;
- (void) configureFromMainTableSelection;
- (void) reloadTableData;

- (void) mergeiFictionFromFile: (NSString*) filename;
- (NSArray*) mergeiFictionFromMetabase: (ZoomMetadata*) newData;

- (void) addFiles: (NSArray *)filenames;

- (void) setupSplitView;
- (void) collapseSplitView;

@end
