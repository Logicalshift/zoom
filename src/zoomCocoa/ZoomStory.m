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

// = Accessors =
- (NSString*) title {
	if (story && story->data.title) {
		return [(NSString*)IFStrCpyCF(story->data.title) autorelease];
	}
	
	return @"";
}

- (NSString*) headline {
	if (story && story->data.headline) {
		return [(NSString*)IFStrCpyCF(story->data.headline) autorelease];
	}
	
	return @"";
}

- (NSString*) author {
	if (story && story->data.author) {
		return [(NSString*)IFStrCpyCF(story->data.author) autorelease];
	}
	
	return @"";
}

- (NSString*) genre {
	if (story && story->data.genre) {
		return [(NSString*)IFStrCpyCF(story->data.genre) autorelease];
	}
	
	return @"";
}

- (int) year {
	if (story) return story->data.year;
	return 0;
}

- (NSString*) group {
	if (story && story->data.group) {
		return [(NSString*)IFStrCpyCF(story->data.group) autorelease];
	}
	
	return @"";
}

- (unsigned) zarfian {
	if (story) return story->data.zarfian;
	return IFMD_Unrated;
}

- (NSString*) teaser {
	if (story && story->data.teaser) {
		return [(NSString*)IFStrCpyCF(story->data.teaser) autorelease];
	}
	
	return @"";
}

- (NSString*) comment {
	if (story && story->data.comment) {
		return [(NSString*)IFStrCpyCF(story->data.comment) autorelease];
	}
	
	return @"";
}

- (float)     rating {
	if (story) return story->data.rating;
	return -1;
}

@end
