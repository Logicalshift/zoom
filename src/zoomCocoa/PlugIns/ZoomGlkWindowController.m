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

#import <GlkView/GlkHub.h>
#import <GlkView/GlkView.h>

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
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[clientPath release];
	[inputPath release];
	[logo release];
	[tts release];
	
	if (glkView) [glkView setDelegate: nil];
	
	[super dealloc];
}

- (void) maybeStartView {
	// If we're sufficiently configured to start the application, then do so
	if (glkView && clientPath && inputPath) {
		[tts release];
		tts = [[ZoomTextToSpeech alloc] init];
		[glkView setDelegate: self];
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

@end
