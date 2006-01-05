//
//  ZoomGlulxe.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 18/12/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomGlulxe.h"


@implementation ZoomGlulxe

- (id) initWithFilename: (NSString*) gameFile {
	// Initialise as usual
	self = [super initWithFilename: gameFile];
	
	if (self) {
		// Set the client to be glulxe
		[self setClientPath: [[NSBundle bundleForClass: [self class]] pathForAuxiliaryExecutable: @"glulxe-client"]];
	}
	
	return self;
}

@end
