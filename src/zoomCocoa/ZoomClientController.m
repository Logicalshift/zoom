//
//  ZoomClientController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomClientController.h"
#import "ZoomPreferenceWindow.h"
#import "ZoomGameInfoController.h"
#import "ZoomStoryOrganiser.h"

#import "ZoomAppDelegate.h"

@implementation ZoomClientController

- (id) init {
    self = [super initWithWindowNibName: @"ZoomClient"];

    if (self) {
        [self setShouldCloseDocument: YES];
		isFullscreen = NO;
    }

    return self;
}

- (void) dealloc {
    if (zoomView) [zoomView setDelegate: nil];
    if (zoomView) [zoomView killTask];
    
    [super dealloc];
}

- (void) windowDidLoad {
    [zoomView runNewServer: nil];
    [zoomView setDelegate: self];
}

- (void) zMachineStarted: (id) sender {
    [[zoomView zMachine] loadStoryFile: [[self document] gameData]];
	
	if ([[self document] autosaveData] != nil) {
		NSUnarchiver* decoder;
		
		decoder = [[NSUnarchiver alloc] initForReadingWithData: [[self document] autosaveData]];
		
		[zoomView restoreAutosaveFromCoder: decoder];
		
		[decoder release];
		[[self document] setAutosaveData: nil];
	}
}

- (void) zMachineFinished: (id) sender {
	[[self window] setTitle: [NSString stringWithFormat: @"%@ (finished)", [[self window] title]]];
	
	if (isFullscreen) [self playInFullScreen: self];
}

- (void) showGamePreferences: (id) sender {
	ZoomPreferenceWindow* gamePrefs;
	
	gamePrefs = [[ZoomPreferenceWindow alloc] init];
	
	[NSApp beginSheet: [gamePrefs window]
	   modalForWindow: [self window]
		modalDelegate: nil
	   didEndSelector: nil
		  contextInfo: nil];
    [NSApp runModalForWindow: [gamePrefs window]];
    [NSApp endSheet: [gamePrefs window]];
	
	[[gamePrefs window] orderOut: self];
	[gamePrefs release];
}

// = Setting up the game info window =

- (IBAction) recordGameInfo: (id) sender {
	ZoomGameInfoController* sgI = [ZoomGameInfoController sharedGameInfoController];
	ZoomStory* storyInfo = [[self document] storyInfo];

	if ([sgI gameInfo] == storyInfo) {
		[storyInfo setTitle: [sgI title]];
		[storyInfo setHeadline: [sgI headline]];
		[storyInfo setAuthor: [sgI author]];
		[storyInfo setGenre: [sgI genre]];
		[storyInfo setYear: [sgI year]];
		[storyInfo setGroup: [sgI group]];
		[storyInfo setComment: [sgI comments]];
		[storyInfo setTeaser: [sgI teaser]];
		[storyInfo setZarfian: [sgI zarfRating]];
		[storyInfo setRating: [sgI rating]];
		
		[[[NSApp delegate] userMetadata] writeToDefaultFile];
	}
}

- (IBAction) updateGameInfo: (id) sender {
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [[self document] storyInfo]];
}

- (void)windowDidResignMain:(NSNotification *)aNotification {
	if (isFullscreen) {
		[self playInFullScreen: self];
	}
	
	[self recordGameInfo: self];
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
}

- (BOOL) windowShouldClose: (id) sender {	
	// Record any game information
	[self recordGameInfo: self];
	
	// Record autosave data
	NSMutableData* autosaveData = [[NSMutableData alloc] init];
	NSArchiver* theCoder = [[NSArchiver alloc] initForWritingWithMutableData: autosaveData];
	
	BOOL autosave = [zoomView createAutosaveDataWithCoder: theCoder];
	
	[theCoder release];
	
	NSString* autosaveDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: [[self document] storyId]];
	NSString* autosaveFile = [autosaveDir stringByAppendingPathComponent: @"autosave.zoomauto"];
	
	if (autosave) {
		// Produce an autosave file
		[autosaveData writeToFile: autosaveFile atomically: YES];
	} else {
		if ([[NSFileManager defaultManager] fileExistsAtPath: autosaveFile]) {
			[[NSFileManager defaultManager] removeFileAtPath: autosaveFile
													 handler: nil];
		}
	}
	
	[autosaveData release];
	
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification {
	// Can't do stuff here: [self document] has been set to nil
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification {
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [[self document] storyInfo]];
}

// = GameInfo updates =

- (IBAction) infoNameChanged: (id) sender {
	[[[self document] storyInfo] setTitle: [[ZoomGameInfoController sharedGameInfoController] title]];
}

- (IBAction) infoHeadlineChanged: (id) sender {
	[[[self document] storyInfo] setHeadline: [[ZoomGameInfoController sharedGameInfoController] headline]];
}

- (IBAction) infoAuthorChanged: (id) sender {
	[[[self document] storyInfo] setAuthor: [[ZoomGameInfoController sharedGameInfoController] author]];
}

- (IBAction) infoGenreChanged: (id) sender {
	[[[self document] storyInfo] setGenre: [[ZoomGameInfoController sharedGameInfoController] genre]];
}

- (IBAction) infoYearChanged: (id) sender {
	[[[self document] storyInfo] setYear: [[ZoomGameInfoController sharedGameInfoController] year]];
}

- (IBAction) infoGroupChanged: (id) sender {
	[[[self document] storyInfo] setGroup: [[ZoomGameInfoController sharedGameInfoController] group]];
}

- (IBAction) infoCommentsChanged: (id) sender {
	[[[self document] storyInfo] setComment: [[ZoomGameInfoController sharedGameInfoController] comments]];
}

- (IBAction) infoTeaserChanged: (id) sender {
	[[[self document] storyInfo] setTeaser: [[ZoomGameInfoController sharedGameInfoController] teaser]];
}

- (IBAction) infoZarfRatingChanged: (id) sender {
	[[[self document] storyInfo] setZarfian: [[ZoomGameInfoController sharedGameInfoController] zarfRating]];
}

- (IBAction) infoMyRatingChanged: (id) sender {
	[[[self document] storyInfo] setRating: [[ZoomGameInfoController sharedGameInfoController] rating]];
}

// = Various IB actions =

- (IBAction) playInFullScreen: (id) sender {
	if (isFullscreen) {
		// Show the menubar
		[NSMenu setMenuBarVisible: YES];

		// Stop being fullscreen
		[zoomView retain];
		[zoomView removeFromSuperview];
		
		[[self window] setFrame: oldWindowFrame
						display: YES
						animate: YES];
		[[self window] setShowsResizeIndicator: YES];
		
		[zoomView setScaleFactor: 1.0];
		[zoomView setFrame: [[[self window] contentView] bounds]];
		[[[self window] contentView] addSubview: zoomView];
		[zoomView release];
		
		isFullscreen = NO;
	} else {
		// Start being fullscreen
		[[self window] makeKeyAndOrderFront: self];
		oldWindowFrame = [[self window] frame];
		
		// Finish off zoomView
		NSSize oldZoomViewSize = [zoomView frame].size;
		
		[zoomView retain];
		[zoomView removeFromSuperviewWithoutNeedingDisplay];
		
		// Resize the window
		NSRect frame = [[[self window] screen] frame];
		[[self window] setShowsResizeIndicator: NO];
		frame = [NSWindow frameRectForContentRect: frame
										styleMask: [[self window] styleMask]];
		[[self window] setFrame: frame
						display: YES
						animate: YES];
		
		// Hide the menubar
		[NSMenu setMenuBarVisible: NO];
		
		// Resize, reposition the zoomView
		NSRect newZoomViewFrame = [[[self window] contentView] bounds];
		NSRect newZoomViewBounds;
		
		newZoomViewBounds.origin = NSMakePoint(0,0);
		newZoomViewBounds.size   = newZoomViewFrame.size;
		
		double ratio = oldZoomViewSize.width/newZoomViewFrame.size.width;
		[zoomView setFrame: newZoomViewFrame];
		[zoomView setScaleFactor: ratio];
		
		// Add it back in again
		[[[self window] contentView] addSubview: zoomView];
		[zoomView release];
		
		isFullscreen = YES;
	}
}

@end
