/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * Protocol for an application to talk to/from Zoom
 */

#import <Cocoa/Cocoa.h>

@protocol ZMachine;
@protocol ZDisplay;
@protocol ZFile;
@class ZStyle;
@class ZBuffer;

typedef enum {
    ZFileQuetzal,
    ZFileTranscript,
    ZFileRecording,
    ZFileData
} ZFileType;

// == Server-side objects ==
@protocol ZVendor
- (out byref NSObject<ZMachine>*) createNewZMachine;
@end

@protocol ZMachine

// Setup
- (void) loadStoryFile: (in bycopy NSData*) storyFile;
- (BOOL) loadResourcesFromData: (in bycopy NSData*) resources;
- (BOOL) loadResourcesFromFile: (in bycopy NSFileHandle*) file;
- (BOOL) loadResourcesFromZFile: (in byref NSObject<ZFile>*) file;

// Running
- (oneway void) startRunningInDisplay: (in byref NSObject<ZDisplay>*) display;

// Debugging
- (out bycopy NSData*) staticMemory;

// Recieving text/characters
- (oneway void) inputText: (in bycopy NSString*) text;
- (oneway void) inputMouseAtPositionX: (int) x
                                    Y: (int) y;

- (void) displaySizeHasChanged;

// Recieving files
- (oneway void) filePromptCancelled;
- (oneway void) promptedFileIs: (in byref NSObject<ZFile>*) file
                          size: (int) size;
@end

// == Client-side objects ==
@protocol ZFile
- (out int)            readByte;
- (out unsigned int)   readWord;
- (out unsigned int)   readDWord;
- (out bycopy NSData*) readBlock: (int) length;

- (oneway void)        seekTo: (int) pos;

- (oneway void) writeByte:  (int) byte;
- (oneway void) writeWord:  (int) word;
- (oneway void) writeDWord: (unsigned int) dword;
- (oneway void) writeBlock: (in bycopy NSData*) block;

- (out BOOL)                sufferedError;
- (out bycopy NSString*)    errorMessage;

- (out int)                 fileSize;

- (oneway void)             close;
@end

@protocol ZWindow
// General Z-Machine window protocol (all windows should have this and another
// protocol)

// Clears the window
- (oneway void) clearWithStyle: (in bycopy ZStyle*) style;

// Sets the input focus to this window
- (oneway void) setFocus;

// Sending data to a window
- (oneway void) writeString: (in bycopy NSString*) string
                  withStyle: (in bycopy ZStyle*) style;
@end

@protocol ZUpperWindow<ZWindow>
// Functions supported by an upper window

// Size (-1 to indicate an unsplit window)
- (oneway void) startAtLine: (int) line;
- (oneway void) endAtLine:   (int) line;

// Cursor positioning
- (oneway void) setCursorPositionX: (in int) xpos
                                 Y: (in int) ypos;
- (NSPoint) cursorPosition;

// Line erasure
- (oneway void) eraseLineWithStyle: (in bycopy ZStyle*) style;
@end

@protocol ZLowerWindow<ZWindow>
@end

@protocol ZDisplay
// Overall display functions

// Display information
- (void) dimensionX: (out int*) xSize
                  Y: (out int*) ySize;

// Functions to create the standard windows
- (out byref NSObject<ZLowerWindow>*) createLowerWindow;
- (out byref NSObject<ZUpperWindow>*) createUpperWindow;

// Requesting user input from
- (void)		shouldReceiveCharacters;
- (void)		shouldReceiveText: (in int) maxLength;
- (void)        stopReceiving;

- (oneway void) setTerminatingCharacters: (in bycopy NSArray*) characters;

// 'Exclusive' mode - lock the UI so no updates occur while we're sending
// large blocks of varied text
- (oneway void) startExclusive;
- (oneway void) stopExclusive;
- (void) flushBuffer: (in bycopy ZBuffer*) toFlush;

// Prompting for files
- (void) promptForFileToWrite: (in ZFileType) type
                                         defaultName: (in bycopy NSString*) name;
- (void) promptForFileToRead: (in ZFileType) type
                 defaultName: (in bycopy NSString*) name;

// Error messages and warnings
- (void) displayFatalError: (in bycopy NSString*) error;
- (void) displayWarning:    (in bycopy NSString*) warning;
@end

// Some useful standard classes
@interface ZHandleFile : NSObject<ZFile> {
    NSFileHandle* handle;
}

- (id) initWithFileHandle: (NSFileHandle*) handle;
@end

@interface ZDataFile : NSObject<ZFile> {
    NSData* data;
    int pos;
}

- (id) initWithData: (NSData*) data;
@end

// Style attributes
extern NSString* ZStyleAttributeName;
@interface ZStyle : NSObject<NSCopying,NSCoding> {
    // Colour
    int foregroundColour;
    int backgroundColour;
    NSColor* foregroundTrue;
    NSColor* backgroundTrue;

    // Style
    BOOL isReversed;
    BOOL isFixed;
    BOOL isBold;
    BOOL isUnderline;
    BOOL isSymbolic;
}

- (void) setForegroundColour: (int) zColour;
- (void) setBackgroundColour: (int) zColour;
- (void) setForegroundTrue:   (NSColor*) colour;
- (void) setBackgroundTrue:   (NSColor*) colour;
- (void) setFixed:            (BOOL) fixed;
- (void) setBold:             (BOOL) bold;
- (void) setUnderline:        (BOOL) underline;
- (void) setSymbolic:         (BOOL) symbolic;
- (void) setReversed:         (BOOL) reversed;

- (int)      foregroundColour;
- (int)      backgroundColour;
- (NSColor*) foregroundTrue;
- (NSColor*) backgroundTrue;
- (BOOL)     reversed;
- (BOOL)     fixed;
- (BOOL)     bold;
- (BOOL)     underline;
- (BOOL)     symbolic;

@end

// Buffering
@interface ZBuffer : NSObject<NSCopying,NSCoding> {
    NSMutableArray* buffer;
}

// Buffering

// General window routines
- (void) writeString: (NSString*) string
           withStyle: (ZStyle*) style
            toWindow: (NSObject<ZWindow>*) window;
- (void) clearWindow: (NSObject<ZWindow>*) window
           withStyle: (ZStyle*) style;

// Upper window routines
- (void) moveTo: (NSPoint) newCursorPos
       inWindow: (NSObject<ZUpperWindow>*) window;
- (void) eraseLineInWindow: (NSObject<ZUpperWindow>*) window
                 withStyle: (ZStyle*) style;
- (void) setWindow: (NSObject<ZUpperWindow>*) window
         startLine: (int) startLine
           endLine: (int) endLine;

// Unbuffering
- (BOOL) empty; // YES if the buffer has no data
- (void) blat; // Like blitting, only messier

@end
