//
//  ZDisplay.m
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

#ifdef DEBUG
# define NOTE(x) NSLog(@"ZDisplay: %@", x)
#else
# define NOTE(x)
#endif

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
	
	NOTE(@"display_get_info");
	
    return &dis;
}

void display_initialise(void) {
	NOTE(@"display_initialise");

	if (currentStyle) [currentStyle release];
    currentStyle = [[ZStyle alloc] init];

    //display_clear(); (Commented out to support autosave)
}

void display_reinitialise(void) {
	NOTE(@"display_reinitialise");
	
    if (currentStyle) [currentStyle release];
    currentStyle = [[ZStyle alloc] init];

    display_clear();
}

void display_finalise(void) {
	NOTE(@"display_finalise");
	
    [mainMachine flushBuffers];
    if (currentStyle) [currentStyle release];
    currentStyle = nil;
}

void display_exit(int code) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_exit(%i)", code);
#endif
	
    [mainMachine flushBuffers];
    NSLog(@"Server exited with code %i (clean)", code);
    exit(code);
}

// Clearing/erasure functions
void display_clear(void) {
    NSObject<ZWindow>* win;
	
	NOTE(@"display_clear");
    
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
	NOTE(@"display_erase_window");
	
    [[mainMachine buffer] clearWindow: [mainMachine windowNumber: currentWindow]
                            withStyle: currentStyle];
    //[mainMachine flushBuffers];
    //[[mainMachine windowNumber: currentWindow] clearWithStyle: currentStyle];
}

void display_erase_line(int val) {
	NOTE(@"display_erase_line");
	
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
	
#ifdef DEBUG
	NSLog(@"ZDisplay: display_prints(\"%@\")", str);
#endif

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
#ifdef DEBUG
	NSLog(@"ZDisplay: display_prints_c(\"%s\")", buf);
#endif
	
	if ([mainMachine windowNumber: currentWindow] == nil) {
		NSLog(@"No window: leaking '%s'", buf);
		return;
	}
	
    NSString* str = [NSString stringWithCString: buf];
    [[mainMachine buffer] writeString: str
                            withStyle: currentStyle
                             toWindow: [mainMachine windowNumber: currentWindow]];
}

void display_printc(int chr) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_printc(\"%c\")", chr);
#endif
	
	if ([mainMachine windowNumber: currentWindow] == nil) {
		NSLog(@"No window: leaking '%c'", chr);
		return;
	}

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
	
	NOTE(@"display_printf");

    va_start(ap, format);
    vsprintf(string, format, ap);
    va_end(ap);

    display_prints_c(string);
}

// Input
int display_readline(int* buf, int len, long int timeout) {
	NOTE(@"display_readline");
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

#ifdef DEBUG
	NSLog(@"ZDisplay: display_readline = %@", inputBuffer);
#endif

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
	NOTE(@"display_readchar");
	
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

#ifdef DEBUG
	NSLog(@"ZDisplay: display_readchar = %i", theChar);
#endif
	
    return theChar;
}

// = Used by the debugger =
void display_sanitise  (void) {
	NOTE(@"display_santise");
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_desanitise(void) {
	NOTE(@"display_desanitise");
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_is_v6(void) { 
	NOTE(@"display_is_v6");
	NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__); 
}

int display_set_font(int font) {
	NOTE(@"display_set_font");
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
    return 0;
}

int display_set_style(int style) {
	NOTE(@"display_set_style");
	
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
#ifdef DEBUG
	NSLog(@"ZDisplay: display_set_colour(%i, %i)", fore, back);
#endif
	
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
#ifdef DEBUG
	NSLog(@"ZDisplay: display_split(%i, %i)", lines, window);
#endif

    // IMPLEMENT ME: window 2
    [[mainMachine buffer] setWindow: [mainMachine windowNumber: window]
                          startLine: 0
                            endLine: lines];
}

void display_join(int win1, int win2) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_join(%i, %i)", win1, win2);
#endif
	
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
#ifdef DEBUG
	NSLog(@"ZDisplay: display_set_window(%i)", window);
#endif

    currentWindow = window;
}

int  display_get_window(void) {
	NOTE(@"display_get_window");
    return currentWindow;
}

void display_set_cursor(int x, int y) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_set_cursor(%i, %i)", x, y);
#endif

    if (currentWindow > 0) {
        [[mainMachine buffer] moveTo: NSMakePoint(x,y)
                            inWindow: [mainMachine windowNumber: currentWindow]];
    }
}

int display_get_cur_x(void) {
	NOTE(@"display_get_cur_x");
	
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
	NOTE(@"display_get_cur_y");
	
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
	NOTE(@"display_force_fixed");
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_terminating (unsigned char* table) {
	NOTE(@"display_terminating");
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

int  display_get_mouse_x(void) {
	NOTE(@"display_get_mouse_x");
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
    return 0;
}

int display_get_mouse_y(void) {
	NOTE(@"display_get_mouse_y");
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
    return 0;
}

void display_set_title(const char* title) {
	NOTE(@"display_set_title");
    NSLog(@"Function not implemented: %s %i", __FILE__, __LINE__);
}

void display_update(void) {
	NOTE(@"display_update");
    [mainMachine flushBuffers];
}

void display_beep(void) {
	NOTE(@"display_beep");
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
