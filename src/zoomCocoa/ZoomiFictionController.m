//
//  ZoomiFictionController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomiFictionController.h"
#import "ZoomStoryOrganiser.h"
#import "ZoomStory.h"
#import "ZoomStoryID.h"
#import "ZoomAppDelegate.h"
#import "ZoomGameInfoController.h"

@implementation ZoomiFictionController

static ZoomiFictionController* sharedController = nil;

// = Setup/initialisation =

+ (ZoomiFictionController*) sharediFictionController {
	if (!sharedController) {
		sharedController = [[ZoomiFictionController alloc] initWithWindowNibName: @"iFiction"];
	}
	
	return sharedController;
}

- (void) dealloc {
	[storyList release];
	[sortColumn release];
	[filterSet1 release]; [filterSet2 release];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super dealloc];
}

- (void) windowDidLoad {
	[addButton setPushedImage: [NSImage imageNamed: @"add-in"]];
	[newgameButton setPushedImage: [NSImage imageNamed: @"newgame-in"]];
	[continueButton setPushedImage: [NSImage imageNamed: @"continue-in"]];
	[drawerButton setPushedImage: [NSImage imageNamed: @"drawer-in"]];		
	
	[continueButton setEnabled: NO];
	[newgameButton setEnabled: NO];
	
	[[self window] setFrameUsingName: @"iFiction"];
	[[self window] setExcludedFromWindowsMenu: YES];
	
	showDrawer = YES;
	needsUpdating = YES;
	
	sortColumn = nil;
	
	[mainTableView setAllowsColumnSelection: NO];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(storyListChanged:)
												 name: ZoomStoryOrganiserChangedNotification
											   object: [ZoomStoryOrganiser sharedStoryOrganiser]];
	
	[self configureFromMainTableSelection];
	[mainTableView reloadData];
}

- (void) close {
	[[self window] orderOut: self];
	[[self window] saveFrameUsingName: @"iFiction"];
}

- (void)windowDidMove:(NSNotification *)aNotification {
	[[self window] saveFrameUsingName: @"iFiction"];
}

// = Useful functions for getting info about the table =
- (ZoomStoryID*) selectedStoryID {
	if (needsUpdating) [self reloadTableData];
	
	if ([mainTableView numberOfSelectedRows] == 1) {
		ZoomStoryID* ident = [storyList objectAtIndex: [mainTableView selectedRow]];
		
		return ident;
	}
	
	return nil;
}

- (ZoomStory*) selectedStory {
	ZoomStoryID* ident = [self selectedStoryID];
	
	if (ident != nil) {
		return [self storyForID: ident];
	}
	
	return nil;
}

- (NSString*) selectedFilename {
	ZoomStoryID* ident = [self selectedStoryID];
	
	if (ident != nil) {
		return [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: ident];
	}
	
	return nil;
}
   
// = IB actions =

- (IBAction) addButtonPressed: (id) sender {
}

- (IBAction) drawerButtonPressed: (id) sender {
	[drawer toggle: self];
	
	if ([drawer state] == NSDrawerClosedState ||
		[drawer state] == NSDrawerClosingState) {
		showDrawer = NO;
	} else {
		showDrawer = YES;
	}
}

- (IBAction) startNewGame: (id) sender {
	NSString* filename = [self selectedFilename];
	
	// FIXME: multiple selections?
	if (filename) {
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: filename
																				display: YES];
		
		[self configureFromMainTableSelection];
	}
}

- (IBAction) restoreAutosave: (id) sender {
	NSString* filename = [self selectedFilename];
	
	// FIXME: multiple selections?, actually save/restore autosaves
	if (filename) {
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: filename
																				display: YES];
		
		[self configureFromMainTableSelection];
	}
}

// = Notifications =
- (void) storyListChanged: (NSNotification*) not {
	needsUpdating = YES;
	
	[mainTableView reloadData];
	[filterTable1 reloadData];
	[filterTable2 reloadData];	
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification {
	[self configureFromMainTableSelection];
}

// = Our life as a data source =
- (ZoomStory*) storyForID: (ZoomStoryID*) ident {
	ZoomStoryOrganiser* org = [ZoomStoryOrganiser sharedStoryOrganiser];
	
	NSString* filename = [org filenameForIdent: ident];
	ZoomStory* story = [[NSApp delegate] findStory: ident];
	
	if (filename == nil) filename = @"No filename";
	
	if (story == nil) {
		story = [[[ZoomStory alloc] init] autorelease];
		[story setTitle: [[filename lastPathComponent] stringByDeletingPathExtension]];
	}
	
	return story;
}

- (int) compareRow: (ZoomStoryID*) a
		   withRow: (ZoomStoryID*) b {
	ZoomStory* sA = [self storyForID: a];
	ZoomStory* sB = [self storyForID: b];
	
	NSString* cA = [sA objectForKey: sortColumn];
	NSString* cB = [sB objectForKey: sortColumn];
	
	return [cA caseInsensitiveCompare: cB];
}

int tableSorter(id a, id b, void* context) {
	ZoomiFictionController* us = context;
	
	return [us compareRow: a withRow: b];
}

- (void) sortTableData {
	if (sortColumn != nil) {
		[storyList sortUsingFunction: tableSorter
							 context: self];
	}
}

- (void) filterTableData {
	// IMPLEMENT ME
}

- (void) reloadTableData {
	ZoomStoryOrganiser* org = [ZoomStoryOrganiser sharedStoryOrganiser];

	[storyList release];
	storyList = [[NSMutableArray alloc] init];
	
	[filterSet1 release]; [filterSet2 release];
	
	NSEnumerator* identEnum = [[org storyIdents] objectEnumerator];
	ZoomStoryID* ident;
	
	while (ident = [identEnum nextObject]) {
		[storyList addObject: ident];
		
		// IMPLEMENT ME: add to the filterSets
	}
	
	[self sortTableData];
	
	needsUpdating = NO;
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	if (needsUpdating) [self reloadTableData];
	
	if (aTableView == mainTableView) {
		return [storyList count];
	} else {
		return 0; // Unknown table view
	}
}

- (id)				tableView: (NSTableView *) aTableView 
	objectValueForTableColumn: (NSTableColumn *) aTableColumn 
						  row: (int) rowIndex {
	if (needsUpdating) [self reloadTableData];

	if (aTableView == mainTableView) {
		// Retrieve row details
		NSString* rowID = [aTableColumn identifier];
		
		ZoomStoryID* ident = [storyList objectAtIndex: rowIndex];
		ZoomStory* story = [self storyForID: ident];		
		
		// Return the value of the appropriate field
		return [story objectForKey: rowID];
	} else {
		return nil; // Unknown table view
	}
}

- (void)				tableView:(NSTableView *)tableView 
   mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn {
	if (tableView == mainTableView) {
		NSString* columnID = [tableColumn identifier];
		
		if (sortColumn == nil || ![sortColumn isEqualToString: columnID]) {
			[mainTableView setHighlightedTableColumn: tableColumn];
			[sortColumn release];
			sortColumn = [columnID copy];
			
			[self sortTableData];
			[mainTableView reloadData];
		}
	}
}

- (void) configureFromMainTableSelection {
	ZoomStoryOrganiser* org = [ZoomStoryOrganiser sharedStoryOrganiser];

	if (needsUpdating) [self reloadTableData];

	// selectedRowEnumerator is deprecated, but we want to support 10.2, where it doesn't exist
	NSEnumerator* rowEnum = [mainTableView selectedRowEnumerator];
	int numSelected = 0;
	
	NSNumber* row;
	
	[continueButton setEnabled: NO];
	[newgameButton setEnabled: NO];
	
	while (row = [rowEnum nextObject]) {
		numSelected++;
		
		ZoomStoryID* ident = [storyList objectAtIndex: [row intValue]];
		NSString* filename = [org filenameForIdent: ident];
		
		if ([[NSDocumentController sharedDocumentController] documentForFileName: filename] != nil) {
			[continueButton setEnabled: YES];
		} else {
			[newgameButton setEnabled: YES];
		}
	}
	
	NSString* comment;
	NSString* teaser;
	
	if (numSelected == 1) {
		ZoomStoryID* ident = [storyList objectAtIndex: [mainTableView selectedRow]];
		ZoomStory* story = [self storyForID: ident];

		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: story];

		comment = [story comment];
		teaser = [story teaser];
		
		[drawerButton setEnabled: YES];
	} else {
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
		
		comment = @"";
		teaser = @"";

		[drawerButton setEnabled: NO];
	}
	
	if (comment == nil) comment = @"";
	if (teaser == nil) teaser = @"";
	
	[commentView setString: comment];
	[teaserView setString: teaser];
	
	if ([comment length] == 0 && [teaser length] == 0) {
		[drawer close];
	} else if (showDrawer) {
		[drawer open];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	NSTableView* tableView = [aNotification object];
	
	if (tableView == mainTableView) {
		[self configureFromMainTableSelection];
	} else {
		// IMPLEMENT ME: the filtering tables
	}
}

- (IBAction) updateGameInfo: (id) sender {
	[self configureFromMainTableSelection];
}

@end
