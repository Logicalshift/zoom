//
//  ZoomStory.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "ZoomStory.h"

#include "ifmetadata.h"

@implementation ZoomStory

- (id) init {
	self = [super init];
	
	if (self) {
		story = IFStory_Alloc();
		needsFreeing = YES;
	}
	
	return self;
}

- (id) initWithStory: (IFMDStory*) s {
	self = [super init];
	
	if (self) {
		story = s;
		needsFreeing = NO;
	}
	
	return self;
}

- (void) dealloc {
	if (needsFreeing) {
		IFStory_Free(story);
		free(story);
	}
	
	[super dealloc];
}

@end
