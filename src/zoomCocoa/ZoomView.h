//
//  ZoomView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomProtocol.h"
#import "ZoomMoreView.h"
#import "ZoomTextView.h"
#import "ZoomScrollView.h"
#import "ZoomPreferences.h"

#define ZBoldStyle 1
#define ZUnderlineStyle 2
#define ZFixedStyle 4
#define ZSymbolicStyle 8

extern NSString* ZoomStyleAttributeName;

@class ZoomScrollView;
@class ZoomTextView;
@interface ZoomView : NSView<ZDisplay> {
    NSObject<ZMachine>* zMachine;

    // Subviews
    ZoomTextView* textView;
    NSTextContainer* upperWindowBuffer; // Things hidden under the upper window
    ZoomScrollView* textScroller;

    int inputPos;
    BOOL receiving;
    BOOL receivingCharacters;

    double morePoint;
    double moreReferencePoint;
    BOOL moreOn;

    ZoomMoreView* moreView;

    NSArray* fonts; // 16 entries
    NSArray* colours; // 11 entries

    NSMutableArray* upperWindows;
    NSMutableArray* lowerWindows; // Not that more than one makes any sort of sense
    int lastUpperWindowSize;
    int lastTileSize;
    BOOL upperWindowNeedsRedrawing;

    BOOL exclusiveMode;

    // The task, if we're running it
    NSTask* zoomTask;
    NSPipe* zoomTaskStdout;
    NSMutableString* zoomTaskData;

    // The delegate
    NSObject* delegate;
    
    // Details about the file we're currently saving
    long creatorCode; // 'YZZY' for Zoom
    long typeCode;
	
	// Preferences
	ZoomPreferences* viewPrefs;
	
	float scaleFactor;
	
	// Command history
	NSMutableArray* commandHistory;
	int				historyPos;
	
	// Autosave
	NSData* lastAutosave;
	int		upperWindowsToRestore;
}

// The delegate
- (void) setDelegate: (id) delegate;
- (id)   delegate;

- (void) killTask;

// debugTask forces a breakpoint at the next instruction. Note that the task must have
// debugging symbols loaded, or this will kill the task. Also note that the effect may
// be different than expected if the task is waiting for input.
- (void) debugTask;

- (void) setScaleFactor: (float) scaling;

// Specifying what to run
- (void) setZMachine: (NSObject<ZMachine>*) machine;
- (void) runNewServer: (NSString*) serverName;
- (NSObject<ZMachine>*) zMachine;

// Scrolling, more prompt
- (void) scrollToEnd;
- (void) resetMorePrompt;
- (void) updateMorePrompt;

- (void) setShowsMorePrompt: (BOOL) shown;
- (void) displayMoreIfNecessary;
- (void) page;

- (void) retileUpperWindowIfRequired;

// Formatting a string
- (NSDictionary*) attributesForStyle: (ZStyle*) style;
- (NSAttributedString*) formatZString: (NSString*) zString
                            withStyle: (ZStyle*) style;

- (ZoomTextView*) textView;

// Fonts, colours, etc
- (NSFont*) fontWithStyle: (int) style;
- (NSColor*) foregroundColourForStyle: (ZStyle*) style;
- (NSColor*) backgroundColourForStyle: (ZStyle*) style;

- (void) setFonts:   (NSArray*) fonts;
- (void) setColours: (NSArray*) colours;

// File saving
- (long) creatorCode;
- (void) setCreatorCode: (long) code;

// The upper window
- (int)  upperWindowSize;
- (void) setUpperBuffer: (double) bufHeight;
- (double) upperBufferHeight;
- (void) rearrangeUpperWindows;
- (NSArray*) upperWindows;
- (void) padToLowerWindow;

- (void) upperWindowNeedsRedrawing;

// Event handling
- (BOOL) handleKeyDown:(NSEvent*) theEvent;

// Setting/updating preferences
- (void) setPreferences: (ZoomPreferences*) prefs;
- (void) preferencesHaveChanged: (NSNotification*)not;

- (void) reformatWindow;

// Autosaving
- (BOOL) createAutosaveDataWithCoder: (NSCoder*) encoder;
- (void) restoreAutosaveFromCoder: (NSCoder*) decoder;

- (BOOL) isRunning;

@end

// ZoomView delegate methods
@interface NSObject(ZoomViewDelegate)

- (void) zMachineStarted: (id) sender;
- (void) zMachineFinished: (id) sender;

@end
