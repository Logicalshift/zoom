//
//  ZoomCollapsableView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Feb 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface ZoomCollapsableView : NSView {
	NSMutableArray* views;
	NSMutableArray* titles;
	NSMutableArray* states; // Booleans, indicating if this is shown or not
	
	BOOL rearranging;
}

- (void) addSubview: (NSView*) subview
		  withTitle: (NSString*) title;
- (void) rearrangeSubviews;
- (void) subviewFrameChanged: (NSNotification*) not;

@end
