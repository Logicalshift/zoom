//
//  ZoomStoryID.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ZoomStoryID : NSObject<NSCopying, NSCoding> {
	struct IFID* ident;
	BOOL needsFreeing;
}

+ (ZoomStoryID*) idForFile: (NSString*) filename;

- (id) initWithZCodeStory: (NSData*) gameData;
- (id) initWithZCodeFile: (NSString*) zcodeFile;
- (id) initWithGlulxFile: (NSString*) glulxFile;
- (id) initWithData: (NSData*) genericGameData;
- (id) initWithIdent: (struct IFID*) ident;
- (id) initWithZcodeRelease: (int) release
					 serial: (const unsigned char*) serial
				   checksum: (int) checksum;

- (struct IFID*) ident;

@end
