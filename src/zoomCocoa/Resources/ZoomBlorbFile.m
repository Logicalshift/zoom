//
//  ZoomBlorbFile.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jul 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomBlorbFile.h"

@implementation ZoomBlorbFile

// = Testing files =

+ (BOOL) dataIsBlorbFile: (NSData*) data {
	NSObject<ZFile>* fl = [[ZDataFile alloc] initWithData: data];
	
	BOOL res = [self zfileIsBlorb: fl];
	
	[fl close];
	
	return res;
}

+ (BOOL) fileContentsIsBlorb: (NSString*) filename {
	NSObject<ZFile>* fl = [[ZHandleFile alloc] initWithFileHandle: [NSFileHandle fileHandleForReadingAtPath: filename]];
	
	BOOL res = [self zfileIsBlorb: fl];
	[fl close];
	
	return res;
}

+ (BOOL) zfileIsBlorb: (NSObject<ZFile>*) zfile {
	// Possibly should write a faster means of doing this
	ZoomBlorbFile* fl = [[[self class] alloc] initWithZFile: zfile];
	
	if (fl == nil) return NO;
	
	BOOL res;
	
	if ([fl->formID isEqualToString: @"IFRS"]) 
		res = YES;
	else
		res = NO;
	
	[fl release];
	
	return res;
}

// = Initialisation =
- (id) initWithZFile: (NSObject<ZFile>*) f {
	self = [super init];
	
	if (self) {
		if (file == nil) {
			[self release];
			return nil;
		}
		
		file = [f retain];
		
		// Attempt to read the file
		[file seekTo: 0];
		NSData* header = [file readBlock: 12];
		
		if (header == nil) {
			[self release];
			return nil;
		}
		
		if ([header length] != 12) {
			[self release];
			return nil;
		}
		
		// File must begin with 'FORM'
		if (memcmp([header bytes], "FORM", 4) != 0) {
			[self release];
			return nil;
		}
		
		// OK, we can get the form ID
		formID = [[NSString stringWithCString: [header bytes] + 8
									   length: 4] retain];
		
		// and the theoretical file length
		const unsigned char* lBytes = [header bytes] + 4;
		formLength = (lBytes[0]<<24)|(lBytes[1]<<16)|(lBytes[2]<<8)|(lBytes[3]<<0);
		
		if (formLength + 8 > (unsigned)[file fileSize]) {
			[self release];
			return nil;
		}
		
		// Now we can parse through the blocks
		iffBlocks = [[NSMutableArray alloc] init];
		typesToBlocks = [[NSMutableDictionary alloc] init];
		locationsToBlocks = [[NSMutableDictionary alloc] init];
		
		unsigned int pos = 12;
		while (pos < formLength) {
			// Read the block
			[file seekTo: pos];
			NSData* blockHeader = [file readBlock: 8];
			
			if (blockHeader == nil || [blockHeader length] != 8) {
				[self release];
				return nil;
			}
			
			// Decode it
			NSString* blockID = [NSString stringWithCString: [blockHeader bytes]
													 length: 4];
			lBytes = [blockHeader bytes]+4;
			unsigned int blockLength = (lBytes[0]<<24)|(lBytes[1]<<16)|(lBytes[2]<<8)|(lBytes[3]<<0);
			
			// Create the block data
			NSDictionary* block = [NSDictionary dictionaryWithObjectsAndKeys:
				blockID, @"id",
				[NSNumber numberWithUnsignedInt: blockLength], @"length",
				[NSNumber numberWithUnsignedInt: pos+8], @"offset",
				nil];
			
			// Store it
			[iffBlocks addObject: block];
			
			NSMutableArray* typeBlocks = [typesToBlocks objectForKey: blockID];
			if (typeBlocks == nil) {
				typeBlocks = [NSMutableArray array];
				[typesToBlocks setObject: typeBlocks
								  forKey: blockID];
			}
			[typeBlocks addObject: block];
			
			[locationsToBlocks setObject: block
								  forKey: [NSNumber numberWithUnsignedInt: pos]];
			
			// Next position
			pos += 8 + blockLength;
		}
	}
	
	return self;
}

- (id) initWithData: (NSData*) blorbFile {
	return [self initWithZFile: [[[ZDataFile alloc] initWithData: blorbFile] autorelease]];
}

- (id) initWithContentsOfFile: (NSString*) filename {
	return [self initWithZFile: [[[ZHandleFile alloc] initWithFileHandle:
		[NSFileHandle fileHandleForReadingAtPath: filename]] autorelease]];
}

- (void) dealloc {
	if (file) {
		[file close];
		[file release];
	}
	
	if (formID) [formID release];
	if (iffBlocks) [iffBlocks release];
	if (typesToBlocks) [typesToBlocks release];
	if (locationsToBlocks) [locationsToBlocks release];
	
	[super dealloc];
}

// Generic IFF data
- (NSArray*) chunksWithType: (NSString*) chunkType {
	return [typesToBlocks objectForKey: chunkType];
}

// Typed data
- (NSData*) imageDataWithNumber: (int) num {
}

- (NSData*) soundDataWithNumber: (int) num {
}

// Decoded data

@end
