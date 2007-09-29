//
//  ZoomPlugInController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugInController.h"


@implementation ZoomPlugInController

// = Initialisation =

+ (ZoomPlugInController*) sharedPlugInController {
	static ZoomPlugInController* sharedController = nil;
	
	if (!sharedController) {
		sharedController = [[ZoomPlugInController alloc] initWithWindowNibName: @"PluginManager"];
	}
	
	return sharedController;
}
	
// Actions
- (IBAction) installUpdates: (id) sender {
	// TODO: Implement me
}

@end
