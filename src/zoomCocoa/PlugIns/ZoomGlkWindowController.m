//
//  ZoomGlkWindowController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkWindowController.h"
#import "ZoomPreferences.h"
#import "ZoomTextToSpeech.h"
#import "ZoomSkeinController.h"
#import "ZoomSkein.h"
#import "ZoomGlkDocument.h"
#import "ZoomGameInfoController.h"
#import "ZoomNotesController.h"

#import <GlkView/GlkHub.h>
#import <GlkView/GlkView.h>

///
/// Class to interface to Zoom's skein system
///
@interface ZoomGlkSkeinOutputReceiver : NSObject<GlkAutomation>{
	ZoomSkein* skein;
}

- (id) initWithSkein: (ZoomSkein*) skein;

@end

@implementation ZoomGlkSkeinOutputReceiver

- (id) initWithSkein: (ZoomSkein*) newSkein {
	self = [super init];
	
	if (self) {
		skein = [newSkein retain];
	}
	
	return self;
}

- (void) dealloc {
	[skein release];
	[super dealloc];
}

- (IBAction) glkTaskHasStarted: (id) sender {
	[skein zoomInterpreterRestart];	
}

- (void) setGlkInputSource: (id) newSource {
}

- (void) receivedCharacters: (NSString*) characters
					 window: (int) windowNumber
				   fromView: (GlkView*) view {
	[skein outputText: characters];
}

- (void) userTyped: (NSString*) userInput
			window: (int) windowNumber
		 lineInput: (BOOL) isLineInput
		  fromView: (GlkView*) view {
	[skein zoomWaitingForInput];
	if (isLineInput) {
		[skein inputCommand: userInput];
	} else {
		[skein inputCharacter: userInput];
	}
}

- (void) userClickedAtXPos: (int) xpos
					  ypos: (int) ypos
					window: (int) windowNumber
				  fromView: (GlkView*) view {
}

- (void) viewWaiting: (GlkView*) view {
	// Do nothing
}

- (void) viewIsWaitingForInput: (GlkView*) view {
}

@end

///
/// The window controller proper
///
@interface ZoomGlkWindowController(ZoomPrivate)

- (void) prefsChanged: (NSNotification*) not;

@end

@implementation ZoomGlkWindowController

+ (void) initialize {
	// Set up the Glk hub
	[[GlkHub sharedGlkHub] useProcessHubName];
	[[GlkHub sharedGlkHub] setRandomHubCookie];
}

// = Preferences =

+ (GlkPreferences*) glkPreferencesFromZoomPreferences {
	GlkPreferences* prefs = [[GlkPreferences alloc] init];
	ZoomPreferences* zPrefs = [ZoomPreferences globalPreferences];
	
	// Set the fonts according to the Zoom preferences object
	[prefs setProportionalFont: [[zPrefs fonts] objectAtIndex: 0]];
	[prefs setFixedFont: [[zPrefs fonts] objectAtIndex: 4]];
	
	// Set the typography options according to the Zoom preferences object
	[prefs setTextMargin: [zPrefs textMargin]];
	[prefs setUseScreenFonts: [zPrefs useScreenFonts]];
	[prefs setUseHyphenation: [zPrefs useHyphenation]];
	
	[prefs setScrollbackLength: [zPrefs scrollbackLength]];
	
	// Set the foreground/background colours
	NSColor* foreground = [[zPrefs colours] objectAtIndex: 0];
	NSColor* background = [[zPrefs colours] objectAtIndex: 7];
	
	NSEnumerator* styleEnum = [[prefs styles] keyEnumerator];
	NSMutableDictionary* newStyles = [NSMutableDictionary dictionary];
	NSNumber* styleNum;

	while (styleNum = [styleEnum nextObject]) {
		GlkStyle* thisStyle = [[prefs styles] objectForKey: styleNum];
		
		[thisStyle setTextColour: foreground];
		[thisStyle setBackColour: background];
		
		[newStyles setObject: thisStyle
					  forKey: styleNum];
	}
	
	[prefs setStyles: newStyles];
	
	return [prefs autorelease];
}

// = Initialisation =

- (id) init {
	self = [super initWithWindowNibPath: [[NSBundle bundleForClass: [ZoomGlkWindowController class]] pathForResource: @"GlkWindow"
																											  ofType: @"nib"]
								  owner: self];
	
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												selector: @selector(prefsChanged:)
													name: ZoomPreferencesHaveChangedNotification
												  object: nil];
		
		skein = [[ZoomSkein alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[clientPath release];
	[inputPath release];
	[logo release];
	[tts release];
	[skein release];
	
	if (glkView) [glkView setDelegate: nil];
	
	[super dealloc];
}

- (void) maybeStartView {
	// If we're sufficiently configured to start the application, then do so
	if (glkView && clientPath && inputPath) {
		[tts release];
		tts = [[ZoomTextToSpeech alloc] init];
		[glkView setDelegate: self];
		[glkView addOutputReceiver: [[[ZoomGlkSkeinOutputReceiver alloc] initWithSkein: skein] autorelease]];
		[glkView setPreferences: [ZoomGlkWindowController glkPreferencesFromZoomPreferences]];
		[glkView setInputFilename: inputPath];
		[glkView launchClientApplication: clientPath
						   withArguments: [NSArray array]];
		
		[self prefsChanged: nil];
	}
}

- (void) windowDidLoad {
	// Configure the view
	[glkView setRandomViewCookie];
	[logDrawer setLeadingOffset: 16];
	[logDrawer setContentSize: NSMakeSize([logDrawer contentSize].width, 120)];
	[logDrawer setMinContentSize: NSMakeSize(0, 120)];
	
	// Set the default log message
	[logText setString: [NSString stringWithFormat: @"Zoom CocoaGlk Plugin\n"]];
	
	// Start it if we've got enough information
	[self maybeStartView];
}

- (void) prefsChanged: (NSNotification*) not {
	// TODO: actually change the preferences (might need some changes to the way Glk styles work here; styles are traditionally fixed after they are set...)
	if (glkView == nil) return;
	
	if ([[ZoomPreferences globalPreferences] speakGameText]) {
		if (!ttsAdded) [glkView addOutputReceiver: tts];
		ttsAdded = YES;
	} else {
		if (ttsAdded) [glkView removeAutomationObject: tts];
		ttsAdded = NO;
	}
}

// = Configuring the client =

- (void) setClientPath: (NSString*) newPath {
	// Set the client path
	[clientPath release];
	clientPath = nil;
	clientPath = [newPath copy];
	
	// Start it if we've got enough information
	[self maybeStartView];
}

- (void) setInputFilename: (NSString*) newPath {
	// Set the input path
	[inputPath release];
	inputPath = nil;
	inputPath = [newPath copy];
	
	// Start it if we've got enough information
	[self maybeStartView];
}

- (void) setLogo: (NSImage*) newLogo {
	[logo release];
	logo = [newLogo copy];
}

- (BOOL) disableLogo {
	return logo == nil;
}

- (NSImage*) logo {
	return logo;
}

- (NSString*) preferredSaveDirectory {
	return [[self document] preferredSaveDirectory];
}

// = Log messages =

- (void) showLogMessage: (NSString*) message
			 withStatus: (GlkLogStatus) status {
	// Choose a style for this message
	float msgSize = 10;
	NSColor* msgColour = [NSColor grayColor];
	BOOL isBold = NO;
	
	switch (status) {
		case GlkLogRoutine:
			break;
			
		case GlkLogInformation:
			isBold = YES;
			break;
			
		case GlkLogCustom:
			msgSize = 12;
			msgColour = [NSColor blackColor];
			break;
			
		case GlkLogWarning:
			msgColour = [NSColor blueColor];
			msgSize = 12;
			break;
			
		case GlkLogError:
			msgSize = 12;
			msgColour = [NSColor redColor];
			isBold = YES;
			break;
			
		case GlkLogFatalError:
			msgSize = 12;
			msgColour = [NSColor colorWithDeviceRed: 0.8
											  green: 0
											   blue: 0
											  alpha: 1.0];
			isBold = YES;
			break;
	}
	
	// Create the attributes for this style
	NSFont* font;
	
	if (isBold) {
		font = [NSFont boldSystemFontOfSize: msgSize];
	} else {
		font = [NSFont systemFontOfSize: msgSize];
	}
	
	NSDictionary* msgAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
		font, NSFontAttributeName,
		msgColour, NSForegroundColorAttributeName,
		nil];
	
	// Create the attributed string
	NSAttributedString* newMsg = [[NSAttributedString alloc] initWithString: [message stringByAppendingString: @"\n"]
																 attributes: msgAttributes];
	
	// Append this message to the log
	[[logText textStorage] appendAttributedString: [newMsg autorelease]];
	
	// Show the log drawer
	if (status >= GlkLogWarning && (status >= GlkLogFatalError || [[ZoomPreferences globalPreferences] displayWarnings])) {
		[logDrawer open: self];
	}
}

- (void) showLog: (id) sender {
	[logDrawer open: self];
}

- (void) windowWillClose: (NSNotification*) not {
	[glkView terminateClient];
}

// = The game info window =

- (IBAction) recordGameInfo: (id) sender {
	ZoomGameInfoController* sgI = [ZoomGameInfoController sharedGameInfoController];
	ZoomStory* storyInfo = [(ZoomGlkDocument*)[self document] storyData];
	
	if ([sgI gameInfo] == storyInfo) {
		NSDictionary* sgIValues = [sgI dictionary];
		
		[storyInfo setTitle: [sgIValues objectForKey: @"title"]];
		[storyInfo setHeadline: [sgIValues objectForKey: @"headline"]];
		[storyInfo setAuthor: [sgIValues objectForKey: @"author"]];
		[storyInfo setGenre: [sgIValues objectForKey: @"genre"]];
		[storyInfo setYear: [[sgIValues objectForKey: @"year"] intValue]];
		[storyInfo setGroup: [sgIValues objectForKey: @"group"]];
		[storyInfo setComment: [sgIValues objectForKey: @"comments"]];
		[storyInfo setTeaser: [sgIValues objectForKey: @"teaser"]];
		[storyInfo setZarfian: [[sgIValues objectForKey: @"zarfRating"] unsignedIntValue]];
		[storyInfo setRating: [[sgIValues objectForKey: @"rating"] floatValue]];
		
		[[(id)[NSApp delegate] userMetadata] writeToDefaultFile];
	}
}

- (IBAction) updateGameInfo: (id) sender {
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == self) {
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [(ZoomGlkDocument*)[self document] storyData]];
	}
}

// = Gaining/losing focus =

- (void)windowDidBecomeMain:(NSNotification *)aNotification {
	[[ZoomSkeinController sharedSkeinController] setSkein: skein];

	[[ZoomGameInfoController sharedGameInfoController] setInfoOwner: self];
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [(ZoomGlkDocument*)[self document] storyData]];

	[[ZoomNotesController sharedNotesController] setGameInfo: [(ZoomGlkDocument*)[self document] storyData]];
	[[ZoomNotesController sharedNotesController] setInfoOwner: self];
}

- (void)windowDidResignMain:(NSNotification *)aNotification {
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == self) {
		[self recordGameInfo: self];
		
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
		[[ZoomGameInfoController sharedGameInfoController] setInfoOwner: nil];
	}

	if ([[ZoomNotesController sharedNotesController] infoOwner] == self) {
		[[ZoomNotesController sharedNotesController] setGameInfo: nil];
		[[ZoomNotesController sharedNotesController] setInfoOwner: nil];
	}
	
	if ([[ZoomSkeinController sharedSkeinController] skein] == skein) {
		[[ZoomSkeinController sharedSkeinController] setSkein: nil];
	}
}

// = Closing the window =

- (void) confirmFinish:(NSWindow *)sheet 
			returnCode:(int)returnCode 
		   contextInfo:(void *)contextInfo {
	if (returnCode == NSAlertAlternateReturn) {
		// Close the window
		closeConfirmed = YES;
		[[NSRunLoop currentRunLoop] performSelector: @selector(performClose:)
											 target: [self window]
										   argument: self
											  order: 32
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	}
}

- (BOOL) windowShouldClose: (id) sender {
	// Get confirmation if required
	if (!closeConfirmed && running && [[ZoomPreferences globalPreferences] confirmGameClose]) {
		BOOL autosave = [[ZoomPreferences globalPreferences] autosaveGames];
		NSString* msg = @"Sarah O'Conner will be terminated.";
		
		msg = @"There is still a story playing in this window. Are you sure you wish to finish it without saving? The current state of the game will be lost.";
		
		NSBeginAlertSheet(@"Finish the game?",
						  @"Keep playing", @"Finish", nil,
						  [self window], self,
						  @selector(confirmFinish:returnCode:contextInfo:), nil,
						  nil, msg);
		
		return NO;
	}
	
	return YES;
}

// = Ending the game =

- (void) taskHasStarted {
	[[self window] setDocumentEdited: YES];	
	
	running = YES;
	closeConfirmed = NO;
}

- (void) taskHasCrashed {
	[[self window] setTitle: [NSString stringWithFormat: @"%@ (crashed)", [[self document] displayName], nil]];
}

- (void) taskHasFinished {
	[[self window] setTitle: [NSString stringWithFormat: @"%@ (finished)", [[self document] displayName], nil]];	

	[[self window] setDocumentEdited: NO];
	running = NO;
}

@end
