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

- (id) initWithZCodeStory: (NSData*) gameData;
- (id) initWithZCodeFile: (NSString*) zcodeFile;
- (id) initWithData: (NSData*) genericGameData;
- (id) initWithIdent: (struct IFID*) ident;

- (struct IFID*) ident;

@end
