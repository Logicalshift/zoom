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


@implementation ZoomClientController

- (id) init {
    self = [super initWithWindowNibName: @"ZoomClient"];

    if (self) {
        [self setShouldCloseDocument: YES];
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
    // Sheet is up here.
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
	}
}

- (IBAction) updateGameInfo: (id) sender {
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [[self document] storyInfo]];
}

- (void)windowDidResignMain:(NSNotification *)aNotification {
	[self recordGameInfo: self];
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
}

- (void)windowWillClose:(NSNotification *)aNotification {
	[self recordGameInfo: self];
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

@end
