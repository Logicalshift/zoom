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

#define DEBUG

/*
 * Protocol for an application to talk to/from Zoom
 */

#import <Foundation/Foundation.h>

@protocol ZMachine;
@protocol ZDisplay;
@protocol ZFile;

// == Server-side objects ==
@protocol ZVendor
- (out byref NSObject<ZMachine>*) createNewZMachine;
@end

@protocol ZMachine

// Setup
- (void) loadStoryFile: (in bycopy NSData*) storyFile;
- (BOOL) loadResourcesFromData: (in bycopy NSData*) resources;
- (BOOL) loadResourcesFromFile: (in bycopy NSFileHandle*) file;
- (BOOL) loadResourcesFromZFile: (in byref NSObject<ZFile>) file;

// Running
- (oneway void) startRunningInDisplay: (in byref NSObject<ZDisplay>*) display;

// Debugging
- (out bycopy NSData*) staticMemory;

// Recieving text/characters
- (oneway void) inputText: (in bycopy NSString*) text;
- (oneway void) inputChar: (in bycopy int)       character;
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
- (oneway void) clear;

// Sets the input focus to this window
- (oneway void) setFocus;

// Sending data to a window
- (oneway void) writeString: (in bycopy NSAttributedString*) string;
@end

@protocol ZUpperWindow<ZWindow>
// Functions supported by an upper window

// Size (-1 to indicate an unsplit window)
- (oneway void) startAtLine: (int) line;
- (oneway void) endAtLine:   (int) line;

    // Cursor positioning
- (oneway void) setCursorPositionX: (in int) xpos
                                 Y: (in int) ypos;
- (void)           cursorPositionX: (out int*) xpos
                                 Y: (out int*) ypos;

    // Line erasure
- (oneway void) eraseLine;
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

// Set whether or not we recieve certain types of data
- (oneway void) shouldReceiveCharacters;
- (oneway void) shouldReceiveText: (in int) maxLength;
- (void)        stopReceiving;
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
