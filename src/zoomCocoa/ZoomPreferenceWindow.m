//
//  ZoomPreferenceWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Dec 20 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomPreferenceWindow.h"


static NSToolbarItem* generalSettingsItem;
static NSToolbarItem* gameSettingsItem;
static NSToolbarItem* fontSettingsItem;
static NSToolbarItem* colourSettingsItem;

static NSDictionary*  itemDictionary = nil;

@implementation ZoomPreferenceWindow

+ (void) initialize {
	// Create the toolbar items
	generalSettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"generalSettings"];
	gameSettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"gameSettings"];
	fontSettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"fontSettings"];
	colourSettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: @"colourSettings"];
	
	// ... and the dictionary
	itemDictionary = [[NSDictionary dictionaryWithObjectsAndKeys:
		generalSettingsItem, @"generalSettings",
		gameSettingsItem, @"gameSettings",
		fontSettingsItem, @"fontSettings",
		colourSettingsItem, @"colourSettings",
		nil] retain];
	
	// Set up the items
	[generalSettingsItem setLabel: @"General"];
	[generalSettingsItem setImage: [[[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForImageResource: @"generalSettings"]] autorelease]];
	[gameSettingsItem setLabel: @"Game"];
	[gameSettingsItem setImage: [[[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForImageResource: @"gameSettings"]] autorelease]];
	[fontSettingsItem setLabel: @"Fonts"];
	[fontSettingsItem setImage: [[[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForImageResource: @"fontSettings"]] autorelease]];
	[colourSettingsItem setLabel: @"Colour"];
	[colourSettingsItem setImage: [[[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForImageResource: @"colourSettings"]] autorelease]];
	
	// And the actions
	[generalSettingsItem setAction: @selector(generalSettings:)];
	[gameSettingsItem setAction: @selector(gameSettings:)];
	[fontSettingsItem setAction: @selector(fontSettings:)];
	[colourSettingsItem setAction: @selector(colourSettings:)];	
}

- (id) init {
	return [self initWithWindowNibName: @"Preferences"];
}

- (void) dealloc {
	if (toolbar) [toolbar release];
	
	[super dealloc];
}

- (void) windowDidLoad {
	// Set the toolbar
	toolbar = [[NSToolbar allocWithZone: [self zone]] initWithIdentifier: @"preferencesToolbar"];
	
	[toolbar setDelegate: self];
	[toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
	[toolbar setAllowsUserCustomization: NO];
	
	[[self window] setToolbar: toolbar];
	
	[[self window] setContentSize: [generalSettingsView frame].size];
	[[self window] setContentView: generalSettingsView];
}

// == Setting the pane that's being displayed ==

- (void) switchToPane: (NSView*) preferencePane {
	if ([[self window] contentView] == preferencePane) return;
	
	// (FIXME: this is OS X 10.3 only)
	NSRect currentFrame = [[self window] contentRectForFrameRect: [[self window] frame]];
	
	currentFrame.origin.y    -= [preferencePane frame].size.height - currentFrame.size.height;
	currentFrame.size.height  = [preferencePane frame].size.height;
	
	[[self window] setContentView: [[[NSView alloc] init] autorelease]];
	[[self window] setFrame: [[self window] frameRectForContentRect: currentFrame]
					display: YES
					animate: YES];
	[[self window] setContentView: preferencePane];
}

// == Toolbar delegate functions ==

- (NSToolbarItem *)toolbar: (NSToolbar *) toolbar
     itemForItemIdentifier: (NSString *)  itemIdentifier
 willBeInsertedIntoToolbar: (BOOL)        flag {
    return [itemDictionary objectForKey: itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return [NSArray arrayWithObjects:
		@"generalSettings", @"gameSettings", @"fontSettings", @"colourSettings",
		nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    return [NSArray arrayWithObjects:
		NSToolbarFlexibleSpaceItemIdentifier, @"generalSettings", @"gameSettings", @"fontSettings", @"colourSettings", NSToolbarFlexibleSpaceItemIdentifier,
		nil];
}

// == Toolbar actions ==

- (void) generalSettings: (id) sender {
	[self switchToPane: generalSettingsView];
}

- (void) gameSettings: (id) sender {
	[self switchToPane: gameSettingsView];
}

- (void) fontSettings: (id) sender {
	[self switchToPane: fontSettingsView];
}

- (void) colourSettings: (id) sender {
	[self switchToPane: colourSettingsView];
}

// == Setting the preferences that we're editing ==

- (void) setPreferences: (ZoomPreferences*) prefs {
	[displayWarnings setState: [prefs displayWarnings]?NSOnState:NSOffState];
	[fatalWarnings setState: [prefs fatalWarnings]?NSOnState:NSOffState];
	[speakGameText setState: [prefs speakGameText]?NSOnState:NSOffState];
	
	[gameTitle setStringValue: [prefs gameTitle]];
	[interpreter selectItemAtIndex: [prefs interpreter]-1];
	[revision setStringValue: [NSString stringWithFormat: @"%c", [prefs revision]]];
}

@end
