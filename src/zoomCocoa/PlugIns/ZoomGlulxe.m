//
//  ZoomGlulxe.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 18/12/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomGlulxe.h"
#import "ZoomBlorbFile.h"

@implementation ZoomGlulxe

+ (BOOL) canRunPath: (NSString*) path {
	NSString* extn = [[path pathExtension] lowercaseString];
	
	// We can run .ulx files
	if ([extn isEqualToString: @"ulx"]) return YES;
	
	// ... and we can run blorb files with a Glulx block in them
	if ([extn isEqualToString: @"blb"] || [extn isEqualToString: @"glb"] || [extn isEqualToString: @"gblorb"] || [extn isEqualToString: @"blorb"]) {
		ZoomBlorbFile* blorb = [[ZoomBlorbFile alloc] initWithContentsOfFile: path];
		
		if (blorb != nil && [blorb dataForChunkWithType: @"GLUL"] != nil) {
			return YES;
		}
	}
	
	return [super canRunPath: path];
}

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
