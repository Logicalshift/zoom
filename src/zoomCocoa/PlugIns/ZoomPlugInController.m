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

// = Actions =

- (IBAction) installUpdates: (id) sender {
	// TODO: Implement me
}

@end
