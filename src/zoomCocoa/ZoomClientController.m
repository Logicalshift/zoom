//
//  ZoomClientController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ZoomClientController.h"


@implementation ZoomClientController

- (id) init {
    self = [super initWithWindowNibName: @"ZoomClient"];

    if (self) {
    }

    return self;
}

- (void) windowDidLoad {
    NSLog(@"Setting ZMachine...");
    [zoomView setZMachine: [[self document] zMachine]];
}

@end
