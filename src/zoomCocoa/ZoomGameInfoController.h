/* ZoomGameInfoController */

// Controller for the game info window

#import <Cocoa/Cocoa.h>
#import "ZoomStory.h"

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

// Interface actions
- (IBAction)selectGenre:(id)sender;
- (IBAction)showGenreMenu:(id)sender;
- (IBAction)activateRating:(id)sender;

// Setting up the game info window
- (void) setGameInfo: (ZoomStory*) info;

// Reading the current (updated) contents of the game info window
- (NSString*) title;
- (NSString*) headline;
- (NSString*) author;
- (NSString*) genre;
- (int)       year;
- (NSString*) group;
- (NSString*) comments;
- (NSString*) teaser;
- (unsigned)  zarfRating;
- (float)     rating;

@end
