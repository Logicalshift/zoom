//
//  ZoomSkein.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZoomSkeinItem.h"

@interface ZoomSkein : NSObject {
	ZoomSkeinItem* rootItem;
}

// Retrieving the root skein item
- (ZoomSkeinItem*) rootItem;

@end
