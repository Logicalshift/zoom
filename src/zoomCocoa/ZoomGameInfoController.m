#import "ZoomGameInfoController.h"

@implementation ZoomGameInfoController

// = Shared info controller =
+ (ZoomGameInfoController*) sharedGameInfoController {
	static ZoomGameInfoController* shared = NULL;
	
	if (shared == NULL) {
		shared = [[ZoomGameInfoController alloc] init];
	}
	
	return shared;
}

// = Initialisation/finalisation =

- (id) init {
	self = [self initWithWindowNibName: @"GameInfo"];
	
	if (self) {
		gameInfo = nil;
	}
	
	return self;
}

- (void) dealloc {
	if (gameInfo) [gameInfo release];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	[super dealloc];
}

// = Interface actions =

- (IBAction)selectGenre:(id)sender {
	NSString* name = nil;
	switch ([sender tag]) {
		case 0: name = @"Fantasy"; break;
		case 1: name = @"Science fiction"; break;
		case 2: name = @"Horror"; break;
		case 3: name = @"Fairy tale"; break;
		case 4: name = @"Surreal"; break;
		case 5: name = @"Mystery"; break;
		case 6: name = @"Romance"; break;
		case 7: name = @"Historical"; break;
		case 8: name = @"Humour"; break;
		case 9: name = @"Parody"; break;
		case 10: name = @"Speed-IF"; break;
		case 11: name = @"Arcade"; break;
		case 12: name = @"Interpreter abuse"; break;
	}
	
	if (name) {
		[genre setStringValue: name];
	}
	
	[NSApp sendAction: @selector(infoGenreChanged:)
				   to: nil 
				 from: self];
}

- (IBAction)showGenreMenu:(id)sender {
	[NSMenu popUpContextMenu: genreMenu
				   withEvent: [NSApp currentEvent]
					 forView: [[self window] contentView]];
}

- (IBAction)activateRating:(id)sender {
	if ([ratingOn state] == NSOnState) {
		[rating setEnabled: YES];
	} else {
		[rating setEnabled: NO];
	}
	
	[NSApp sendAction: @selector(infoMyRatingChanged:)
				   to: nil 
				 from: self];
}

- (void) setGameInfo: (ZoomStory*) info {
	[self window]; // (Make sure the window is loaded)
	
	if (info == nil) {
		if (gameInfo) [gameInfo release];
		gameInfo = nil;
		
		[gameName setEnabled: NO];		[gameName setStringValue: @"No game selected"];
		[headline setEnabled: NO];		[headline setStringValue: @""];
		[author setEnabled: NO];		[author setStringValue: @""];
		[genre setEnabled: NO];			[genre setStringValue: @""];
		[year setEnabled: NO];			[year setStringValue: @""];
		[group setEnabled: NO];			[group setStringValue: @""];
		
		[comments setEditable: NO];		[comments setString: @""];
		[teaser setEditable: NO];		[teaser setString: @""];
		
		[zarfRating setEnabled: NO];	[zarfRating selectItemAtIndex: 0];
		[rating setEnabled: NO];		[rating setIntValue: 5.0];
		[ratingOn setEnabled: NO];		[ratingOn setState: NSOffState];
	} else {		
		if (gameInfo) [gameInfo release];
		gameInfo = [info retain];

		[gameName setEnabled: YES];		[gameName setStringValue: [info title]];
		[headline setEnabled: YES];		[headline setStringValue: [info headline]];
		[author setEnabled: YES];		[author setStringValue: [info author]];
		[genre setEnabled: YES];		[genre setStringValue: [info genre]];
		[year setEnabled: YES];			
		
		int yr = [info year];
		if (yr > 0) {
			[year setStringValue: [NSString stringWithFormat: @"%i", yr]];
		} else {
			[year setStringValue: @""];
		}
		
		[group setEnabled: YES];		[group setStringValue: [info group]];
		
		[comments setEditable: YES];	[comments setString: [info comment]];
		[teaser setEditable: YES];		[teaser setString: [info teaser]];
		
		[zarfRating setEnabled: YES];   [zarfRating selectItemAtIndex: [info zarfian]];
		
		float rat = [info rating];
		if (rat >= 0) {
			[rating setEnabled: YES];		[rating setIntValue: rat];
			[ratingOn setEnabled: YES];		[ratingOn setState: NSOnState];
		} else {
			[rating setEnabled: NO];		[rating setIntValue: 5.0];
			[ratingOn setEnabled: YES];		[ratingOn setState: NSOffState];
		}
	}
}

- (ZoomStory*) gameInfo {
	return gameInfo;
}

// Reading the current (updated) contents of the game info window
- (NSString*) title {
	return [gameName stringValue];
}

- (NSString*) headline {
	return [headline stringValue];
}

- (NSString*) author {
	return [author stringValue];
}

- (NSString*) genre {
	return [genre stringValue];
}

- (int) year {
	return [year intValue];
}

- (NSString*) group {
	return [group stringValue];
}

- (NSString*) comments {
	return [comments string];
}

- (NSString*) teaser {
	return [teaser string];
}

- (unsigned) zarfRating {
	return [zarfRating indexOfSelectedItem];
}

- (float) rating {
	if ([ratingOn state] == NSOnState) {
		return [rating floatValue];
	} else {
		return -1;
	}
}

- (NSDictionary*) dictionary {
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[self title], @"title",
		[self headline], @"headline",
		[self author], @"author",
		[self genre], @"genre",
		[NSNumber numberWithInt: [self year]], @"year",
		[self group], @"group",
		[self comments], @"comments",
		[self teaser], @"teaser",
		[NSNumber numberWithUnsignedInt: [self zarfRating]], @"zarfRating",
		[NSNumber numberWithFloat: [self rating]], @"rating",
		nil];
}

// = NSText delegate =
- (void)textDidEndEditing:(NSNotification *)aNotification {
	NSTextView* textView = [aNotification object];
	
	if (textView == comments) {
		[NSApp sendAction: @selector(infoCommentsChanged:)
					   to: nil
					 from: self];
	} else if (textView == teaser) {
		[NSApp sendAction: @selector(infoTeaserChanged:)
					   to: nil
					 from: self];
	} else {
		NSLog(@"Unknown text view");
	}
}

@end
