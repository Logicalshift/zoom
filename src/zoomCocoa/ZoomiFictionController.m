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
#import "ZoomClient.h"

#import "ifmetadata.h"

@implementation ZoomiFictionController

static ZoomiFictionController* sharedController = nil;

static NSString* addDirectory = @"ZoomiFictionControllerDefaultDirectory";

// = Setup/initialisation =

+ (ZoomiFictionController*) sharediFictionController {
	if (!sharedController) {
		NSString* nibName = @"iFiction";
		if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_2)
			nibName = @"iFiction-10.2";
		sharedController = [[ZoomiFictionController alloc] initWithWindowNibName: nibName];
	}
	
	return sharedController;
}

+ (void) initialize {
	// Create user defaults
	NSString* docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
		objectAtIndex: 0];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
		docDir, addDirectory, nil]];
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
	[infoButton setPushedImage: [NSImage imageNamed: @"information-in"]];		
	
	[continueButton setEnabled: NO];
	[newgameButton setEnabled: NO];
	
	[[self window] setFrameUsingName: @"iFiction"];
	[[self window] setExcludedFromWindowsMenu: YES];
	
	showDrawer = YES;
	needsUpdating = YES;
	
	sortColumn = [@"group" retain];
	
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

- (ZoomStory*) createStoryCopy: (ZoomStory*) theStory {
	// When editing story data, we need to work on a copy in the user metadata area.
	// By default, we just use the first version we find, which might be in one of the
	// files loaded from our own application (and hence won't get saved when we finish
	// up)
	if ([theStory story]->numberOfIdents <= 0) {
		NSLog(@"Story has no identification");
		
		return nil;
	}

	ZoomStoryID* theId = [[[ZoomStoryID alloc] initWithIdent: [theStory story]->idents[0]] autorelease];
	ZoomStory* newStory = [[[NSApp delegate] userMetadata] findStory: theId];
	if (newStory) return newStory;
	
	[[[NSApp delegate] userMetadata] storeStory: [[theStory copy] autorelease]];
	
	newStory = [[[NSApp delegate] userMetadata] findStory: theId];
	
	if (newStory) {
		needsUpdating = YES;
	} else {
		NSLog(@"Failed to create story copy");
	}
	
	return newStory;
}

// = Panel actions =

- (void) addFilesFromPanel: (NSOpenPanel *)sheet
				returnCode: (int)returnCode
			   contextInfo: (void *)contextInfo {
	if (returnCode != NSOKButton) return;

	NSArray* fileTypes = [NSArray arrayWithObjects: @"z3", @"z4", @"z5", @"z6", @"z7", @"z8", nil];
	
	// Store the defaults
	[[NSUserDefaults standardUserDefaults] setObject: [sheet directory]
											  forKey: addDirectory];
	
	// Add all the files we can
	NSMutableArray* selectedFiles = [[sheet filenames] mutableCopy];
	NSEnumerator* selFileEnum = [selectedFiles objectEnumerator];
	NSString* filename;
	
	while (filename = [selFileEnum nextObject]) {
		NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
		BOOL isDir;
		
		isDir = NO;
		[[NSFileManager defaultManager] fileExistsAtPath: filename
											 isDirectory: &isDir];
		
		NSString* fileType = [filename pathExtension];
		
		if (isDir) {
			NSArray* dirContents = [[NSFileManager defaultManager] directoryContentsAtPath: filename];
			
			NSEnumerator* dirContentsEnum = [dirContents objectEnumerator];
			NSString* dirComponent;
			
			while (dirComponent = [dirContentsEnum nextObject]) {
				if ([fileTypes containsObject: [dirComponent pathExtension]]) {
					[selectedFiles addObject: [filename stringByAppendingPathComponent: dirComponent]];
				}
			}
		} else if ([fileTypes containsObject: fileType]) {
			ZoomStoryID* fileID = [[ZoomStoryID alloc] initWithZCodeFile: filename];
			
			if (fileID != nil) {
				[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: filename
														  withIdent: fileID];
				
				[fileID release];
			}
		}
		
		[p release];
	}
	
	[selectedFiles release];
}

// = IB actions =

- (IBAction) addButtonPressed: (id) sender {
	// Create an open panel
	NSOpenPanel* storiesToAdd;
	NSArray* fileTypes = [NSArray arrayWithObjects: @"z3", @"z4", @"z5", @"z6", @"z7", @"z8", nil];
	
	storiesToAdd = [NSOpenPanel openPanel];
	
	[storiesToAdd setAllowsMultipleSelection: YES];
	[storiesToAdd setCanChooseDirectories: YES];
	[storiesToAdd setCanChooseFiles: YES];
	
	NSString* path = [[NSUserDefaults standardUserDefaults] objectForKey: addDirectory];
	
	[storiesToAdd beginSheetForDirectory: path
									file: nil
								   types: fileTypes
						  modalForWindow: [self window]
						   modalDelegate: self
						  didEndSelector: @selector(addFilesFromPanel:returnCode:contextInfo:)
							 contextInfo: nil];
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
		ZoomClient* newDoc = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: filename
																									display: NO];
		
		if ([[newDoc windowControllers] count] == 0) {
			[newDoc makeWindowControllers];
		}
		
		[newDoc loadDefaultAutosave];
		[[[newDoc windowControllers] objectAtIndex: 0] showWindow: self];
		
		[self configureFromMainTableSelection];
	}
}

- (IBAction) searchFieldChanged: (id) sender {
	[self reloadTableData]; [mainTableView reloadData];
}

- (IBAction) changeFilter: (id) sender {
	NSString* filterName = [ZoomStory keyForTag: [sender tag]];
	
	NSString* filterTitle = [ZoomStory nameForKey: filterName];
	
	if (!filterName || !filterTitle) {
		return;
	}
	
	// For the moment, we only change the filter of the first filter table
	// Need to find a way of discovering which table the user brought the menu up
	// for (preferably without using a duplicate menu)
	NSTableColumn* filterColumn = [[filterTable1 tableColumns] objectAtIndex: 0];

	[filterColumn setIdentifier: filterName];
	[[filterColumn headerCell] setStringValue: filterTitle];
	
	[filterTable1 selectRow: 0 byExtendingSelection: NO];
	[filterTable2 selectRow: 0 byExtendingSelection: NO];
	
	[self reloadTableData]; [mainTableView reloadData];
}

// = Notifications =
- (void) storyListChanged: (NSNotification*) not {
	needsUpdating = YES;
	
	[mainTableView reloadData];
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

		// If we ever support more formats (Z-Code blorb is probable, GLULX is likely, other are possible)
		// we need to do this in a more intelligent way.
		[story addID: [[[ZoomStoryID alloc] initWithZCodeFile: filename] autorelease]];
	}
	
	return story;
}

- (int) compareRow: (ZoomStoryID*) a
		   withRow: (ZoomStoryID*) b {
	ZoomStory* sA = [self storyForID: a];
	ZoomStory* sB = [self storyForID: b];
	
	NSString* cA = [sA objectForKey: sortColumn];
	NSString* cB = [sB objectForKey: sortColumn];

	if ([cA length] != [cB length]) {
		if ([cA length] == 0) return 1;
		if ([cB length] == 0) return -1;
	}
	
	int res = [cA caseInsensitiveCompare: cB];
	
	if (res == 0) {
		return [[sA title] caseInsensitiveCompare: [sB title]];
	} else {
		return res;
	}
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

- (void) filterTableDataPass1 {
	// Filter using the selection from the first filter table
	NSString* filterKey = [[[filterTable1 tableColumns] objectAtIndex: 0] identifier];
	
	// Get the selected items from the first filter table
	NSMutableSet* filterFor = [NSMutableSet set];
	NSEnumerator* selEnum = [filterTable1 selectedRowEnumerator];
	NSNumber* selRow;
	
	while (selRow = [selEnum nextObject]) {
		if ([selRow intValue] == 0) {
			// All selected - no filtering
			[filterTable1 selectRow: 0 byExtendingSelection: NO];
			return;
		}
		
		[filterFor addObject: [filterSet1 objectAtIndex: [selRow intValue]-1]];
	}
	
	// Remove anything that doesn't match the filter
	int num;
	
	for (num = 0; num < [storyList count]; num++) {
		ZoomStoryID* ident = [storyList objectAtIndex: num];
		
		ZoomStory* thisStory = [self storyForID: ident];
		NSString* storyKey = [thisStory objectForKey: filterKey];
		
		if (![filterFor containsObject: storyKey]) {
			[storyList removeObjectAtIndex: num];
			num--;
		}
	}
}

- (void) filterTableDataPass2 {
	// Filter using the selection from the second filter table
	NSString* filterKey = [[[filterTable2 tableColumns] objectAtIndex: 0] identifier];
	
	// Get the selected items from the first filter table
	NSMutableSet* filterFor = [NSMutableSet set];
	NSEnumerator* selEnum = [filterTable2 selectedRowEnumerator];
	NSNumber* selRow;
	
	BOOL tableFilter;
	
	tableFilter = YES;
	while (selRow = [selEnum nextObject]) {
		if ([selRow intValue] == 0) {
			// All selected - no filtering
			[filterTable2 selectRow: 0 byExtendingSelection: NO];
			tableFilter = NO;
			break;
		}
		
		[filterFor addObject: [filterSet2 objectAtIndex: [selRow intValue]-1]];
	}
	
	// Remove anything that doesn't match the filter (second filter table *or* the search field)
	int num;
	NSString* searchText = [searchField stringValue];
	
	if (!tableFilter && [searchText length] <= 0) return; // Nothing to do
		
	for (num = 0; num < [storyList count]; num++) {
		ZoomStoryID* ident = [storyList objectAtIndex: num];
		
		ZoomStory* thisStory = [self storyForID: ident];
		
		// Filter table
		NSString* storyKey = [thisStory objectForKey: filterKey];
		
		if (tableFilter && ![filterFor containsObject: storyKey]) {
			[storyList removeObjectAtIndex: num];
			num--;
			continue;
		}
		
		// Search field
		if ([searchText length] > 0) {
			if (![thisStory containsText: searchText]) {
				[storyList removeObjectAtIndex: num];
				num--;
				continue;				
			}
		}
	}
}

- (void) filterTableData {
	[self filterTableDataPass1];
	[self filterTableDataPass2];
}

- (void) reloadTableData {
	ZoomStoryOrganiser* org = [ZoomStoryOrganiser sharedStoryOrganiser];
	
	needsUpdating = NO;
	
	// Store the previous list of selected IDs
	NSMutableArray* previousIDs = [NSMutableArray array];
	NSEnumerator* selEnum = [mainTableView selectedRowEnumerator];
	NSNumber* selRow;
	
	while (selRow = [selEnum nextObject]) {
		[previousIDs addObject: [storyList objectAtIndex: [selRow intValue]]];
	}

	// Free up the previous table data
	[storyList release];
	storyList = [[NSMutableArray alloc] init];
	
	[filterSet1 release]; [filterSet2 release];
	
	filterSet1 = [[NSMutableArray alloc] init];
	filterSet2 = [[NSMutableArray alloc] init];
	
	// Repopulate the table
	NSEnumerator* identEnum = [[org storyIdents] objectEnumerator];
	ZoomStoryID* ident;
	
	NSString* filterKey1 = [[[filterTable1 tableColumns] objectAtIndex: 0] identifier];
	NSString* filterKey2 = [[[filterTable2 tableColumns] objectAtIndex: 0] identifier];
	
	while (ident = [identEnum nextObject]) {
		ZoomStory* thisStory = [self storyForID: ident];
		
		[storyList addObject: ident];
		
		NSString* filterItem1 = [thisStory objectForKey: filterKey1];
		
		if ([filterItem1 length] != 0 && [filterSet1 indexOfObject: filterItem1] == NSNotFound) [filterSet1 addObject: filterItem1];
	}
	
	// Sort the first filter set
	[filterSet1 sortUsingSelector: @selector(caseInsensitiveCompare:)];
	[filterTable1 reloadData];
	
	// Filter the table as required
	[self filterTableDataPass1];
	
	// Generate + sort the second filter set
	identEnum = [storyList objectEnumerator];
	
	while (ident = [identEnum nextObject]) {
		ZoomStory* thisStory = [self storyForID: ident];
		NSString* filterItem2 = [thisStory objectForKey: filterKey2];		
		if ([filterItem2 length] != 0 && [filterSet2 indexOfObject: filterItem2] == NSNotFound) [filterSet2 addObject: filterItem2];
	}
	
	[filterSet2 sortUsingSelector: @selector(caseInsensitiveCompare:)];
	[filterTable2 reloadData];	

	// Continue filtering
	[self filterTableDataPass2];

	// Sort the table as required
	[self sortTableData];

	// Joogle the selection
	[mainTableView deselectAll: self];
	selEnum = [previousIDs objectEnumerator];
	
	ZoomStoryID* selID;
	
	while (selID = [selEnum nextObject]) {
		unsigned index = [storyList indexOfObject: selID];
		
		if (index != NSNotFound) {
			[mainTableView selectRow: index
				byExtendingSelection: YES];
		}
	}
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	if (needsUpdating) [self reloadTableData];
	
	if (aTableView == mainTableView) {
		return [storyList count];
	} else if (aTableView == filterTable1) {
		return [filterSet1 count]+1;
	} else if (aTableView == filterTable2) {
		return [filterSet2 count]+1;
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
	} else if (aTableView == filterTable1) {
		if (rowIndex == 0) return [NSString stringWithFormat: @"All (%i items)", [filterSet1 count]];
		return [filterSet1 objectAtIndex: rowIndex-1];
	} else if (aTableView == filterTable2) {
		if (rowIndex == 0) return [NSString stringWithFormat: @"All (%i items)", [filterSet2 count]];
		return [filterSet2 objectAtIndex: rowIndex-1];
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
			
			//[self sortTableData];
			[self reloadTableData];
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
			
			NSString* autosaveDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: ident];
			NSString* autosaveFile = [autosaveDir stringByAppendingPathComponent: @"autosave.zoomauto"];

			if ([[NSFileManager defaultManager] fileExistsAtPath: autosaveFile]) {
				// Can restore an autosave
				[continueButton setEnabled: YES];
			}
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
	} else if (tableView == filterTable1 || tableView == filterTable2) {
		if (tableView == filterTable1) {
			[filterTable2 selectRow: 0 byExtendingSelection: NO];
		}
		
		[self reloadTableData]; [mainTableView reloadData];
	} else {
		// Zzzz
	}
}

- (void)tableView:(NSTableView *)tableView 
   setObjectValue:(id)anObject 
   forTableColumn:(NSTableColumn*)aTableColumn 
			  row:(int)rowIndex {
	if (needsUpdating) [self reloadTableData];

	if (tableView == mainTableView) {
		ZoomStoryID* ident = [storyList objectAtIndex: [mainTableView selectedRow]];
		ZoomStory* story = [self storyForID: ident];
		
		story = [self createStoryCopy: story];
		
		[story setObject: anObject
				  forKey: [aTableColumn identifier]];
	}

	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) updateGameInfo: (id) sender {
	[self configureFromMainTableSelection];
}

// = GameInfo window actions =

- (IBAction) infoNameChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setTitle: [[ZoomGameInfoController sharedGameInfoController] title]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoHeadlineChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setHeadline: [[ZoomGameInfoController sharedGameInfoController] headline]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoAuthorChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setAuthor: [[ZoomGameInfoController sharedGameInfoController] author]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoGenreChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setGenre: [[ZoomGameInfoController sharedGameInfoController] genre]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoYearChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setYear: [[ZoomGameInfoController sharedGameInfoController] year]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoGroupChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setGroup: [[ZoomGameInfoController sharedGameInfoController] group]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoCommentsChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setComment: [[ZoomGameInfoController sharedGameInfoController] comments]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoTeaserChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setTeaser: [[ZoomGameInfoController sharedGameInfoController] teaser]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoZarfRatingChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setZarfian: [[ZoomGameInfoController sharedGameInfoController] zarfRating]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoMyRatingChanged: (id) sender {
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setRating: [[ZoomGameInfoController sharedGameInfoController] rating]];
	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];
}

// = NSText delegate =

- (void)textDidEndEditing:(NSNotification *)aNotification {
	NSTextView* textView = [aNotification object];

	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	
	if (textView == commentView) {
		[story setComment: [commentView string]];
	} else if (textView == teaserView) {
		[story setTeaser: [teaserView string]];
	} else {
		NSLog(@"Unknown text view");
	}

	[self reloadTableData]; [mainTableView reloadData];
	[[[NSApp delegate] userMetadata] writeToDefaultFile];		
}

@end
