//
//  ZoomClient.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomClient.h"
#import "ZoomProtocol.h"
#import "ZoomClientController.h"
#import "ZoomStoryOrganiser.h"

#import "ZoomAppDelegate.h"

// This deserves a note by itself: the autosave system is a bit weird. Strange bits are
// handled by strange objects for strange reasons. This is because we have:
//
//   zMachine (Model, runs in a seperate process)
//   ZoomClient (Also a model)
//   ZoomClientController (Controller)
//   ZoomView (View)
//
// These are used like this:
//
//     ZoomClient -> ZoomClientController -> ZoomView
//                                              |
//                                              v
//											 zMachine (Look, ma, I broke the paradigm!)
//
// But autosave state is distributed across all of them. So things that save stuff are
// kind of distributed, too.
//
// The zMachine is simple: we just derive save state from there: same as an undo buffer
// (which in Zoom is the same as a save file). We need the display state from the ZoomView.
// Technically, y'see, ZoomClient doesn't represent a running ZMachine: that's associated
// with the ZoomView (ZoomView has to be self-contained). So, we have an encoder there.
// The actual saving is done by ZoomClientController: ZoomClient represents a game, but
// ZoomClientController represents a session with a game, and the autosave data is
// associated with a session. Anyway, we save at the same time we store the data in the
// game info window, as that's the opportune moment.
//
// Loading has even more hair: we load the autosave data into the ZoomClient, so the
// ZoomClientController can pick it up and ask ZoomView to do the actual work of loading.
// (Actually, this is just saving in reverse, but with now with the involvement of
// ZoomClient).
//
// Hmph, there may have been a better way to design this, but I really wanted (and needed)
// ZoomView to be a self-contained z-machine thingie. Which is what breaks the MVC
// paradigm. Well, that and the need for two completely seperate models (game data and
// game state). It makes sense if you don't care about autosave.
//
// Oh, and, umm, official Zoom terminology is 'Story' rather than 'Game'. Except I always
// forget that.

@implementation ZoomClient

- (id) init {
    self = [super init];

    if (self) {
        gameData = nil;
		story = nil;
		storyId = nil;
		autosaveData = nil;
    }

    return self;
}

- (void) dealloc {
    [gameData release];
	if (story) [story release];
	if (storyId) [storyId release];
    
    [super dealloc];
}

// = Creating the document =
- (void) makeWindowControllers {
    ZoomClientController* controller = [[ZoomClientController allocWithZone: [self zone]] init];

    [self addWindowController: [controller autorelease]];
}

- (NSData *)dataRepresentationOfType:(NSString *)type {
    // Can't save, really

    return gameData;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)type {
    if (gameData) [gameData release];
    gameData = [data retain];
	
	storyId = [[ZoomStoryID alloc] initWithZCodeStory: gameData];

	if (storyId == nil) {
		// Can't ID this story
		[gameData release];
		gameData = nil;
		return NO;
	}
	
	story = [[[NSApp delegate] userMetadata] findStory: storyId];
	
	if (!story) {
		story = [[NSApp delegate] findStory: storyId];
		
		if (story == nil) {
			story = [[ZoomStory alloc] init];
			[story setTitle: [[[self fileName] lastPathComponent] stringByDeletingPathExtension]];
		} else {
			[story retain];
		}
		
		[story addID: storyId];
		
		[[[NSApp delegate] userMetadata] storeStory: [[story copy] autorelease]];
		[story release];
		
		story = [[[NSApp delegate] userMetadata] findStory: storyId];
		if (story == nil) {
			story = [[ZoomStory alloc] init];
		} else {
			[story retain];
		}
	} else {
		[story retain];
	}
	
	[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: [self fileName]
											  withIdent: storyId];
    
    return YES;
}

// = Document info =

- (NSData*) gameData {
    return gameData;
}

- (ZoomStory*) storyInfo {
	return story;
}

- (ZoomStoryID*) storyId {
	return storyId;
}

// = Autosave =

- (void) setAutosaveData: (NSData*) data {
	if (autosaveData) [autosaveData release];
	autosaveData = [data retain];
}

- (NSData*) autosaveData {
	return autosaveData;
}

- (void) loadDefaultAutosave {
	if (autosaveData) [autosaveData release];
	
	NSString* autosaveDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: storyId];
	NSString* autosaveFile = [autosaveDir stringByAppendingPathComponent: @"autosave.zoomauto"];
	
	autosaveData = [[NSData dataWithContentsOfFile: autosaveFile] retain];
}

@end
