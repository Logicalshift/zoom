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
		
		if ([gameData length] < 64) {
			[self release];
			return nil;
		}
		
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

- (id) initWithZCodeFile: (NSString*) zcodeFile {
	self = [super init];
	
	if (self) {
		const unsigned char* bytes;
		
		NSFileHandle* fh = [NSFileHandle fileHandleForReadingAtPath: zcodeFile];
		NSData* data = [fh readDataOfLength: 64];
		[fh closeFile];
		
		if ([data length] < 64) {
			[self release];
			return nil;
		}
		
		bytes = [data bytes];
		
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

// = NSCopying =
- (id) copyWithZone: (NSZone*) zone {
	ZoomStoryID* newID = [[ZoomStoryID allocWithZone: zone] init];
	
	newID->ident = IFID_Alloc();
	IFIdent_Copy(newID->ident, ident);
	newID->needsFreeing = YES;
	
	return newID;
}

// = NSCoding =
- (void)encodeWithCoder:(NSCoder *)encoder {
	// Version might change later on
	int version = 1;
	
	[encoder encodeValueOfObjCType: @encode(int) at: &version];
	
	// General stuff (data format, MD5, etc)
	[encoder encodeValueOfObjCType: @encode(enum IFMDFormat) 
								at: &ident->dataFormat];
	[encoder encodeValueOfObjCType: @encode(IFMDByte)
								at: &ident->usesMd5];
	if (ident->usesMd5) {
		[encoder encodeArrayOfObjCType: @encode(IFMDByte)
								 count: 16
									at: ident->md5Sum];
	}
	
	switch (ident->dataFormat) {
		case IFFormat_ZCode:
			[encoder encodeArrayOfObjCType: @encode(IFMDByte)
									 count: 6
										at: ident->data.zcode.serial];
			[encoder encodeValueOfObjCType: @encode(int)
										at: &ident->data.zcode.release];
			[encoder encodeValueOfObjCType: @encode(int)
										at: &ident->data.zcode.checksum];
			break;
		
		default:
			/* No other formats are supported yet */
			break;
	}
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
	if (self) {
		ident = IFID_Alloc();
		needsFreeing = YES;
		
		// As above, but backwards
		int version;
		
		[decoder decodeValueOfObjCType: @encode(int) at: &version];
		
		if (version != 1) {
			// Only v1 decodes supported ATM
			[self release];
			
			NSLog(@"Tried to load a version %i ZoomStoryID (this version of Zoom supports only version 1)", version);
			
			return nil;
		}
		
		// General stuff (data format, MD5, etc)
		[decoder decodeValueOfObjCType: @encode(enum IFMDFormat) 
									at: &ident->dataFormat];
		ident->format = ident->dataFormat;
		[decoder decodeValueOfObjCType: @encode(IFMDByte)
									at: &ident->usesMd5];
		if (ident->usesMd5) {
			[decoder decodeArrayOfObjCType: @encode(IFMDByte)
									 count: 16
										at: ident->md5Sum];
		}
		
		switch (ident->dataFormat) {
			case IFFormat_ZCode:
				[decoder decodeArrayOfObjCType: @encode(IFMDByte)
										 count: 6
											at: ident->data.zcode.serial];
				[decoder decodeValueOfObjCType: @encode(int)
											at: &ident->data.zcode.release];
				[decoder decodeValueOfObjCType: @encode(int)
											at: &ident->data.zcode.checksum];
				break;
				
			default:
				/* No other formats are supported yet */
				break;
		}		
	}
	
	return self;
}

// = Hashing/comparing =
- (unsigned) hash {
	return [[self description] hash];
}

- (BOOL) isEqual: (id)anObject {
	if ([anObject isKindOfClass: [ZoomStoryID class]]) {
		ZoomStoryID* compareWith = anObject;
		
		if (IFID_Compare(ident, [compareWith ident]) == 0) {
			return YES;
		} else {
			return NO;
		}
	} else {
		return NO;
	}
}

- (NSString*) description {
	switch (ident->dataFormat) {
		case IFFormat_ZCode:
			return [NSString stringWithFormat: @"ZoomStoryID (ZCode): %i.%.6s.%04x",
				ident->data.zcode.release,
				ident->data.zcode.serial,
				ident->data.zcode.checksum];
			break;
			
		default:
			if (ident->usesMd5) {
				int x;
				
				NSMutableString* s = [NSMutableString string];
				NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
				
				for (x=0; x<16; x++) {
					[s appendString: [NSString stringWithFormat: @"%02x", ident->md5Sum[x]]];
				}

				[p release];

				return [NSString stringWithFormat: @"ZoomStoryID (MD5): %@", s];
			} else {
				return [NSString stringWithFormat: @"ZoomStoryID (nonspecific)"];
			}
	}
}

@end
