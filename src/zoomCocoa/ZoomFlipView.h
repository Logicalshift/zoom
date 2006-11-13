//
//  ZoomFlipView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 23/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum ZoomViewAnimationStyle {
	ZoomAnimateLeft,
	ZoomAnimateRight,
	ZoomAnimateFade,
	
	ZoomCubeDown,
	ZoomCubeUp
} ZoomViewAnimationStyle;

///
/// NSView subclass that allows us to flip between several views
///
@interface ZoomFlipView : NSView {
	// The start and the end of the animation
	NSImage* startImage;
	NSImage* endImage;
	
	// Animation settings
	NSTimeInterval animationTime;
	ZoomViewAnimationStyle animationStyle;
	
	// Information used while animating
	NSOpenGLPixelBuffer* pixelBuffer;
	NSTimer* animationTimer;
	NSRect originalFrame;
	NSView* originalView;
	NSView* originalSuperview;
	NSDate* whenStarted;	
}

// Caching views
+ (NSImage*) cacheView: (NSView*) view;								// Returns an image with the contents of the specified view
- (void) cacheStartView: (NSView*) view;							// Caches a specific image as the start of an animation

// Animating
- (void) prepareToAnimateView: (NSView*) view;						// Prepares to animate, using the specified view as a template
- (void) animateTo: (NSView*) view									// Begins animating the specified view so that transitions from the state set in prepareToAnimateView to the new state
			 style: (ZoomViewAnimationStyle) style;
- (void) finishAnimation;											// Abandons any running animation

@end

@interface NSObject(ZoomViewAnimation)

- (void) removeTrackingRects;										// Optional method implemented by views that is a request from the animation view to remove any applicable tracking rectangles
- (void) setTrackingRects;											// Optional method implemented by views that is a request from the animation view to add any tracking rectangles back again

@end