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
	if (prefs) [prefs release];
	
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
	
	[fonts setDataSource: self];
	[fonts setDelegate: self];
	[colours setDataSource: self];
	[colours setDelegate: self];
}

// == Setting the pane that's being displayed ==

- (void) switchToPane: (NSView*) preferencePane {
	if ([[self window] contentView] == preferencePane) return;
	
	NSRect currentFrame = [[[self window] contentView] frame];
	NSRect oldFrame = currentFrame;
	NSRect windowFrame = [[self window] frame];
	
	currentFrame.origin.y    -= [preferencePane frame].size.height - currentFrame.size.height;
	currentFrame.size.height  = [preferencePane frame].size.height;
	
	// Grr, complicated, as OS X provides no way to work out toolbar proportions except in 10.3
	windowFrame.origin.x    += (currentFrame.origin.x - oldFrame.origin.x);
	windowFrame.origin.y    += (currentFrame.origin.y - oldFrame.origin.y);
	windowFrame.size.width  += (currentFrame.size.width - oldFrame.size.width);
	windowFrame.size.height += (currentFrame.size.height - oldFrame.size.height);
	
	[[self window] setContentView: [[[NSView alloc] init] autorelease]];
	[[self window] setFrame: windowFrame
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

- (void) setPreferences: (ZoomPreferences*) preferences {
	if (prefs) [prefs release];
	prefs = [preferences retain];
	
	[displayWarnings setState: [prefs displayWarnings]?NSOnState:NSOffState];
	[fatalWarnings setState: [prefs fatalWarnings]?NSOnState:NSOffState];
	[speakGameText setState: [prefs speakGameText]?NSOnState:NSOffState];
	[keepGamesOrganised setState: [prefs keepGamesOrganised]?NSOnState:NSOffState];
	[autosaveGames setState: [prefs autosaveGames]?NSOnState:NSOffState];
	
	[interpreter selectItemAtIndex: [prefs interpreter]-1];
	[revision setStringValue: [NSString stringWithFormat: @"%c", [prefs revision]]];
	
	[organiseDir setString: [prefs organiserDirectory]];
}

// == Table data source ==

- (int)numberOfRowsInTableView: (NSTableView *)aTableView {
	if (aTableView == fonts) return [[prefs fonts] count];
	if (aTableView == colours) return [[prefs colours] count];
	
	return 0;
}

static void appendStyle(NSMutableString* styleName,
						NSString* newStyle) {
	if ([styleName length] == 0) {
		[styleName appendString: newStyle];
	} else {
		[styleName appendString: @"-"];
		[styleName appendString: newStyle];
	}
}

- (id)              tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
						  row:(int)rowIndex {
	if (aTableView == fonts) {
		// Fonts table
		NSArray* fontArray = [prefs fonts];
		
		if ([[aTableColumn identifier] isEqualToString: @"Style"]) {
			NSMutableString* name = [[@"" mutableCopy] autorelease];
			
			if (rowIndex&1) appendStyle(name, @"bold");
			if (rowIndex&2) appendStyle(name, @"italic");
			if (rowIndex&4) appendStyle(name, @"fixed");
			if (rowIndex&8) appendStyle(name, @"symbolic");
			
			if ([name isEqualToString: @""]) name = [[@"roman" mutableCopy] autorelease];
			
			return name;
		} else if ([[aTableColumn identifier] isEqualToString: @"Font"]) {
			NSString* fontName;
			NSFont* font = [fontArray objectAtIndex: rowIndex];
			
			fontName = [NSString stringWithFormat: @"%@ (%.2gpt)", 
				[font fontName],
				[font pointSize]];
			
			NSAttributedString* res;
			
			res = [[[NSAttributedString alloc] initWithString: fontName
												   attributes: [NSDictionary dictionaryWithObject: font
																						   forKey: NSFontAttributeName]]
				autorelease];
			
			return res;
		}
		
		return @" -- ";
	}
	
	if (aTableView == colours) {
		if ([[aTableColumn identifier] isEqualToString: @"Colour name"]) {
			switch (rowIndex) {
				case 0: return @"Black";
				case 1: return @"Red";
				case 2: return @"Green";
				case 3: return @"Yellow";
				case 4: return @"Blue";
				case 5: return @"Magenta";
				case 6: return @"Cyan";
				case 7: return @"White";
				case 8: return @"Light grey";
				case 9: return @"Medium grey";
				case 10: return @"Dark grey";
				default: return @"Unused colour";
			}
			
		} else if ([[aTableColumn identifier] isEqualToString: @"Colour"]) {
			NSColor* theColour = [[prefs colours] objectAtIndex: rowIndex];
			NSAttributedString* res;
			
			res = [[NSAttributedString alloc] initWithString: @"Sample"
												  attributes: [NSDictionary dictionaryWithObjectsAndKeys:
													  theColour, NSForegroundColorAttributeName,
													  theColour, NSBackgroundColorAttributeName,
													  nil]];
			
			return [res autorelease];
		}
		
		return @" -- ";
	}
	
	return @" -- ";
}

// == Table delegate ==

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	if ([aNotification object] == fonts) {
		int selFont = [fonts selectedRow];
		
		if (selFont < 0) {
			return;
		}

		NSFont* font = [[prefs fonts] objectAtIndex: selFont];
		
		// Display font panel
		[[NSFontPanel sharedFontPanel] setPanelFont: font
										 isMultiple: NO];
		[[NSFontPanel sharedFontPanel] setEnabled: YES];
		[[NSFontPanel sharedFontPanel] setAccessoryView: nil];
		[[NSFontPanel sharedFontPanel] orderFront: self];
		[[NSFontPanel sharedFontPanel] reloadDefaultFontFamilies];
	} else if ([aNotification object] == colours) {
		int selColour = [colours selectedRow];
		
		if (selColour < 0) {
			return;
		}
		
		NSColor* colour = [[prefs colours] objectAtIndex: selColour];
		
		// Display colours
		[[NSColorPanel sharedColorPanel] setColor: colour];
		[[NSColorPanel sharedColorPanel] setAccessoryView: nil];
		[[NSColorPanel sharedColorPanel] orderFront: self];
	}
}

// == Font panel delegate ==

- (void) changeFont:(id) sender {
	// Change the selected font in the font table
	int selFont = [fonts selectedRow];
	
	if (selFont < 0) return;
	
	NSMutableArray* prefFonts = [[prefs fonts] mutableCopy];
	NSFont* newFont;
	
	newFont = [sender convertFont: [prefFonts objectAtIndex: selFont]];

	if (newFont) {
		[prefFonts replaceObjectAtIndex: selFont
						 withObject: newFont];
		[prefs setFonts: prefFonts];
		
		[fonts reloadData];
	}
	
	[prefFonts release];
}

- (void)changeColor:(id)sender {
	int selColour = [colours selectedRow];
	
	if (selColour < 0) {
		return;
	}
	
	NSColor* colour = [[NSColorPanel sharedColorPanel] color];
	
	NSMutableArray* cols = [[prefs colours] mutableCopy];
	
	if (colour) {
		[cols replaceObjectAtIndex: selColour
						withObject: colour];
		[prefs setColours: cols];
		
		[colours reloadData];
	}
	
	[cols release];
}

// == Various actions ==
- (IBAction) interpreterChanged: (id) sender {
	[prefs setInterpreter: [interpreter indexOfSelectedItem]+1];
}

- (IBAction) revisionChanged: (id) sender {
	[prefs setRevision: [[revision stringValue] characterAtIndex: 0]];
}

- (IBAction) displayWarningsChanged: (id) sender {
	[prefs setDisplayWarnings: [sender state]==NSOnState];
}

- (IBAction) fatalWarningsChanged: (id) sender {
	[prefs setFatalWarnings: [sender state]==NSOnState];
}

- (IBAction) speakGameTextChanged: (id) sender {
	[prefs setSpeakGameText: [sender state]==NSOnState];
}

- (IBAction) autosaveChanged: (id) sender {
	[prefs setAutosaveGames: [sender state]==NSOnState];
}

- (IBAction) keepOrganisedChanged: (id) sender {
	[prefs setKeepGamesOrganised: [sender state]==NSOnState];
	if ([sender state]==NSOffState) {
		[autosaveGames setState: NSOffState];
		[prefs setAutosaveGames: NO];
	}
}


- (void) changeOrganiserDirTo: (NSOpenPanel *)sheet
				   returnCode: (int)returnCode
				  contextInfo: (void *)contextInfo {
	if (returnCode != NSOKButton) return;
	
	[prefs setOrganiserDirectory: [sheet directory]];
	[organiseDir setString: [prefs organiserDirectory]];
}

- (IBAction) changeOrganiseDir: (id) sender {
	NSOpenPanel* dirChooser = [NSOpenPanel openPanel];
	
	[dirChooser setAllowsMultipleSelection: NO];
	[dirChooser setCanChooseDirectories: YES];
	[dirChooser setCanChooseFiles: NO];
	
	NSString* path = [prefs organiserDirectory];
	
	[dirChooser beginSheetForDirectory: path
								  file: nil
								 types: nil
						modalForWindow: [self window]
						 modalDelegate: self
						didEndSelector: @selector(changeOrganiserDirTo:returnCode:contextInfo:)
						   contextInfo: nil];
}

- (IBAction) resetOrganiseDir: (id) sender {
	[prefs setOrganiserDirectory: nil];
	[organiseDir setString: [prefs organiserDirectory]];
}

@end
