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
    va_list  ap;
    char     string[8192];

    va_start(ap, format);
    vsprintf(string, format, ap);
    va_end(ap);

    fputs(string, stdout);
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

    int xsize, ysize;
    [[mainMachine display] dimensionX: &xsize
                                    Y: &ysize];

    dis.lines         = ysize;
    dis.columns       = xsize;
    dis.width         = xsize;
    dis.height        = ysize;
    
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

    display_clear();
}

void display_reinitialise(void) {
    if (currentStyle) [currentStyle release];
    currentStyle = [[ZStyle alloc] init];

    display_clear();
}

void display_finalise(void) {
    [mainMachine flushBuffers];
    NSLog(@"Display finalised");
    if (currentStyle) [currentStyle release];
    currentStyle = nil;
}

void display_exit(int code) {
    [mainMachine flushBuffers];
    NSLog(@"Server exited with code %i (clean)", code);
    exit(code);
}

// Clearing/erasure functions
void display_clear(void) {
    NSObject<ZWindow>* win;
    
    NSLog(@"clear...");

    currentWindow = 0;

    [mainMachine flushBuffers];

    win = [mainMachine windowNumber: 1];
    [win clearWithStyle: currentStyle];
    [(NSObject<ZUpperWindow>*)win startAtLine: 0];
    [(NSObject<ZUpperWindow>*)win endAtLine: 0];

    win = [mainMachine windowNumber: 2];
    [win clearWithStyle: currentStyle];
    [(NSObject<ZUpperWindow>*)win startAtLine: 0];
    [(NSObject<ZUpperWindow>*)win endAtLine: 0];
    
    win = [mainMachine windowNumber: 0];
    [win clearWithStyle: currentStyle];
}

void display_erase_window(void) {
    [[mainMachine buffer] clearWindow: [mainMachine windowNumber: currentWindow]
                            withStyle: currentStyle];
    //[mainMachine flushBuffers];
    //[[mainMachine windowNumber: currentWindow] clearWithStyle: currentStyle];
}

void display_erase_line(int val) {
    [[mainMachine buffer] eraseLineInWindow: [mainMachine windowNumber: currentWindow]
                                  withStyle: currentStyle];
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
    [[mainMachine buffer] writeString: str
                            withStyle: currentStyle
                             toWindow: [mainMachine windowNumber: currentWindow]];
    /*
    [[mainMachine windowNumber: currentWindow] writeString: str
                                                 withStyle: currentStyle];
     */
}

void display_prints_c(const char* buf) {
    NSString* str = [NSString stringWithCString: buf];
    [[mainMachine buffer] writeString: str
                            withStyle: currentStyle
                             toWindow: [mainMachine windowNumber: currentWindow]];
}

void display_printc(int chr) {
    unichar bufU[1];

    bufU[0] = chr;

    NSString* str = [NSString stringWithCharacters: bufU
                                            length: 1];
    [[mainMachine buffer] writeString: str
                            withStyle: currentStyle
                             toWindow: [mainMachine windowNumber: currentWindow]];
}

void display_printf(const char* format, ...) {
    va_list  ap;
    char     string[512];

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

    NSDate* when;

    if (timeout > 0) {
        when = [NSDate dateWithTimeIntervalSinceNow: ((double)timeout)/1000.0];
    } else {
        when = [NSDate distantFuture];
    }

    [when retain];
    
    // Wait for input
    while (mainMachine != nil &&
           [[mainMachine inputBuffer] length] == 0 &&
           [when compare: [NSDate date]] == NSOrderedDescending) {
        // Cycle the autorelease pool
        [displayPool release];
        displayPool = [[NSAutoreleasePool alloc] init];
        
        [mainLoop acceptInputForMode: NSDefaultRunLoopMode
                          beforeDate: [NSDate distantFuture]];
    }

    [when release];

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
    int termChar = 0;

    for (chr = 0; chr<realLen; chr++) {
        buf[chr] = [inputBuffer characterAtIndex: chr];

        if (buf[chr] == 10 ||
            buf[chr] == 13) {
            realLen = chr;
            termChar = 10;

            [inputBuffer deleteCharactersInRange: NSMakeRange(chr, 1)];
            break;
        }
    }

    buf[realLen] = 0;

    [inputBuffer deleteCharactersInRange: NSMakeRange(0, realLen)];

    return termChar;
}

int display_readchar(long int timeout) {
    [mainMachine flushBuffers];

    NSObject<ZDisplay>* display = [mainMachine display];

    // Cycle the autorelease pool
    [displayPool release];
    displayPool = [[NSAutoreleasePool alloc] init];

    // Request input
    [[mainMachine inputBuffer] setString: @""];

    [display shouldReceiveCharacters];
    [[mainMachine windowNumber: currentWindow] setFocus];

    NSDate* when;

    if (timeout > 0) {
        when = [NSDate dateWithTimeIntervalSinceNow: ((double)timeout)/1000.0];
    } else {
        when = [NSDate distantFuture];
    }

    [when retain];

    // Wait for input
    while (mainMachine != nil &&
           [[mainMachine inputBuffer] length] == 0 &&
           [when compare: [NSDate date]] == NSOrderedDescending) {
        [mainLoop acceptInputForMode: NSDefaultRunLoopMode
                          beforeDate: when];
    }

    [when release];

    // Cycle the autorelease pool
    [displayPool release];
    displayPool = [[NSAutoreleasePool alloc] init];

    // Finish up
    [display stopReceiving];

    // Copy the data
    unichar theChar;
    
    if ([[mainMachine inputBuffer] length] == 0) {
        theChar = 0; // Timeout occured
    } else {
        NSMutableString* inputBuffer = [mainMachine inputBuffer];
        theChar = [inputBuffer characterAtIndex: 0];
    }

    return theChar;
}

// = Used by the debugger =
void display_sanitise  (void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_desanitise(void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_is_v6(void) { NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); }

int display_set_font(int font) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
    return 0;
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
        [newStyle setReversed: NO];

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

static NSColor* getTrue(int col) {
    double r,g,b;

    r = ((double)(col&0x1f))/31.0;
    g = ((double)(col&0x3e0))/992.0;
    b = ((double)(col&0x7c00))/31744.0;

    return [NSColor colorWithDeviceRed: r
                                 green: g
                                  blue: b
                                 alpha: 1.0];
}

void display_set_colour(int fore, int back) {
    currentStyle = [[currentStyle autorelease] copy];

    if (fore == -1) fore = 0;
    if (back == -1) back = 7;
    
    if (fore < 16) {
        if (fore >= 0) {
            [currentStyle setForegroundTrue: nil];
            [currentStyle setForegroundColour: fore];
        }
    } else {
        [currentStyle setForegroundTrue: getTrue(fore)];
    }

    if (back < 16) {
        if (back >= 0) {
            [currentStyle setBackgroundTrue: nil];
            [currentStyle setBackgroundColour: back];
        }
    } else {
        [currentStyle setBackgroundTrue: getTrue(back)];
    }
}

void display_split(int lines, int window) {
    // IMPLEMENT ME: window 2
    [[mainMachine buffer] setWindow: [mainMachine windowNumber: window]
                          startLine: 0
                            endLine: lines];
}

void display_join(int win1, int win2) {
    // IMPLEMENT ME: window 2
    [[mainMachine buffer] setWindow: [mainMachine windowNumber: win2]
                          startLine: 0
                            endLine: 0];

    /*
    [mainMachine flushBuffers];
    [[mainMachine windowNumber: win2] clearWithStyle: currentStyle];
     */
}

void display_set_window(int window) {
    currentWindow = window;
}

int  display_get_window(void) {
    return currentWindow;
}

void display_set_cursor(int x, int y) {
    if (currentWindow > 0) {
        [[mainMachine buffer] moveTo: NSMakePoint(x,y)
                            inWindow: [mainMachine windowNumber: currentWindow]];
    }
}

int display_get_cur_x(void) {
    if (currentWindow == 0) {
        NSLog(@"Get_cur_x called for lower window");
        return -1; // No cursor position for the lower window
    }

    [mainMachine flushBuffers];
    
    NSPoint pos = [(NSObject<ZUpperWindow>*)[mainMachine windowNumber: currentWindow]
        cursorPosition];
    return pos.x;
}

int display_get_cur_y(void) {
    if (currentWindow == 0) {
        NSLog(@"Get_cur_y called for lower window");
        return -1; // No cursor position for the lower window
    }

    [mainMachine flushBuffers];

    NSPoint pos = [(NSObject<ZUpperWindow>*)[mainMachine windowNumber: currentWindow]
        cursorPosition];
    return pos.y;
}

void display_force_fixed (int window, int val) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_terminating (unsigned char* table) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

int  display_get_mouse_x(void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
    return 0;
}

int display_get_mouse_y(void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
    return 0;
}

void display_set_title(const char* title) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_update(void) {
    [mainMachine flushBuffers];
}

void display_beep(void) {
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

// = Getting files =
static ZFileType convert_file_type(ZFile_type typein) {
    switch (typein) {
        case ZFile_save:
            return ZFileQuetzal;
            
        case ZFile_data:
            return ZFileData;
            
        case ZFile_transcript:
            return ZFileTranscript;
            
        case ZFile_recording:
            return ZFileRecording;
            
        default:
            return ZFileData;
    }
}

static void wait_for_file(void) {
    [mainMachine flushBuffers];
        
    while (mainMachine != nil &&
           ![mainMachine filePromptFinished]) {
        [mainLoop acceptInputForMode: NSDefaultRunLoopMode
                          beforeDate: [NSDate distantFuture]];
    }
}

ZFile* get_file_write(int* size, char* name, ZFile_type purpose) {
    // FIXME: fill in size
    NSObject<ZFile>* res = NULL;
    
    [mainMachine filePromptStarted];
    [[mainMachine display] promptForFileToWrite: convert_file_type(purpose)
                                    defaultName: [NSString stringWithCString: name]];
    
    wait_for_file();
    res = [[mainMachine lastFile] retain];
    [mainMachine clearFile];

    if (res) {
        if (size) *size = [mainMachine lastSize];
        return open_file_from_object([res autorelease]);
    } else {
        if (size) *size = -1;
        return NULL;
    }
}

ZFile* get_file_read(int* size, char* name, ZFile_type purpose) {
    NSObject<ZFile>* res = NULL;
    
    [mainMachine filePromptStarted];
    [[mainMachine display] promptForFileToRead: convert_file_type(purpose)
                                   defaultName: [NSString stringWithCString: name]];
    
    wait_for_file();
    res = [[mainMachine lastFile] retain];
    [mainMachine clearFile];

    if (res) {
        if (size) *size = [mainMachine lastSize];
        return open_file_from_object([res autorelease]);
    } else {
        if (size) *size = -1;
        return NULL;
    }
}
