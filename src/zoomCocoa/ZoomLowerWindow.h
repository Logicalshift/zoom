//
//  ZoomLowerWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Oct 08 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomProtocol.h"
#import "ZoomView.h"

@interface ZoomLowerWindow : NSObject<ZLowerWindow> {
    ZoomView* zoomView;
}

- (id) initWithZoomView: (ZoomView*) zoomView;

@end
