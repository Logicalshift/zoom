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
static ZStyle* currentStyle = nil;

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
    if (currentStyle) [currentStyle release];
    currentStyle = [[ZStyle alloc] init];
}

void display_reinitialise(void) {
    if (currentStyle) [currentStyle release];
    currentStyle = [[ZStyle alloc] init];
}

void display_finalise(void) {
    if (currentStyle) [currentStyle release];
    currentStyle = nil;
}

void display_exit(int code) {
    exit(code);
}

// Clearing/erasure functions
void display_clear(void) {
    NSObject<ZWindow>* win;

    currentWindow = 0;

    [mainMachine flushBuffers];

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
}

void display_erase_window(void) {
    [mainMachine flushBuffers];
    [[mainMachine windowNumber: currentWindow] clear];
}

void display_erase_line(int val) {
    [mainMachine flushBuffers];
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

// Display functions
void display_prints(const int* buf) {
    // Convert buf to an NSString
    int length;
    static unichar* bufU = NULL;

    for (length=0; buf[length] != 0; length++) {
        bufU = realloc(bufU, sizeof(unichar)*((length>>4)+1)<<4);
        bufU[length] = buf[length];
    }

    if (length == 0) return;

    NSString* str = [NSString stringWithCharacters: bufU
                                            length: length];

    // Send to the window
    [mainMachine bufferString: str
                    forWindow: currentWindow
                    withStyle: currentStyle];
    /*
    [[mainMachine windowNumber: currentWindow] writeString: str
                                                 withStyle: currentStyle];
     */
}

void display_prints_c(const char* buf) {
    NSString* str = [NSString stringWithCString: buf];
    [mainMachine bufferString: str
                    forWindow: currentWindow
                    withStyle: currentStyle];
    //[[mainMachine windowNumber: currentWindow] writeString: str
    //                                             withStyle: currentStyle];
}

void display_printc(int chr) {
    unichar bufU[1];

    bufU[0] = chr;

    NSString* str = [NSString stringWithCharacters: bufU
                                            length: 1];
    [mainMachine bufferString: str
                    forWindow: currentWindow
                    withStyle: currentStyle];
    //[[mainMachine windowNumber: currentWindow] writeString: str
    //                                             withStyle: currentStyle];
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
    [mainMachine flushBuffers];
    
    NSObject<ZDisplay>* display = [mainMachine display];

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
    [mainMachine flushBuffers];
    
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

int  display_set_font(int font) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

int display_set_style(int style) {
    // Copy the old style
    ZStyle* newStyle = [currentStyle copy];

    int oldStyle =
        ([newStyle reversed]?1:0)|
        ([newStyle bold]?2:0)|
        ([newStyle underline]?4:0)|
        ([newStyle fixed]?8:0)|
        ([newStyle symbolic]?16:0);
    
    // Not using this any more
    if (currentStyle) [currentStyle release];

    BOOL flag = (style<0)?NO:YES;
    if (style < 0) style = -style;
     
    // Set the flags
    if (style == 0) {
        [newStyle setBold: NO];
        [newStyle setUnderline: NO];
        [newStyle setFixed: NO];
        [newStyle setSymbolic: NO];

        currentStyle = newStyle;
        return oldStyle;
    }

    if (style&1)  [newStyle setReversed: flag];
    if (style&2)  [newStyle setBold: flag];
    if (style&4)  [newStyle setUnderline: flag];
    if (style&8)  [newStyle setFixed: flag];
    if (style&16) [newStyle setSymbolic: flag];

    // Set as the current style
    currentStyle = newStyle;

    return oldStyle;
}

void display_set_colour  (int fore, int back) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

void display_split(int lines, int window) {
    [mainMachine flushBuffers];

    NSObject<ZUpperWindow>* win = [mainMachine windowNumber: window];

    if ([win conformsToProtocol: @protocol(ZUpperWindow)]) {
        // IMPLEMENT ME: window 2
        [win startAtLine: 0];
        [win endAtLine: lines];
    }
}

void display_join(int win1, int win2) {
    [mainMachine flushBuffers];
    
    NSObject<ZUpperWindow>* win = [mainMachine windowNumber: win2];

    if ([win conformsToProtocol: @protocol(ZUpperWindow)]) {
        // IMPLEMENT ME: window 2
        [win startAtLine: 0];
        [win endAtLine: 0];
    }
}

void display_set_window(int window) {
    currentWindow = window;
}

int  display_get_window(void) {
    return currentWindow;
}

void display_set_cursor(int x, int y) {
    if (currentWindow > 0) {
        [mainMachine bufferMovement: NSMakePoint(x,y)
                          forWindow: currentWindow];
        /*
        [mainMachine flushBuffers];
        NSObject<ZUpperWindow>* win = [mainMachine windowNumber: currentWindow];
        [win setCursorPositionX: x Y: y];
         */
    }
}

int  display_get_cur_x   (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
int  display_get_cur_y   (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void display_force_fixed (int window, int val) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

void display_terminating (unsigned char* table) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
int  display_get_mouse_x (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
int  display_get_mouse_y (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

void display_set_title(const char* title) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void display_update   (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
void display_beep     (void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }
