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

extern NSString* ZBufferNeedsFlushingNotification;

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

// Restoring game state
- (void) restoreSaveState: (in bycopy NSData*) gameSave;

// Running
- (oneway void) startRunningInDisplay: (in byref NSObject<ZDisplay>*) display;

// Recieving text/characters
- (oneway void) inputText: (in bycopy NSString*) text;
- (oneway void) inputMouseAtPositionX: (int) x
                                    Y: (int) y;

- (void) displaySizeHasChanged;

// Recieving files
- (oneway void) filePromptCancelled;
- (oneway void) promptedFileIs: (in byref NSObject<ZFile>*) file
                          size: (int) size;

// Obtaining game state
- (out bycopy NSData*) createGameSave;

// Debugging
- (void) loadDebugSymbolsFrom: (NSString*) symbolFile
			   withSourcePath: (NSString*) sourcePath;

- (void) continueFromBreakpoint;
- (void) stepFromBreakpoint;
- (void) stepIntoFromBreakpoint;
- (void) finishFromBreakpoint;

- (out bycopy NSData*) staticMemory;
- (int)    evaluateExpression: (NSString*) expression;
- (void)   setBreakpointAt: (int) address;
- (BOOL)   setBreakpointAtName: (NSString*) name;
- (void)   removeBreakpointAt: (int) address;
- (void)   removeBreakpointAtName: (NSString*) name;

- (int)        addressForName: (NSString*) name;
- (NSString*)  nameForAddress: (int) address;

- (NSString*) sourceFileForAddress: (int) address;
- (NSString*) routineForAddress: (int) address;
- (int)       lineForAddress: (int) address;

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

@protocol ZPixmapWindow<ZWindow>
// Pixmap windows are used by version 6 Z-Machines
// You can't combine pixmap and ordinary windows (as yet)

// Sets the size of this window
- (void) setSize: (in NSSize) windowSize;

// Plots a rectangle in a given style
- (void) plotRect: (in NSRect) rect
		withStyle: (in bycopy ZStyle*) style;

// Plots some text of a given size at a given point
- (void) plotText: (in bycopy NSString*) text
		  atPoint: (in NSPoint) point
		withStyle: (in bycopy ZStyle*) style;

// Gets information about a font
- (void) getInfoForStyle: (in bycopy ZStyle*) style
				   width: (out float*) width
				  height: (out float*) height
				  ascent: (out float*) ascent
				 descent: (out float*) descent;
- (out bycopy NSDictionary*) attributesForStyle: (in bycopy ZStyle*) style;

// Reading information about the pixmap
- (out bycopy NSColor*) colourAtPixel: (NSPoint) point;

// Measures a string
- (NSSize) measureString: (in bycopy NSString*) string
			   withStyle: (in bycopy ZStyle*) style;
@end

@protocol ZDisplay
// Overall display functions

// Display information
- (void) dimensionX: (out int*) xSize
                  Y: (out int*) ySize;
- (void) pixmapX: (out int*) xSize
			   Y: (out int*) ySize;
- (void) fontWidth: (out int*) width
			height: (out int*) height;

// Functions to create the standard windows
- (out byref NSObject<ZLowerWindow>*) createLowerWindow;
- (out byref NSObject<ZUpperWindow>*) createUpperWindow;
- (out byref NSObject<ZPixmapWindow>*) createPixmapWindow;

// Requesting user input from
- (void)		shouldReceiveCharacters;
- (void)		shouldReceiveText: (in int) maxLength;
- (void)        stopReceiving;

- (oneway void) setTerminatingCharacters: (in bycopy NSArray*) characters;

// 'Exclusive' mode - lock the UI so no updates occur while we're sending
// large blocks of varied text
- (oneway void) startExclusive;
- (oneway void) stopExclusive;
- (oneway void) flushBuffer: (in bycopy ZBuffer*) toFlush;

// Prompting for files
- (void) promptForFileToWrite: (in ZFileType) type
                                         defaultName: (in bycopy NSString*) name;
- (void) promptForFileToRead: (in ZFileType) type
                 defaultName: (in bycopy NSString*) name;

// Error messages and warnings
- (void) displayFatalError: (in bycopy NSString*) error;
- (void) displayWarning:    (in bycopy NSString*) warning;

// Debugging
- (void) hitBreakpointAt: (int) programCounter;

@end

// Some useful standard classes

// File from a handle
@interface ZHandleFile : NSObject<ZFile> {
    NSFileHandle* handle;
}

- (id) initWithFileHandle: (NSFileHandle*) handle;
@end

// File from data stored in memory
@interface ZDataFile : NSObject<ZFile> {
    NSData* data;
    int pos;
}

- (id) initWithData: (NSData*) data;
@end

// File(s) from a package
@interface ZPackageFile : NSObject<ZFile> {
	NSFileWrapper* wrapper;
	BOOL forWriting;
	NSString* writePath;
	NSString* defaultFile;
	
	NSFileWrapper* data;
	NSMutableData* writeData;
	
	NSDictionary* attributes;
	
	int pos;
}

- (id) initWithPath: (NSString*) path
		defaultFile: (NSString*) filename
		 forWriting: (BOOL) write;

- (void) setAttributes: (NSDictionary*) attributes;

- (void) addData: (NSData*) data
	 forFilename: (NSString*) filename;
- (NSData*) dataForFile: (NSString*) filename;

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
	int bufferCount;
}

// Buffering

// Notifications
- (void) addedToBuffer;

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

// Pixmap window routines
- (void) plotRect: (NSRect) rect
		withStyle: (ZStyle*) style
		 inWindow: (NSObject<ZPixmapWindow>*) win;
- (void) plotText: (NSString*) text
		  atPoint: (NSPoint) point
		withStyle: (ZStyle*) style
		 inWindow: (NSObject<ZPixmapWindow>*) win;

// Unbuffering
- (BOOL) empty; // YES if the buffer has no data
- (void) blat; // Like blitting, only messier

@end
