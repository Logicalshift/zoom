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
        [self setShouldCloseDocument: YES];
    }

    return self;
}

- (void) dealloc {
    if (zoomView) [zoomView setDelegate: nil];
    if (zoomView) [zoomView killTask];
    
    [super dealloc];
}

- (void) windowDidLoad {
    [zoomView runNewServer: nil];
    [zoomView setDelegate: self];
}

- (void) zMachineStarted: (id) sender {
    [[zoomView zMachine] loadStoryFile: [[self document] gameData]];
}

@end
