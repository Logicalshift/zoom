//
//  ZoomZMachine.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ZoomZMachine.h"
#import "ZoomServer.h"

#include "sys/time.h"


#include "zmachine.h"
#include "random.h"
#include "file.h"
#include "zscii.h"
#include "display.h"
#include "rc.h"
#include "stream.h"
#include "blorb.h"
#include "v6display.h"

#define DEBUG

@implementation ZoomZMachine

- (id) init {
    self = [super init];

    if (self) {
#ifdef DEBUG
        NSLog(@"Allocated ZMachine object");
#endif
        display = nil;
        machineFile = NULL;

        inputBuffer = [[NSMutableString allocWithZone: [self zone]] init];

        windows[0] = windows[1] = windows[2] = nil;

        int x;
        for(x=0; x<3; x++) {
            windowBuffer[x] = [[NSMutableAttributedString alloc] init];
        }
    }

    return self;
}

- (void) dealloc {
#ifdef DEBUG
    NSLog(@"Deallocated ZMachine object");
#endif

    if (windows[0])
        [windows[0] release];
    if (windows[1])
        [windows[1] release];
    if (windows[2])
        [windows[2] release];

    int x;
    for (x=0; x<3; x++) {
        [windowBuffer[x] release];
    }

    [display release];
    [inputBuffer release];

    mainMachine = nil;

    if (machineFile) {
        close_file(machineFile);
    }
    
    [super dealloc];
}

- (NSString*) description {
    return @"Zoom 1.0.2 ZMachine object";
}

// = Setup =
- (void) loadStoryFile: (NSData*) storyFile {
    // Create the machine file
#ifdef DEBUG
    NSLog(@"Loading story file...");
#endif

    ZDataFile* file = [[ZDataFile alloc] initWithData: storyFile];
    machineFile = open_file_from_object([file autorelease]);
}

- (BOOL) loadResourcesFromData: (in bycopy NSData*) resources {
}

- (BOOL) loadResourcesFromFile: (in bycopy NSFileHandle*) file {
}

- (BOOL) loadResourcesFromZFile: (in byref NSObject<ZFile>) file {
}

// = Running =
- (void) startRunningInDisplay: (in byref NSObject<ZDisplay>*) disp {
    NSAutoreleasePool* mainPool = [[NSAutoreleasePool alloc] init];
#ifdef DEBUG
    NSLog(@"Started running");
#endif
    /*
    {
        int x;
        for (x=0; x<10; x++) {
            NSLog(@"...%i...", x);
            sleep(1);
        }
    }
     */
    
    display = [disp retain];

    // OK, we can now set up the ZMachine and get running

    // RNG
    struct timeval tv;
    gettimeofday(&tv, NULL);
    random_seed(tv.tv_sec^tv.tv_usec);

    // Options
    rc_load();

    // Load the story
    machine.story_length = get_size_of_file(machineFile);
    zmachine_load_file(machineFile, &machine);

    // Setup the display
    windows[0] = NULL;
    windows[1] = NULL;
    windows[2] = NULL;

    // Cycle the autorelease pool
    displayPool = [[NSAutoreleasePool alloc] init];
    
    switch (machine.header[0]) {
        case 3:
            // Status window

        case 4:
        case 5:
        case 7:
        case 8:
            // Upper/lower window
            windows[0] = [[display createLowerWindow] retain];
            windows[1] = [[display createUpperWindow] retain];
            windows[2] = [[display createUpperWindow] retain];
            break;

        case 6:
            // Implement me
            break;
    }

    int x;
    for (x=0; x<3; x++) {
        [windows[x] setProtocolForProxy: @protocol(ZVendor)];
    }

    // Setup the display, etc
    rc_set_game(zmachine_get_serial(), Word(ZH_release), Word(ZH_checksum));
    display_initialise();

    // Start running the machine
    int version = 0;
    
    switch (machine.header[0])
    {
#ifdef SUPPORT_VERSION_3
        case 3:
            display_split(1, 1);

            display_set_colour(0, 7); display_set_font(0);
            display_set_window(0);
            zmachine_run(3, NULL);
            break;
#endif
#ifdef SUPPORT_VERSION_4
        case 4:
            zmachine_run(4, NULL);
            break;
#endif
#ifdef SUPPORT_VERSION_5
        case 5:
            zmachine_run(5, NULL);
            break;
        case 7:
            zmachine_run(7, NULL);
            break;
        case 8:
            zmachine_run(8, NULL);
            break;
#endif
#ifdef SUPPORT_VERSION_6
        case 6:
            v6_startup();
            v6_set_cursor(1,1);
            zmachine_run(6, NULL);
            break;
#endif

        default:
            zmachine_fatal("Unsupported ZMachine version %i", machine.header[0]);
            break;
    }
}

// = Debugging =
- (NSData*) staticMemory {
}

// = Recieving text/characters =
- (void) inputText: (NSString*) text {
    [inputBuffer appendString: text];
}

- (void) inputChar: (int) character {
}

// = Our own functions =
- (NSObject<ZWindow>*) windowNumber: (int) num {
    if (num < 0 || num > 2) {
        NSLog(@"*** BUG - window %i does not exist", num);
        return nil;
    }
    
    return windows[num];
}

- (NSObject<ZDisplay>*) display {
    return display;
}

- (NSMutableString*) inputBuffer {
    return inputBuffer;
}

// = Output buffering (mark II, over the stream stuff) =
- (void) appendAttributedString: (NSAttributedString*) str
                       toWindow: (int) window {
    [windowBuffer[window] appendAttributedString: str];
    if ([windowBuffer[window] length] > 4096) {
        [self flushBufferForWindow: window];
    }
}

- (void) flushBufferForWindow: (int) window {
    [windows[window] writeString: windowBuffer[window]];
    [windowBuffer[window] release];
    windowBuffer[window] = [[NSMutableAttributedString alloc] init];
}

- (void) clearBufferForWindow: (int) window {
    [windowBuffer[window] release];
    windowBuffer[window] = [[NSMutableAttributedString alloc] init];
}

@end

// Various Zoom C functions (not yet implemented elsewhere)
#include "file.h"
#include "display.h"

// = V6 display =

extern int   display_init_pixmap    (int width, int height) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern void  display_plot_rect      (int x, int y,
                                     int width, int height) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern void  display_scroll_region   (int x, int y,
                                      int width, int height,
                                      int xoff, int yoff) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern void  display_pixmap_cols     (int fg, int bg) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern int   display_get_pix_colour  (int x, int y) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern void  display_plot_gtext      (const int* buf, int len,
                                      int style, int x, int y) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern void  display_plot_image      (BlorbImage* img, int x, int y) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern float display_measure_text    (const int* buf, int len, int style) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern float display_get_font_width  (int style) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern float display_get_font_height (int style) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern float display_get_font_ascent (int style) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern float display_get_font_descent(int style) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern void  display_wait_for_more   (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

extern void  display_read_mouse      (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern int   display_get_pix_mouse_b (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern int   display_get_pix_mouse_x (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
extern int   display_get_pix_mouse_y (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

extern void  display_set_input_pos   (int style, int x, int y, int width) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
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
