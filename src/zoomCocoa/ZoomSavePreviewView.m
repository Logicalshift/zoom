//
//  ZoomSavePreviewView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Mon Mar 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSavePreviewView.h"
#import "ZoomSavePreview.h"

#import "ZoomClient.h"


@implementation ZoomSavePreviewView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		upperWindowViews = nil;
		[self setAutoresizesSubviews: YES];
		[self setAutoresizingMask: NSViewWidthSizable];
		selected = NSNotFound;
    }
    return self;
}

- (void) dealloc {
	if (upperWindowViews) [upperWindowViews release];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
}

- (void) setDirectoryToUse: (NSString*) directory {
	// Get rid of our old views
	if (upperWindowViews) {
		[upperWindowViews makeObjectsPerformSelector: @selector(removeFromSuperview)];
		[upperWindowViews release];
		upperWindowViews = nil;
	}
	
	upperWindowViews = [[NSMutableArray alloc] init];
	selected = NSNotFound;
	
	if (directory == nil || ![[NSFileManager defaultManager] fileExistsAtPath: directory]) {
		NSRect ourFrame = [self frame];
		ourFrame.size.height = 2;
		[self setFrame: ourFrame];
		[self setNeedsDisplay: YES];
		return;
	}
	
	// Get our frame size
	NSRect ourFrame = [self frame];
	ourFrame.size.height = 0;
	
	// Load all the zoomSave files from the given directory
	NSArray* contents = [[NSFileManager defaultManager] directoryContentsAtPath: directory];
	
	if (contents == nil) {
		return;
	}
	
	// Read in the previews from any .zoomSave packages
	NSEnumerator* fileEnum = [contents objectEnumerator];
	NSString* file;
	
	while (file = [fileEnum nextObject]) {
		if ([[[file pathExtension] lowercaseString] isEqualToString: @"zoomsave"]) {
			// This is a zoomSave file - load the preview
			NSString* previewFile = [directory stringByAppendingPathComponent: file];
			previewFile = [previewFile stringByAppendingPathComponent: @"ZoomPreview.dat"];
			
			BOOL isDir;
			
			if (![[NSFileManager defaultManager] fileExistsAtPath: previewFile
													  isDirectory: &isDir]) {
				// Can't be a valid zoomSave file
				continue;
			}
			
			if (isDir) {
				// Also can't be a valid zoomSave file
				continue;
			}
			
			// Presumably, this is a valid preview file...
			ZoomUpperWindow* win = [NSUnarchiver unarchiveObjectWithFile: previewFile];
			
			if (win != nil && ![win isKindOfClass: [ZoomUpperWindow class]]) continue;
			
			// We've got a valid window - add to the list of upper windows
			ZoomSavePreview* preview;
			
			preview = [[ZoomSavePreview alloc] initWithPreview: win
													  filename: previewFile];
			
			[preview setAutoresizingMask: NSViewWidthSizable];
			[preview setMenu: [self menu]];
			[self addSubview: preview];
			[upperWindowViews addObject: [preview autorelease]];
		}
	}
	
	// Arrange the views, resize ourselves
	float size = 2;
	NSRect bounds = [self bounds];
	
	NSEnumerator* viewEnum = [upperWindowViews objectEnumerator];
	ZoomSavePreview* view;
	
	while (view = [viewEnum nextObject]) {
		[view setFrame: NSMakeRect(0, size, bounds.size.width, 48)];
		size += 49;
	}
	
	NSRect frame = [self frame];
	frame.size.height = size;
	
	[self setFrameSize: frame.size];
	[self setNeedsDisplay: YES];
}

- (void) previewMouseUp: (NSEvent*) evt
				 inView: (ZoomSavePreview*) view {
	int clicked = [upperWindowViews indexOfObjectIdenticalTo: view];
	
	if (clicked == NSNotFound) {
		NSLog(@"BUG: save preview not found");
		return;
	}
	
	if ([evt clickCount] == 1) {
		// Select a new view
		if (selected != NSNotFound) {
			[[upperWindowViews objectAtIndex: selected] setHighlighted: NO];
		}
		
		[view setHighlighted: YES];
		selected = clicked;
	} else if ([evt clickCount] == 2) {
		// Launch this game
		NSString* filename = [view filename];
		NSString* directory = [filename stringByDeletingLastPathComponent];
		
		//ZoomClient* newDoc = 
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: directory
																				display: YES];
	}
}

- (NSString*) selectedSaveGame {
	if (selected >= 0 && selected != NSNotFound) {
		return [[upperWindowViews objectAtIndex: selected] filename];
	} else {
		return nil;
	}
}

@end
