//
//  ZDisplay.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ZoomProtocol.h"
#import "ZoomZMachine.h"
#import "ZoomServer.h"

#include "file.h"
#include "display.h"

// = Display state =
NSAutoreleasePool* displayPool = nil;

static int currentWindow = 0;

// = Display =

// Debugging functions
void printf_debug(char* format, ...) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}
void printf_info (char* format, ...) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}
void printf_info_done(void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}
void printf_error(char* format, ...) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}
void printf_error_done(void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

ZDisplay* display_get_info(void) {
    static ZDisplay dis;

    dis.status_line   = 1;
    dis.can_split     = 1;
    dis.variable_font = 1;
    dis.colours       = 1;
    dis.boldface      = 1;
    dis.italic        = 1;
    dis.fixed_space   = 1;
    dis.sound_effects = 0;
    dis.timed_input   = 1;
    dis.mouse         = 0;

    dis.lines         = 25; // IMPLEMENT ME: get from server
    dis.columns       = 80;
    dis.width         = 80;
    dis.height        = 25;
    
    dis.font_width    = 1;
    dis.font_height   = 1;
    dis.pictures      = 1;
    dis.fore          = 0; // Implement me: make configurable
    dis.back          = 7; // Implement me: make configurable

    /*
    col               = maccolour[FIRST_ZCOLOUR+DEFAULT_FORE];
    dis.fore_true     = (col.red>>11)|((col.green>>11)<<5)|((col.blue>>11)<<10);
    col               = maccolour[FIRST_ZCOLOUR+DEFAULT_BACK];
    dis.back_true     = (col.red>>11)|((col.green>>11)<<5)|((col.blue>>11)<<10);

     if (pixmap != NULL)
     {
         dis.width = pix_w;
         dis.height = pix_h;

         dis.font_width = xfont_get_width(font[style_font[4]])+0.5;
         dis.font_height = xfont_get_height(font[style_font[4]])+0.5;
    }
    */
    return &dis;
}

void display_initialise(void) {
    // Do nothing for the moment
}

void display_reinitialise(void) {
    // Do nothing for the moment
}

void display_finalise(void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_exit(int code) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);

    exit(code);
}

// Clearing/erasure functions
void display_clear(void) {
    NSObject<ZWindow>* win;

    currentWindow = 0;

    win = [mainMachine windowNumber: 1];
    [win clear];
    [(NSObject<ZUpperWindow>*)win startAtLine: -1];
    [(NSObject<ZUpperWindow>*)win endAtLine: -1];

    win = [mainMachine windowNumber: 2];
    [win clear];
    [(NSObject<ZUpperWindow>*)win startAtLine: -1];
    [(NSObject<ZUpperWindow>*)win endAtLine: -1];
    
    win = [mainMachine windowNumber: 0];
    [win clear];

    int x;
    for (x=0; x<3; x++) [mainMachine clearBufferForWindow: x];
}

void display_erase_window(void) {
    [mainMachine clearBufferForWindow: currentWindow];
    [[mainMachine windowNumber: currentWindow] clear];
}

void display_erase_line(int val) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

// Display functions
static inline NSAttributedString* makeAttributed(NSString* str) {
    NSAttributedString* as = [[NSAttributedString alloc] initWithString: str];
    return [as autorelease];
}

void display_prints(const int* buf) {
    // Convert buf to an NSString
    int length;
    static unichar* bufU = NULL;

    for (length=0; buf[length] != 0; length++) {
        bufU = realloc(bufU, sizeof(unichar)*((length>>4)+1)<<4);
        bufU[length] = buf[length];
    }

    NSString* str = [NSString stringWithCharacters: bufU
                                            length: length];

    // Send to the window
    [mainMachine appendAttributedString: makeAttributed(str)
                              toWindow: currentWindow];
}

void display_prints_c(const char* buf) {
    NSString* str = [NSString stringWithCString: buf];
    [mainMachine appendAttributedString: makeAttributed(str)
                              toWindow: currentWindow];
}

void display_printc(int chr) {
    unichar bufU[1];

    bufU[0] = chr;

    NSString* str = [NSString stringWithCharacters: bufU
                                            length: 1];
    [mainMachine appendAttributedString: makeAttributed(str)
                              toWindow: currentWindow];
}

void display_printf(const char* format, ...) {
    va_list  ap;
    char     string[512];
    int x,len;
    int      istr[512];

    va_start(ap, format);
    vsprintf(string, format, ap);
    va_end(ap);

    display_prints_c(string);
}

// Input
int display_readline(int* buf, int len, long int timeout) {
    NSObject<ZDisplay>* display = [mainMachine display];

    // Flush window buffers
    int x;
    for (x=0; x<3; x++) [mainMachine flushBufferForWindow: x];

    // Cycle the autorelease pool
    [displayPool release];
    displayPool = [[NSAutoreleasePool alloc] init];

    // Request input
    [[mainMachine inputBuffer] setString: @""];
    
    [display shouldReceiveText: len];
    [[mainMachine windowNumber: currentWindow] setFocus];

    // Wait for input
    // FIXME: timeouts
    while (mainMachine != nil &&
           [[mainMachine inputBuffer] length] == 0) {
        [mainLoop acceptInputForMode: NSDefaultRunLoopMode
                          beforeDate: [NSDate distantFuture]];
    }

    // Cycle the autorelease pool
    [displayPool release];
    displayPool = [[NSAutoreleasePool alloc] init];
    
    // Finish up
    [display stopReceiving];

    // Copy the data
    NSMutableString* inputBuffer = [mainMachine inputBuffer];
    
    int realLen = [inputBuffer length];
    if (realLen > (len-1)) {
        realLen = len-1;
    }

    int chr;

    for (chr = 0; chr<realLen; chr++) {
        buf[chr] = [inputBuffer characterAtIndex: chr];

        if (buf[chr] == 10 ||
            buf[chr] == 13) {
            realLen = chr;
            buf[chr++] = 0;

            [inputBuffer deleteCharactersInRange: NSMakeRange(chr-1, 1)];
            break;
        }
    }

    [inputBuffer deleteCharactersInRange: NSMakeRange(0, realLen)];

    return realLen;
}

int  display_readchar(long int timeout) {
    // Flush window buffers
    int x;
    for (x=0; x<3; x++) [mainMachine flushBufferForWindow: x];

    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

// = Used by the debugger =
void display_sanitise  (void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}
void display_desanitise(void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_is_v6(void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

int  display_set_font    (int font) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
int  display_set_style   (int style) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void display_set_colour  (int fore, int back) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

void display_split(int lines, int window) {
    NSObject<ZUpperWindow>* win = [mainMachine windowNumber: window];

    if ([win conformsToProtocol: @protocol(ZUpperWindow)]) {
        // IMPLEMENT ME: window 2
        [win startAtLine: 0];
        [win endAtLine: lines];
    }
}

void display_join(int win1, int win2) {
    NSObject<ZUpperWindow>* win = [mainMachine windowNumber: win2];

    if ([win conformsToProtocol: @protocol(ZUpperWindow)]) {
        // IMPLEMENT ME: window 2
        [win startAtLine: 0];
        [win endAtLine: 0];
    }
}

void display_set_window(int window) {
    currentWindow = window;
    NSLog(@"Switching to window %i", currentWindow);

    [[mainMachine windowNumber: window] setFocus];
}

int  display_get_window(void) {
    return currentWindow;
}

void display_set_cursor  (int x, int y) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
int  display_get_cur_x   (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
int  display_get_cur_y   (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void display_force_fixed (int window, int val) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

void display_terminating (unsigned char* table) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
int  display_get_mouse_x (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
int  display_get_mouse_y (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

void display_set_title(const char* title) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void display_update   (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void display_beep     (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
