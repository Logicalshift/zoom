//
//  ZoomScrollView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Oct 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "ZoomView.h"
#import "ZoomUpperWindowView.h"

@class ZoomView;
@class ZoomUpperWindowView;
@interface ZoomScrollView : NSScrollView {
    ZoomView*            zoomView;
    ZoomUpperWindowView* upperView;
        
    NSBox* upperDivider;
}

- (id) initWithFrame: (NSRect) frame
            zoomView: (ZoomView*) zView;

- (void) updateUpperWindows;

@end
