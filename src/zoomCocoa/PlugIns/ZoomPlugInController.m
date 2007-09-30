//
//  ZoomPlugInController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugInController.h"
#import "ZoomPlugInManager.h"
#import "ZoomPlugInCell.h"

@implementation ZoomPlugInController

// = Initialisation =

+ (ZoomPlugInController*) sharedPlugInController {
	static ZoomPlugInController* sharedController = nil;
	
	if (!sharedController) {
		sharedController = [[ZoomPlugInController alloc] initWithWindowNibName: @"PluginManager"];
		[[ZoomPlugInManager sharedPlugInManager] setDelegate: sharedController];
	}
	
	return sharedController;
}

- (id) initWithWindowNibName: (NSString*) name {
	self = [super initWithWindowNibName: name];
	
	if (self) {
		// Set the cell type in the table (interface builder seems to be unable to do this itself)
	}
	
	return self;
}

- (void) windowDidLoad {
	NSTableColumn* pluginColumn = [pluginTable tableColumnWithIdentifier: @"Plugin"];
	[pluginColumn setDataCell: [[[ZoomPlugInCell alloc] init] autorelease]];	
}

// = The data source for the plugin table =

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [[[ZoomPlugInManager sharedPlugInManager] informationForPlugins] count];
}

- (id)				tableView:(NSTableView *)aTableView 
	objectValueForTableColumn:(NSTableColumn *)aTableColumn 
						  row:(int)rowIndex {
	ZoomPlugInInfo* info = [[[ZoomPlugInManager sharedPlugInManager] informationForPlugins] objectAtIndex: rowIndex];
	return info;
}

// = Plugin manager delegate methods =

- (void) pluginInformationChanged {
	[pluginTable reloadData];
}

- (void) checkingForUpdates {
	[pluginProgress setIndeterminate: YES];
	[pluginProgress startAnimation: self];
	
	[statusField setStringValue: @"Checking for updates..."];
	[statusField setHidden: NO];
	
	[installButton setEnabled: NO];
	[checkForUpdates setEnabled: NO];
}

- (void) finishedCheckingForUpdates {
	[pluginProgress stopAnimation: self];
	[statusField setHidden: YES];

	[installButton setEnabled: YES];
	[checkForUpdates setEnabled: YES];
}

- (void) downloadingUpdates {
	[pluginProgress setIndeterminate: YES];
	[pluginProgress startAnimation: self];
	[pluginProgress setMinValue: 0];
	[pluginProgress setMaxValue: 100];
	
	[statusField setStringValue: @"Downloading updates..."];
	[statusField setHidden: NO];
	
	[installButton setEnabled: NO];
	[checkForUpdates setEnabled: NO];	
}

- (void) downloadProgress: (NSString*) status
			   percentage: (float) percent {
	if (percent >= 0) {
		[pluginProgress setIndeterminate: NO];
		[pluginProgress setDoubleValue: percent];
	} else {
		[pluginProgress setIndeterminate: YES];
	}

	[statusField setStringValue: status];
}

- (void) finishedDownloadingUpdates {
	[pluginProgress stopAnimation: self];
	[statusField setHidden: YES];
	
	[installButton setEnabled: YES];
	[checkForUpdates setEnabled: YES];	
}

// = Actions =

- (IBAction) installUpdates: (id) sender {
	// TODO: implement this properly
	
	// Download the updates
	[[ZoomPlugInManager sharedPlugInManager] downloadUpdates];
}

- (IBAction) checkForUpdates: (id) sender {
	[[ZoomPlugInManager sharedPlugInManager] checkForUpdates];
}

@end
