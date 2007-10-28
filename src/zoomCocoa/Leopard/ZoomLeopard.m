//
//  ZoomLeopard.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 28/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomLeopard.h"
#import <QuartzCore/QuartzCore.h>


@implementation ZoomLeopard

- (id) init {
	self = [super init];
	
	if (self) {
		NSLog(@"Leopard Extensions loaded");
		animationsWillFinish = [[NSMutableArray alloc] init];
		finishInvocations = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void) prepareToAnimateView: (NSView*) view
						layer: (CALayer*) layer {
	NSEnumerator* subviewEnum = [[view subviews] objectEnumerator];
	NSView* subview;
	while (subview = [subviewEnum nextObject]) {
		[self prepareToAnimateView: subview
							 layer: nil];		
	}

	if (![view wantsLayer]) {
		[view setWantsLayer: YES];
	}
	
	[view layer].backgroundColor = CGColorCreateGenericRGB(0, 0,0,0);
}

- (void) prepareToAnimateView: (NSView*) view {
	CALayer* viewLayer = [CALayer layer];
	
	viewLayer.backgroundColor = CGColorCreateGenericRGB(0, 0,0,0);

	[self prepareToAnimateView: view
						 layer: viewLayer];
}

- (void) popView: (NSView*) view 
		duration: (NSTimeInterval) seconds
		finished: (NSInvocation*) finished {
	// Set up the layers for this view
	[self prepareToAnimateView: view];
	
	// Create a pop-up animation
	CABasicAnimation* popAnimation = [CABasicAnimation animation];
	
	CATransform3D startScaling = CATransform3DScale(CATransform3DIdentity, 0.2, 0.2, 0.2);
	CATransform3D finalScaling = CATransform3DIdentity;
	CATransform3D popScaling   = CATransform3DScale(CATransform3DIdentity, 1.1, 1.1, 1.1);

	popAnimation.keyPath		= @"transform";
	popAnimation.fromValue		= [NSValue valueWithCATransform3D: startScaling];
	popAnimation.toValue		= [NSValue valueWithCATransform3D: popScaling];
	popAnimation.duration		= seconds * 0.8;
	popAnimation.beginTime		= CACurrentMediaTime();
	popAnimation.repeatCount	= 1;
	popAnimation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];

	CABasicAnimation* popBackAnimation = [CABasicAnimation animation];
	
	popBackAnimation.keyPath		= @"transform";
	popBackAnimation.fromValue		= [NSValue valueWithCATransform3D: popScaling];
	popBackAnimation.toValue		= [NSValue valueWithCATransform3D: finalScaling];
	popBackAnimation.duration		= seconds * 0.2;
	popBackAnimation.beginTime		= CACurrentMediaTime() + seconds * 0.8;
	popBackAnimation.repeatCount	= 1;
	popBackAnimation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
	
	// Create a fade-in animation
	CABasicAnimation* fadeAnimation = [CABasicAnimation animation];
	
	fadeAnimation.keyPath		= @"opacity";
	fadeAnimation.fromValue		= [NSNumber numberWithDouble: 0];
	fadeAnimation.toValue		= [NSNumber numberWithDouble: 1];
	fadeAnimation.repeatCount	= 1;
	fadeAnimation.timingFunction= [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
	fadeAnimation.duration		= seconds*0.8;
	fadeAnimation.fillMode		= kCAFillModeBoth;
	
	popBackAnimation.delegate = self;

	// Animate the view's layer
	[view layer].opacity = 1;
	[[view layer] removeAllAnimations];
	[[view layer] addAnimation: popAnimation
						forKey: @"PopView"];
	[[view layer] addAnimation: popBackAnimation
						forKey: @"PopBackView"];
	[[view layer] addAnimation: fadeAnimation
						forKey: @"FadeView"];

	// Set up the finished event handler
	if (finished) {
		[animationsWillFinish addObject: [[view layer] animationForKey: @"PopBackView"]];
		[finishInvocations addObject: finished];
	}
}

- (void) popOutView: (NSView*) view 
		   duration: (NSTimeInterval) seconds
		   finished: (NSInvocation*) finished {
	// Set up the layers for this view
	[self prepareToAnimateView: view];
	
	// Create a pop-up animation
	CABasicAnimation* popAnimation = [CABasicAnimation animation];
	
	CATransform3D startScaling = CATransform3DScale(CATransform3DIdentity, 0.2, 0.2, 0.2);
	CATransform3D finalScaling = CATransform3DIdentity;
	CATransform3D popScaling   = CATransform3DScale(CATransform3DIdentity, 1.1, 1.1, 1.1);
	
	popAnimation.keyPath		= @"transform";
	popAnimation.fromValue		= [NSValue valueWithCATransform3D: finalScaling];
	popAnimation.toValue		= [NSValue valueWithCATransform3D: popScaling];
	popAnimation.duration		= seconds * 0.2;
	popAnimation.beginTime		= CACurrentMediaTime();
	popAnimation.repeatCount	= 1;
	popAnimation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
	popAnimation.fillMode		= kCAFillModeBoth;
	
	CABasicAnimation* popBackAnimation = [CABasicAnimation animation];
	
	popBackAnimation.keyPath		= @"transform";
	popBackAnimation.fromValue		= [NSValue valueWithCATransform3D: popScaling];
	popBackAnimation.toValue		= [NSValue valueWithCATransform3D: startScaling];
	popBackAnimation.duration		= seconds * 0.8;
	popBackAnimation.beginTime		= CACurrentMediaTime() + seconds * 0.2;
	popBackAnimation.repeatCount	= 1;
	popBackAnimation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
	popBackAnimation.fillMode		= kCAFillModeBoth;
	
	// Create a fade-in animation
	CABasicAnimation* fadeAnimation = [CABasicAnimation animation];
	
	fadeAnimation.keyPath		= @"opacity";
	fadeAnimation.fromValue		= [NSNumber numberWithDouble: 1];
	fadeAnimation.toValue		= [NSNumber numberWithDouble: 0];
	fadeAnimation.repeatCount	= 1;
	fadeAnimation.timingFunction= [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
	fadeAnimation.duration		= seconds;
	fadeAnimation.fillMode		= kCAFillModeBoth;

	fadeAnimation.delegate = self;

	// Animate the view's layer
	[view layer].opacity = 0;
	[[view layer] removeAllAnimations];
	[[view layer] addAnimation: popAnimation
						forKey: @"PopView"];
	[[view layer] addAnimation: popBackAnimation
						forKey: @"PopBackView"];
	[[view layer] addAnimation: fadeAnimation
						forKey: @"FadeView"];
	
	// Set up the finished event handler
	if (finished) {
		[animationsWillFinish addObject: [[view layer] animationForKey: @"FadeView"]];
		[finishInvocations addObject: finished];
		fadeAnimation.delegate = self;
	}
}

- (void) clearLayersForView: (NSView*) view {
	if ([view wantsLayer]) {
		[view setWantsLayer: NO];

		NSEnumerator* subviewEnum = [[view subviews] objectEnumerator];
		NSView* subview;
		while (subview = [subviewEnum nextObject]) {
			[self clearLayersForView: subview];
		}
	}
}

// = Animation delegate functions =

- (void)animationDidStop:(CAAnimation *)theAnimation
				finished:(BOOL)flag {
	int index = [animationsWillFinish indexOfObject: theAnimation];
	
	if (index != NSNotFound) {
		[[finishInvocations objectAtIndex: index] invoke];
		
		[animationsWillFinish removeObjectAtIndex: index];
		[finishInvocations removeObjectAtIndex: index];
	}
}

@end
