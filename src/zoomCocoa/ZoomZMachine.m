//
//  ZoomZMachine.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomZMachine.h"
#import "ZoomServer.h"

#include "sys/time.h"


#include "zmachine.h"
#include "interp.h"
#include "random.h"
#include "file.h"
#include "zscii.h"
#include "display.h"
#include "rc.h"
#include "stream.h"
#include "blorb.h"
#include "v6display.h"
#include "state.h"
#include "debug.h"

@implementation ZoomZMachine

- (id) init {
    self = [super init];

    if (self) {
        display = nil;
        machineFile = NULL;

        inputBuffer = [[NSMutableString allocWithZone: [self zone]] init];
        outputBuffer = [[ZBuffer allocWithZone: [self zone]] init];
        lastFile = nil;
		terminatingCharacter = 0;

        windows[0] = windows[1] = windows[2] = nil;

        int x;
        for(x=0; x<3; x++) {
            windowBuffer[x] = [[NSMutableAttributedString alloc] init];
        }
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(flushBuffers)
													 name: ZBufferNeedsFlushingNotification
												   object: nil];
    }

    return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
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
    [outputBuffer release];

    mainMachine = nil;
    
    if (lastFile) [lastFile release];

    if (machineFile) {
        close_file(machineFile);
    }
	if (storyData) [storyData release];
    
    [super dealloc];
}

- (NSString*) description {
    return @"Zoom 1.0.2 ZMachine object";
}

// = Setup =
- (void) loadStoryFile: (NSData*) storyFile {
    // Create the machine file
	storyData = [storyFile retain];
    ZDataFile* file = [[ZDataFile alloc] initWithData: storyFile];
    machineFile = open_file_from_object([file autorelease]);
	
	// Start initialising the Z-Machine
	// (We do this so that we can load a save state at any time after this call)
	
	wasRestored = NO;
	
    // RNG
    struct timeval tv;
    gettimeofday(&tv, NULL);
    random_seed(tv.tv_sec^tv.tv_usec);
	
    // Some default options
	// rc_load(); // DELETEME: TEST FOR BUG
	rc_hash = hash_create();
	
	rc_defgame = malloc(sizeof(rc_game));
	rc_defgame->name = "";
	rc_defgame->interpreter = 3;
	rc_defgame->revision = 'Z';
	rc_defgame->fonts = NULL;
	rc_defgame->n_fonts = 0;
	rc_defgame->colours = NULL;
	rc_defgame->n_colours = 0;
	rc_defgame->gamedir = rc_defgame->savedir = rc_defgame->sounds = rc_defgame->graphics = NULL;
	rc_defgame->xsize = 80;
	rc_defgame->ysize = 25;
	rc_defgame->antialias = 1;
	
	hash_store(rc_hash, "default", 7, rc_defgame);
	
    // Load the story
    machine.story_length = get_size_of_file(machineFile);
    zmachine_load_file(machineFile, &machine);
	machine.blorb = blorb_loadfile(NULL);
}

// = Running =
- (void) startRunningInDisplay: (in byref NSObject<ZDisplay>*) disp {
    NSAutoreleasePool* mainPool = [[NSAutoreleasePool alloc] init];
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
			windows[0] = [[display createPixmapWindow] retain];
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
    switch (machine.header[0])
    {
#ifdef SUPPORT_VERSION_3
        case 3:
            display_split(1, 1);

            display_set_colour(0, 7); display_set_font(0);
            display_set_window(0);
            if (!wasRestored) zmachine_run(3, NULL); else zmachine_runsome(3, machine.zpc);
            break;
#endif
#ifdef SUPPORT_VERSION_4
        case 4:
            if (!wasRestored) zmachine_run(4, NULL); else zmachine_runsome(4, machine.zpc);
            break;
#endif
#ifdef SUPPORT_VERSION_5
        case 5:
            if (!wasRestored) zmachine_run(5, NULL); else zmachine_runsome(5, machine.zpc);
            break;
        case 7:
            if (!wasRestored) zmachine_run(7, NULL); else zmachine_runsome(7, machine.zpc);
            break;
        case 8:
            if (!wasRestored) zmachine_run(8, NULL); else zmachine_runsome(8, machine.zpc);
            break;
#endif
#ifdef SUPPORT_VERSION_6
        case 6:
            v6_startup();
            v6_set_cursor(1,1);
			
            if (!wasRestored) zmachine_run(6, NULL); else zmachine_runsome(6, machine.zpc);
            break;
#endif

        default:
            zmachine_fatal("Unsupported ZMachine version %i", machine.header[0]);
            break;
    }

    display_finalise();
    [mainPool release];
	
	display_exit(0);
}

// = Debugging =
void cocoa_debug_handler(ZDWord pc) {
	[mainMachine breakpoint: pc];
}

- (void) breakpoint: (ZDWord) pc {
	if (display) {
		// Notify the display of the breakpoint
		waitingForBreakpoint = YES;
		[self flushBuffers];
		[display hitBreakpointAt: pc];
		
		// Wait for the display to request resumption
		NSAutoreleasePool* breakpointPool = [[NSAutoreleasePool alloc] init];
		
		while (waitingForBreakpoint && (mainConnection != nil || mainMachine != nil)) {
			[breakpointPool release];
			breakpointPool = [[NSAutoreleasePool alloc] init];
			
			[mainLoop acceptInputForMode: NSDefaultRunLoopMode
							  beforeDate: [NSDate distantFuture]];
		}
		
		[breakpointPool release];
	}
}

- (void) continueFromBreakpoint {
	if (!waitingForBreakpoint) {
		[NSException raise: @"BreakpointException" format: @"Attempt to call a continuation function when Zoom was not waiting at a breakpoint"];
		return;
	}
	
	waitingForBreakpoint = NO;
}

- (void) stepFromBreakpoint {
	if (!waitingForBreakpoint) {
		[NSException raise: @"BreakpointException" format: @"Attempt to call a continuation function when Zoom was not waiting at a breakpoint"];
		return;
	}
	
	debug_set_temp_breakpoints(debug_step_over);
	waitingForBreakpoint = NO;
}

- (void) stepIntoFromBreakpoint {
	if (!waitingForBreakpoint) {
		[NSException raise: @"BreakpointException" format: @"Attempt to call a continuation function when Zoom was not waiting at a breakpoint"];
		return;
	}
	
	debug_set_temp_breakpoints(debug_step_into);
	waitingForBreakpoint = NO;
}

- (void) finishFromBreakpoint {
	if (!waitingForBreakpoint) {
		[NSException raise: @"BreakpointException" format: @"Attempt to call a continuation function when Zoom was not waiting at a breakpoint"];
		return;
	}
	
	debug_set_temp_breakpoints(debug_step_out);
	waitingForBreakpoint = NO;
}

- (NSData*) staticMemory {
}

- (void) loadDebugSymbolsFrom: (NSString*) symbolFile
			   withSourcePath: (NSString*) sourcePath {	
	debug_load_symbols([symbolFile cString], [sourcePath cString]);

	// Setup our debugger callback
	debug_set_bp_handler(cocoa_debug_handler);
}

- (int) evaluateExpression: (NSString*) expression {
	debug_address addr;
	
	addr = debug_find_address(machine.zpc);

	debug_expr = malloc(sizeof(int) * ([expression length]+1));
	int x;
	for (x=0; x<[expression length]; x++) {
		debug_expr[x] = [expression characterAtIndex: x];
	}
	debug_expr[x] = 0;

	debug_expr_routine = addr.routine;
	debug_error = NULL;
	debug_expr_pos = 0;
	debug_eval_parse();
	free(debug_expr);
	
	if (debug_error != NULL) return 0x7fffffff;
	
	return debug_eval_result;
}

- (void) setBreakpointAt: (int) address {
	debug_set_breakpoint(address, 0, 0);
}

- (BOOL) setBreakpointAtName: (NSString*) name {
	int address = [self addressForName: name];
	
	if (address >= 0) {
		[self setBreakpointAt: address];
		return YES;
	} else {
		return NO;
	}
}

- (void) removeBreakpointAt: (int) address {
	debug_clear_breakpoint(debug_get_breakpoint(address));
}

- (void) removeBreakpointAtName: (NSString*) name {
	int address = [self addressForName: name];
	
	if (address >= 0) {
		[self removeBreakpointAt: address];
	}
}

- (int) addressForName: (NSString*) name {
	return debug_find_named_address([name cString]);
}

- (NSString*) nameForAddress: (int) address {
	debug_address addr = debug_find_address(address);
	
	if (addr.routine != NULL) {
		return [NSString stringWithCString: addr.routine->name];
	}
	
	return nil;
}

- (NSString*) sourceFileForAddress: (int) address {
	debug_address addr = debug_find_address(address);
	
	if (addr.line == NULL) return nil;

	return [NSString stringWithCString: debug_syms.files[addr.line->fl].realname];
}

- (NSString*) routineForAddress: (int) address {
	debug_address addr = debug_find_address(address);
	
	if (addr.routine == NULL) return nil;
	
	return [NSString stringWithCString: addr.routine->name];
}

- (int) lineForAddress: (int) address {
	debug_address addr = debug_find_address(address);
	
	if (addr.line == NULL) return -1;
	
	return addr.line->ln;
}

// = Autosave =
- (NSData*) createGameSave {
	// Create a save game, for autosave purposes
	int len;
	
	if (machine.autosave_pc <= 0) return nil;
	
	void* gameData = state_compile(&machine.stack, machine.autosave_pc, &len, 1);
	
	NSData* result = [NSData dataWithBytes: gameData length: len];
	
	free(gameData);
	
	return result;
}

- (NSData*) storyFile {
	return storyData;
}

- (void) restoreSaveState: (NSData*) saveData {
	const ZByte* gameData = [saveData bytes];
	
	// NOTE: suppresses a warning (but it should be OK)
	state_decompile((ZByte*)gameData, &machine.stack, &machine.zpc, [saveData length]);
	wasRestored = YES;
}

// = Receiving text/characters =
- (void) inputText: (NSString*) text {
    [inputBuffer appendString: text];
}

- (void) inputTerminatedWithCharacter: (unsigned int) termChar {
	terminatingCharacter = termChar;
}

- (int)	terminatingCharacter {
	return terminatingCharacter;
}

// = Receiving files =
- (void) filePromptCancelled {
    if (lastFile) {
        [lastFile release];
        lastFile = nil;
        lastSize = -1;
    }
    
    filePromptFinished = YES;
}

- (void) promptedFileIs: (NSObject<ZFile>*) file
                   size: (int) size {
    if (lastFile) [lastFile release];
    
    lastFile = [file retain];
    lastSize = size;
    
    filePromptFinished = YES;
}

- (void) filePromptStarted {
    filePromptFinished = NO;
    if (lastFile) {
        [lastFile release];
        lastFile = nil;
    }
}

- (BOOL) filePromptFinished {
    return filePromptFinished;
}

- (NSObject<ZFile>*) lastFile {
    return lastFile;
}

- (int) lastSize {
    return lastSize;
}

- (void) clearFile {
    if (lastFile) {
        [lastFile release];
        lastFile = nil;
    }
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

// = Buffering =

- (ZBuffer*) buffer {
    return outputBuffer;
}

- (void) flushBuffers {
    [display flushBuffer: outputBuffer];
    [outputBuffer release];
    outputBuffer = [[ZBuffer allocWithZone: [self zone]] init];
}

// = Display size =

- (void) displaySizeHasChanged {
    zmachine_resize_display(display_get_info());
}

@end

// = Fatal errors and warnings =
void  zmachine_fatal(char* format, ...) {
	char fatalBuf[512];
	va_list  ap;
	
	va_start(ap, format);
	vsnprintf(fatalBuf, 512, format, ap);
	va_end(ap);
	
	fatalBuf[511] = 0;
	
	[[mainMachine display] displayFatalError: [NSString stringWithCString: fatalBuf]];
	
	display_exit(1);
}

void  zmachine_warning(char* format, ...) {
	char fatalBuf[512];
	va_list  ap;
	
	va_start(ap, format);
	vsnprintf(fatalBuf, 512, format, ap);
	va_end(ap);
	
	fatalBuf[511] = 0;
	
	[[mainMachine display] displayWarning: [NSString stringWithCString: fatalBuf]];
}
