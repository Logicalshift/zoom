//
//  ZoomSkeinController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Jul 04 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinController.h"

#import "ZoomClientController.h"

@implementation ZoomSkeinController

+ (ZoomSkeinController*) sharedSkeinController {
	static ZoomSkeinController* cont = nil;
	
	if (!cont) {
		cont = [[[self class] alloc] init];
	}
	
	return cont;
}

- (id) init {
	self = [self initWithWindowNibName: @"Skein"];
	
	if (self) {
	}
	
	return self;
}

- (void) awakeFromNib {
	[(NSPanel*)[self window] setBecomesKeyOnlyIfNeeded: YES];
	[skeinView setDelegate: self];
}

- (void) setSkein: (ZoomSkein*) skein {
	if (skeinView == nil) {
		[self loadWindow];
	}
	
	[skeinView setSkein: skein];
}

- (ZoomSkein*) skein {
	return [skeinView skein];
}

- (void) restartGame {
	ZoomClientController* activeController = [[NSApp mainWindow] windowController];
	
	if ([activeController isKindOfClass: [ZoomClientController class]]) {
		// Will force a restart
		[[activeController zoomView] runNewServer: nil];
	}
}

- (void) playToPoint: (ZoomSkeinItem*) point
		   fromPoint: (ZoomSkeinItem*) fromPoint{
	ZoomClientController* activeController = [[NSApp mainWindow] windowController];
	
	if ([activeController isKindOfClass: [ZoomClientController class]]) {
		id inputSource = [ZoomSkein inputSourceFromSkeinItem: fromPoint
													  toItem: point];
		
		
		[[activeController zoomView] setInputSource: inputSource];
	}
}

@end
