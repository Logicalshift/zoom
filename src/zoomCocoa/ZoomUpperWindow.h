//
//  ZoomUpperWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomView.h"

@interface ZoomUpperWindow : NSObject<ZUpperWindow> {
    ZoomView* theView;

    int startLine, endLine;

    NSMutableArray* lines;
    int xpos, ypos;
}

- (id) initWithZoomView: (ZoomView*) view;

- (int) length;
- (NSArray*) lines;

@end
