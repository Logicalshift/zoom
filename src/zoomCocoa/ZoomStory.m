//
//  ZoomStory.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomStory.h"
#import "ZoomStoryID.h"

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
- (struct IFMDStory*) story {
	return story;
}

- (void) addID: (ZoomStoryID*) newID {
	int ident;
	int foundID = -1;
	
	for (ident = 0; ident<story->numberOfIdents; ident++) {
		if (IFID_Compare(story->idents[ident], [newID ident]) == 0) {
			foundID = ident; break;
		}
	}
	
	if (foundID >= 0) {
		if (story->idents[foundID]->dataFormat == IFFormat_ZCode) {
			if (story->idents[foundID]->data.zcode.checksum == 0x10000) {
				story->idents[foundID]->data.zcode.checksum = [newID ident]->data.zcode.checksum;
			}
		}
	} else {
		story->numberOfIdents++;
		story->idents = realloc(story->idents, sizeof(IFMDIdent)*story->numberOfIdents);
		story->idents[story->numberOfIdents-1] = IFID_Alloc();
		IFIdent_Copy(story->idents[story->numberOfIdents-1], [newID ident]);
	}
}

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

// = Setting data =

// Setting data
- (void) setTitle: (NSString*) newTitle {
	if (story->data.title) {
		free(story->data.title);
		story->data.title = NULL;
	}
	
	if (newTitle) {
		story->data.title = IFMakeStrCF((CFStringRef)newTitle);
	}
}

- (void) setHeadline: (NSString*) newHeadline {
	if (story->data.headline) {
		free(story->data.headline);
		story->data.headline = NULL;
	}
	
	if (newHeadline) {
		story->data.headline = IFMakeStrCF((CFStringRef)newHeadline);
	}
}

- (void) setAuthor: (NSString*) newAuthor {
	if (story->data.author) {
		free(story->data.author);
		story->data.author = NULL;
	}
	
	if (newAuthor) {
		story->data.author = IFMakeStrCF((CFStringRef)newAuthor);
	}
}

- (void) setGenre: (NSString*) genre {
	if (story->data.genre) {
		free(story->data.genre);
		story->data.genre = NULL;
	}
	
	if (genre) {
		story->data.genre = IFMakeStrCF((CFStringRef)genre);
	}
}

- (void) setYear: (int) year {
	story->data.year = year;
}

- (void) setGroup: (NSString*) group {
	if (story->data.group) {
		free(story->data.group);
		story->data.group = NULL;
	}
	
	if (group) {
		story->data.group = IFMakeStrCF((CFStringRef)group);
	}
}

- (void) setZarfian: (unsigned) zarfian {
	story->data.zarfian = zarfian;
}

- (void) setTeaser: (NSString*) teaser {
	if (story->data.teaser) {
		free(story->data.teaser);
		story->data.teaser = NULL;
	}
	
	if (teaser) {
		story->data.teaser = IFMakeStrCF((CFStringRef)teaser);
	}
}

- (void) setComment: (NSString*) comment {
	if (story->data.comment) {
		free(story->data.comment);
		story->data.comment = NULL;
	}
	
	if (comment) {
		story->data.comment = IFMakeStrCF((CFStringRef)comment);
	}
}

- (void) setRating: (float) rating {
	story->data.rating = rating;
}

// = NSCopying =
- (id) copyWithZone: (NSZone*) zone {
	IFMDStory* newStory = IFStory_Alloc();
	IFStory_Copy(newStory, story);
	
	ZoomStory* res;
	
	res = [[ZoomStory alloc] initWithStory: newStory];
	res->needsFreeing = YES;
	
	return res;
}

// = Story pseudo-dictionary methods =
- (id) objectForKey: (id) key {
	if (![key isKindOfClass: [NSString class]]) {
		[NSException raise: @"ZoomKeyNotString" format: @"Metadata key is not a string"];
		return nil;
	}
	
	if ([key isEqualToString: @"title"]) {
		return [self title];
	} else if ([key isEqualToString: @"headline"])  {
		return [self headline];
	} else if ([key isEqualToString: @"author"]) {
		return [self author];
	} else if ([key isEqualToString: @"genre"]) {
		return [self genre];
	} else if ([key isEqualToString: @"group"]) {
		return [self group];
	} else if ([key isEqualToString: @"year"]) {
		int year = [self year];
		
		if (year <= 0) return nil;
		
		return [NSString stringWithFormat: @"%i", year];
	} else if ([key isEqualToString: @"zarfian"]) {
		//return [self zarfian];
		return @"IMPLEMENT ME";
	} else if ([key isEqualToString: @"teaser"]) {
		return [self teaser];
	} else if ([key isEqualToString: @"comment"]) {
		return [self comment];
	} else if ([key isEqualToString: @"rating"]) {
		float rating = [self rating];
		
		if (rating < 0) return nil;
		
		return [NSString stringWithFormat: @"%.2f", rating];
	} else {
		[NSException raise: @"ZoomKeyNotKnown" format: @"Metadata key '%@' is not known", key];
		return nil;
	}
}

- (void) setObject: (id) value
			forKey: (id) key {
	if (![value isKindOfClass: [NSString class]]) {
		[NSException raise: @"ZoomBadValue" format: @"Metadata value is not a string"];
		return;
	}
	if (![key isKindOfClass: [NSString class]]) {
		[NSException raise: @"ZoomKeyNotString" format: @"Metadata key is not a string"];
		return;
	}

	if ([key isEqualToString: @"title"]) {
		[self setTitle: value];
	} else if ([key isEqualToString: @"headline"])  {
		[self setHeadline: value];
	} else if ([key isEqualToString: @"author"]) {
		[self setAuthor: value];
	} else if ([key isEqualToString: @"genre"]) {
		[self setGenre: value];
	} else if ([key isEqualToString: @"group"]) {
		[self setGroup: value];
	} else if ([key isEqualToString: @"year"]) {
		if (value == nil || [value length] == 0) [self setYear: 0];
		else [self setYear: atoi([value cString])];
	} else if ([key isEqualToString: @"zarfian"]) {
		// IMPLEMENT ME
	} else if ([key isEqualToString: @"teaser"]) {
		[self setTeaser: value];
	} else if ([key isEqualToString: @"comment"]) {
		[self setComment: value];
	} else if ([key isEqualToString: @"rating"]) {
		if (value == nil || [value length] == 0) [self setRating: -1];
		else [self setRating: atof([value cString])];
	} else {
		[NSException raise: @"ZoomKeyNotKnown" format: @"Metadata key '%@' is not known", key];
	}
}

@end
