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
	}
	
	return self;
}

- (void) dealloc {
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
}

- (IBAction)showGenreMenu:(id)sender {
	[NSMenu popUpContextMenu: genreMenu
				   withEvent: [NSApp currentEvent]
					 forView: [[self window] contentView]];
}

- (void) setGameInfo: (ZoomGameInfo*) info {
	[self window]; // (Make sure the window is loaded)
	
	if (info == nil) {
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
		[gameName setEnabled: YES];		[gameName setStringValue: @"No game selected"];
		[headline setEnabled: YES];		[headline setStringValue: @""];
		[author setEnabled: YES];		[author setStringValue: @""];
		[genre setEnabled: YES];		[genre setStringValue: @""];
		[year setEnabled: YES];			[year setStringValue: @""];
		[group setEnabled: YES];		[group setStringValue: @""];
		
		[comments setEditable: YES];	[comments setString: @""];
		[teaser setEditable: YES];		[teaser setString: @""];
		
		[zarfRating setEnabled: YES];   [zarfRating selectItemAtIndex: 0];
		[rating setEnabled: YES];		[rating setIntValue: 5.0];
		[ratingOn setEnabled: YES];		[ratingOn setState: NSOffState];
	}
}

@end
