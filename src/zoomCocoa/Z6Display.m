//
//  Z6Display.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomProtocol.h"
#import "ZoomZMachine.h"
#import "ZoomServer.h"

#include "file.h"
#include "display.h"
#include "v6display.h"

extern int zDisplayCurrentWindow;
extern ZStyle* zDisplayCurrentStyle;
extern BOOL zPixmapDisplay;

#undef  MEASURE_REMOTELY		// Set to force measuring of font sizes, etc, on the Zoom process rather than this one. Will be slower

// = V6 display =

// Initialisation

int display_init_pixmap(int width, int height) {
	[(NSObject<ZPixmapWindow>*)[mainMachine windowNumber: 0] setSize: NSMakeSize(width, height)];
	zPixmapDisplay = YES;
	
	return 1;
}

void display_has_restarted(void) {
	[[mainMachine display] zMachineHasRestarted];
}

static int set_style(int style) {
    // Copy the old style
    ZStyle* newStyle = [zDisplayCurrentStyle copy];
	
    int oldStyle =
        ([newStyle reversed]?1:0)|
        ([newStyle bold]?2:0)|
        ([newStyle underline]?4:0)|
        ([newStyle fixed]?8:0)|
        ([newStyle symbolic]?16:0);
    
    // Not using this any more
    if (zDisplayCurrentStyle) [zDisplayCurrentStyle release];
	
    BOOL flag = (style<0)?NO:YES;
    if (style < 0) style = -style;
	
    // Set the flags
    if (style == 0) {
        [newStyle setBold: NO];
        [newStyle setUnderline: NO];
        [newStyle setFixed: NO];
        [newStyle setSymbolic: NO];
        [newStyle setReversed: NO];
		
        zDisplayCurrentStyle = newStyle;
        return oldStyle;
    }
	
    if (style&1)  [newStyle setReversed: flag];
    if (style&2)  [newStyle setBold: flag];
    if (style&4)  [newStyle setUnderline: flag];
    if (style&8)  [newStyle setFixed: flag];
    if (style&16) [newStyle setSymbolic: flag];
	
    // Set as the current style
    zDisplayCurrentStyle = newStyle;
	
    return oldStyle;
}

// Drawing

extern void  display_plot_rect(int x, int y,
							   int width, int height) { 
	[[mainMachine buffer] plotRect: NSMakeRect(x, y, width, height)
						 withStyle: zDisplayCurrentStyle
						  inWindow: [mainMachine windowNumber: 0]];
	
#ifdef DEBUG
	NSLog(@"display_plot_rect(%i, %i, %i, %i)", x, y, width, height);
#endif
}

void  display_plot_gtext(const int* buf, int len,
						 int style, int x, int y) {	
	set_style(style);
	
    // Convert buf to an NSString
    int length;
    static unichar* bufU = NULL;
	
    for (length=0; length < len; length++) {
        bufU = realloc(bufU, sizeof(unichar)*((length>>4)+1)<<4);
        bufU[length] = buf[length];
    }
	
    if (length == 0) return;
	
	// Plot the text
    NSString* str = [NSString stringWithCharacters: bufU
                                            length: length];
	
	[[mainMachine buffer] plotText: str
						   atPoint: NSMakePoint(x, y)
						 withStyle: zDisplayCurrentStyle
						  inWindow: [mainMachine windowNumber: 0]];

#ifdef DEBUG
	NSLog(@"display_plot_gtext(%@, %i, %i, %i, %i)", str, len, style, x, y);
#endif
}

void display_pixmap_cols(int fore, int back) { 
#ifdef DEBUG
	NSLog(@"ZDisplay: display_pixmap_cols(%i, %i)", fore, back);
#endif

	display_set_colour(fore, back);
}

void display_scroll_region(int x, int y,
						   int width, int height,
						   int xoff, int yoff) {
	[[mainMachine buffer] scrollRegion: NSMakeRect(x, y, width, height)
							   toPoint: NSMakePoint(x+xoff, y+yoff)
							  inWindow: [mainMachine windowNumber: 0]];
}

// Measuring

static int lastStyle = -12763;
static float lastWidth = -1;
static float lastHeight = -1;
static float lastAscent = -1;
static float lastDescent = -1;

static void measureStyle(int style) {
	if (style == lastStyle) return;

	set_style(style);
	[(NSObject<ZPixmapWindow>*)[mainMachine windowNumber: 0] getInfoForStyle: zDisplayCurrentStyle
																	   width: &lastWidth
																	  height: &lastHeight
																	  ascent: &lastAscent
																	 descent: &lastDescent];
	lastStyle = style;
}

static NSDictionary* styleAttributes(ZStyle* style) {
	static ZStyle* attributeStyle = nil;
	static NSDictionary* lastAttributes = nil;
	
	if (attributeStyle != nil &&
		[attributeStyle isEqual: style]) {
		return lastAttributes;
	}
	
	[lastAttributes release]; lastAttributes = nil;
	[attributeStyle release]; attributeStyle = nil;
	
	attributeStyle = [style copy];
	lastAttributes = [(NSObject<ZPixmapWindow>*)[mainMachine windowNumber: 0] attributesForStyle: style];
	[lastAttributes retain];
	
	return lastAttributes;
}

float display_measure_text(const int* buf, int len, int style) { 
	set_style(style);
	
    // Convert buf to an NSString
    int length;
    static unichar* bufU = NULL;
	
    for (length=0; length < len; length++) {
        bufU = realloc(bufU, sizeof(unichar)*((length>>4)+1)<<4);
        bufU[length] = buf[length];
    }
	
    if (length == 0) return 0;
	
    NSString* str = [NSString stringWithCharacters: bufU
                                            length: length];
	
	// Measure the string
	
#ifdef MEASURE_REMOTELY
	NSSize sz = [(NSObject<ZPixmapWindow>*)[mainMachine windowNumber: 0] measureString: str
																			 withStyle: zDisplayCurrentStyle];
#else
	NSSize sz = [str sizeWithAttributes: styleAttributes(zDisplayCurrentStyle)];
#endif
	
#ifdef DEBUG
	NSLog(@"display_measure_text(%@, %i, %i) = %g", str, len, style, sz.width);
#endif
	
	return sz.width;
}

float display_get_font_width(int style) { 
	measureStyle(style);
	
#ifdef DEBUG
	NSLog(@"display_get_font_width = %g", lastWidth);
#endif
	return lastWidth;
}

float display_get_font_height(int style) {
	measureStyle(style);

#ifdef DEBUG
	NSLog(@"display_get_font_height = %g", lastHeight);
#endif
	
	return ceilf(lastHeight)+1.0;
}

float display_get_font_ascent(int style) {
	measureStyle(style);
	
#ifdef DEBUG
	NSLog(@"display_get_font_ascent = %g", lastAscent);
#endif
	
	return ceilf(lastAscent);
}

float display_get_font_descent(int style) { 
	measureStyle(style);
	
#ifdef DEBUG
	NSLog(@"display_get_font_descent = %g", -lastDescent);
#endif
	
	return ceilf(-lastDescent);
}

int display_get_pix_colour(int x, int y) {
	[mainMachine flushBuffers];
	
	NSColor* pixColour = [(NSObject<ZPixmapWindow>*)[mainMachine windowNumber: 0] colourAtPixel: NSMakePoint(x, y)];
	
	int redComponent = [pixColour redComponent] * 31.0;
	int greenComponent = [pixColour greenComponent] * 31.0;
	int blueComponent = [pixColour blueComponent] * 31.0;
	
	return (redComponent)|(greenComponent<<5)|(blueComponent<<10);
}

// Input

void display_set_input_pos(int style, int x, int y, int width) { 
	set_style(style);
	
	[(NSObject<ZPixmapWindow>*)[mainMachine windowNumber: 0] setInputPosition: NSMakePoint(x, y)
																	withStyle: zDisplayCurrentStyle];
}

extern void  display_plot_image      (BlorbImage* img, int x, int y) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern void  display_wait_for_more   (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

extern void  display_read_mouse      (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern int   display_get_pix_mouse_b (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern int   display_get_pix_mouse_x (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern int   display_get_pix_mouse_y (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

extern void  display_set_mouse_win   (int x, int y, int width, int height) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

// = Images =
image_data*    image_load       (ZFile* file,
                                 int offset,
                                 int len,
                                 image_data* palimg) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void           image_unload     (image_data* img) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void           image_unload_rgb (image_data* img) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

int            image_cmp_palette(image_data* img1, image_data* img2) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

int            image_width      (image_data* img) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
int            image_height     (image_data* img) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
unsigned char* image_rgb        (image_data* img) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

void           image_resample   (image_data* img, int n, int d) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

void           image_set_data   (image_data* img, void* data,
                                 void (*destruct)(image_data*, void*)) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void*          image_get_data   (image_data* img) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
