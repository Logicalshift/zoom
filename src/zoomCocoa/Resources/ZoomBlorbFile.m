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
	
	if (![fl parseResourceIndex]) res = NO;
	
	[fl release];
	
	return res;
}

// = Initialisation =

- (id) initWithZFile: (NSObject<ZFile>*) f {
	self = [super init];
	
	if (self) {
		if (f == nil) {
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
			if ((pos&1)) pos++;
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
	
	if (resourceIndex) [resourceIndex release];
	
	[super dealloc];
}

// = Generic IFF data =

- (NSArray*) chunksWithType: (NSString*) chunkType {
	return [typesToBlocks objectForKey: chunkType];
}

- (NSData*) dataForChunk: (id) chunk {
	if (![chunk isKindOfClass: [NSDictionary class]]) return nil;
	if (!file) return nil;
	if (![[chunk objectForKey: @"offset"] isKindOfClass: [NSNumber class]]) return nil;
	if (![[chunk objectForKey: @"length"] isKindOfClass: [NSNumber class]]) return nil;
	
	NSDictionary* cD = chunk;
	
	[file seekTo: [[cD objectForKey: @"offset"] unsignedIntValue]];
	
	return [file readBlock: [[cD objectForKey: @"length"] unsignedIntValue]];
}

- (NSData*) dataForChunkWithType: (NSString*) chunkType {
	return [self dataForChunk: [[self chunksWithType: chunkType] objectAtIndex: 0]];
}

// = The resource index =

- (BOOL) parseResourceIndex {
	if (resourceIndex) {
		[resourceIndex release];
		resourceIndex = nil;
	}

	// Get the index chunk
	NSData* resourceChunk = [self dataForChunkWithType: @"RIdx"];
	if (resourceChunk == nil) {
		return NO;
	}
	const unsigned char* data = [resourceChunk bytes];
		
	// Create the index
	resourceIndex = [[NSMutableDictionary alloc] init];
	
	// Process the chunk
	int pos;
	for (pos = 4; pos+12 <= [resourceChunk length]; pos += 12) {
		// Read the chunk
		NSString* usage = [NSString stringWithCString: data+pos
											   length: 4];
		NSNumber* num = [NSNumber numberWithUnsignedInt: (data[pos+4]<<24)|(data[pos+5]<<16)|(data[pos+6]<<8)|(data[pos+7])];
		NSNumber* start = [NSNumber numberWithUnsignedInt: (data[pos+8]<<24)|(data[pos+9]<<16)|(data[pos+10]<<8)|(data[pos+11])];
		
		// Store it in the index
		NSMutableDictionary* usageDict = [resourceIndex objectForKey: usage];
		if (usageDict == nil) {
			usageDict = [NSMutableDictionary dictionary];
			[resourceIndex setObject: usageDict
							  forKey: usage];
		}
		
		[usageDict setObject: start
					  forKey: num];
		
		// Check against the data we've already parsed for this file
		if ([locationsToBlocks objectForKey: start] == nil) {
			NSLog(@"ZoomBlorbFile: Warning: '%@' resource %@ not found (at %@)", usage, num, start);
		}
	}
	
	return YES;
}

// = Typed data =

- (NSData*) gameHeader {
	return [self dataForChunkWithType: @"IFhd"];
}

- (NSData*) imageDataWithNumber: (int) num {
	// Get the index	
	if (!resourceIndex) {
		if (![self parseResourceIndex]) return NO;
	}
	if (!resourceIndex) return NO;
	
	// Get the resource
	return [self dataForChunk: 
		[locationsToBlocks objectForKey: 
			[[resourceIndex objectForKey: @"Pict"] objectForKey: 
				[NSNumber numberWithUnsignedInt: num]]]];
}

- (NSData*) soundDataWithNumber: (int) num {
	// Get the index	
	if (!resourceIndex) {
		if (![self parseResourceIndex]) return NO;
	}
	if (!resourceIndex) return NO;
	
	// Get the resource
	return [self dataForChunk: 
		[locationsToBlocks objectForKey: 
			[[resourceIndex objectForKey: @"Snd "] objectForKey: 
				[NSNumber numberWithUnsignedInt: num]]]];
}

// Fiddling with PNG palettes

// Decoded data
- (NSImage*) imageWithNumber: (int) num {
	NSDictionary* imageBlock = [locationsToBlocks objectForKey: 
		[[resourceIndex objectForKey: @"Pict"] objectForKey: 
			[NSNumber numberWithUnsignedInt: num]]];
	
	if (imageBlock == nil) return nil;
	
	NSString* type = [imageBlock objectForKey: @"id"];
	NSImage* res = nil;
	
	// IMPLEMENT ME: cache/retrieve the image
	
	if ([type isEqualToString: @"Rect"]) {
		// Nonstandard extension: rectangle
		res = nil; // Implement me
	} else if ([type isEqualToString: @"PNG "]) {
		// PNG file
		NSData* pngData = [self dataForChunk: imageBlock];
		
		res = [[[NSImage alloc] initWithData: pngData] autorelease];
	} else if ([type isEqualToString: @"JPEG"]) {
		// JPEG file
		res = [[[NSImage alloc] initWithData: [self dataForChunk: imageBlock]] autorelease];
	} else {
		// Could be anything
		res = [[[NSImage alloc] initWithData: [self dataForChunk: imageBlock]] autorelease];
	}
	
	// IMPLEMENT ME: scale according to resolution
	
	// Return the result
	return res;
}

@end
