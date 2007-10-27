//
//  ZoomLFlipView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 27/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "ZoomLFlipView.h"

#define NORECURSION									// Define to specify that no recursive animation should be allowed

@implementation ZoomFlipView(ZoomLeopardFlipView)

+ (id) flipViewClass {
	static id classId = nil;
	if (!classId) {
		classId = [objc_lookUpClass("ZoomFlipView") retain];
	}
	return classId;
}

- (void) setupLayersForView: (NSView*) view {
	// Build the root layer
	if ([[self propertyDictionary] objectForKey: @"RootLayer"] == nil) {
		CALayer* rootLayer;
		[[self propertyDictionary] setObject: rootLayer = [CALayer layer]
									  forKey: @"RootLayer"];
		//rootLayer.layoutManager = self;
	}

	// Set up the layers for this view
	CALayer* viewLayer = [CALayer layer];
	
	[view setLayer: viewLayer];
	[viewLayer setFrame: [[self layer] bounds]];
	
	if (![view wantsLayer]) {
		[view setWantsLayer: YES];
	}
	if (![self wantsLayer]) {
		[self setLayer: [[self propertyDictionary] objectForKey: @"RootLayer"]];
		[self setWantsLayer: YES];
	}
}

- (void) leopardPrepareViewForAnimation: (NSView*) view {
	if (view == nil) return;
	
	[[self propertyDictionary] setObject: view
								  forKey: @"StartView"];
	
#ifdef NORECURSION
	while ([[view superview] isKindOfClass: [self class]]) {
		[(ZoomFlipView*)[view superview] finishAnimation];
	}
#endif
	
	// Setup the layers
	[self setupLayersForView: view];

	// Gather some information
	[originalView autorelease];
	[originalSuperview release];
	originalView = [view retain];
	originalSuperview = [[view superview] retain];
	originalFrame = [view frame];
	
	// Move the view into this view
	[[view retain] autorelease];
	[self setFrame: originalFrame];	

	[view removeFromSuperviewWithoutNeedingDisplay];
	[view setFrame: [self bounds]];
	
	[self addSubview: view];
	[[self layer] addSublayer: [view layer]];
	
	// Move this view to where the original view was
	[self setAutoresizingMask: [view autoresizingMask]];		
	[self removeFromSuperview];
	[self setFrame: originalFrame];
	[originalSuperview addSubview: self];
}

- (void) leopardAnimateTo: (NSView*) view
					style: (ZoomViewAnimationStyle) style {
	[[self propertyDictionary] setObject: view
								  forKey: @"FinalView"];

	// Setup the layers for the specified view
	[self setupLayersForView: view];

	// Move the view into this view
	[[view retain] autorelease];
	
	[view removeFromSuperview];
	[view setFrame: [self bounds]];
	
	[self addSubview: view];
	[[self layer] addSublayer: [view layer]];
}

- (void) leopardFinishAnimation {
	if (originalView) {
		NSView* finalView =[[self propertyDictionary] objectForKey: @"FinalView"];
		
		// Ensure nothing gets freed prematurely
		[[self retain] autorelease];
		[[originalView retain] autorelease];
		[[finalView retain] autorelease];
		
		// Move to the final view		
		[finalView removeFromSuperview];
		[finalView setFrame: [self frame]];
		[originalSuperview addSubview: finalView];

		// Self destruct
		[originalView removeFromSuperview];
		[self removeFromSuperview];
	}
}

@end
