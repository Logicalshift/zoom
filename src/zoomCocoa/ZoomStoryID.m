//
//  ZoomStoryID.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomStoryID.h"

#include "ifmetadata.h"

@implementation ZoomStoryID

- (id) initWithZCodeStory: (NSData*) gameData {
	self = [super init];
	
	if (self) {
		const unsigned char* bytes = [gameData bytes];
		
		ident = IFID_Alloc();
		needsFreeing = YES;
		
		ident->format = ident->dataFormat = IFFormat_ZCode;

		memcpy(ident->data.zcode.serial, bytes + 0x12, 6);
		ident->data.zcode.release  = (((int)bytes[0x2])<<8)|((int)bytes[0x3]);
		ident->data.zcode.checksum = (((int)bytes[0x1c])<<8)|((int)bytes[0x1d]);
		ident->usesMd5 = 0;
	}
	
	return self;
}

- (id) initWithData: (NSData*) genericGameData {
	self = [super init];
	
	if (self) {
		// IMPLEMENT ME: take MD5 of file
	}
	
	return self;
}

- (id) initWithIdent: (struct IFMDIdent*) idt {
	self = [super init];
	
	if (self) {
		ident = idt;
		needsFreeing = NO;
	}
	
	return self;
}

- (void) dealloc {
	if (needsFreeing) {
		IFID_Free(ident);
		free(ident);
	}
	
	[super dealloc];
}

- (struct IFMDIdent*) ident {
	return ident;
}

@end
