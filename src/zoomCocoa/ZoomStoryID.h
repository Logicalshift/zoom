//
//  ZoomStoryID.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ZoomStoryID : NSObject {
	struct IFMDIdent* ident;
	BOOL needsFreeing;
}

- (id) initWithZCodeStory: (NSData*) gameData;
//- (id) initWithData: (NSData*) genericGameData;
- (id) initWithIdent: (struct IFMDIdent*) ident;

- (struct IFMDIdent*) ident;

@end
