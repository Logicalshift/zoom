/* ZoomGameInfoController */

// Controller for the game info window

#import <Cocoa/Cocoa.h>

@class ZoomGameInfo;
@interface ZoomGameInfoController : NSWindowController {
	IBOutlet NSMenu*      genreMenu;
	
	IBOutlet NSTextField* gameName;
	IBOutlet NSTextField* headline;
	IBOutlet NSTextField* author;
	IBOutlet NSTextField* genre;
	IBOutlet NSTextField* year;
	IBOutlet NSTextField* group;
	
	IBOutlet NSTextView*  comments;
	IBOutlet NSTextView*  teaser;
	
	IBOutlet NSPopUpButton* zarfRating;
	IBOutlet NSSlider*      rating;
	IBOutlet NSButton*      ratingOn;
	
	IBOutlet NSTabView*     tabs;
}

+ (ZoomGameInfoController*) sharedGameInfoController;

- (IBAction)selectGenre:(id)sender;
- (IBAction)showGenreMenu:(id)sender;

- (void) setGameInfo: (ZoomGameInfo*) info;

@end
