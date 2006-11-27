//
//  ZoomTextToSpeech.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 21/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Carbon/Carbon.h>

#import "ZoomTextToSpeech.h"

static SpeechChannel channel = nil;

@implementation ZoomTextToSpeech

+ (void) initialize {
	if (channel == nil) NewSpeechChannel(NULL, &channel);
}

- (id) init {
	if (channel == nil) return nil;
	
	self = [super init];
	
	if (self) {
		text = [[NSMutableString alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[text release];
	
	[super dealloc];
}

// = Direct output =

- (void) inputCommand: (NSString*) command {
	[text appendString: @"\n\n"];
	[text appendString: command];
	[text appendString: @"\n\n"];
}

- (void) inputCharacter: (NSString*) character {
}

- (void) outputText:     (NSString*) outputText {
	[text appendString: outputText];
}

// = Status notifications =

- (void) zoomWaitingForInput {
	char* buffer = NULL;
	int bufLen = 0;
	int x;
	
#define WriteBuffer(x) buffer = realloc(buffer, bufLen+1); buffer[bufLen++] = x;
	
	BOOL whitespace = YES;
	BOOL newline = YES;
	BOOL punctuation = NO;
	
	for (x=0; x<[text length]; x++) {
		unichar chr = [text characterAtIndex: x];
		
		if (chr != '\n' && chr != '\r' && (chr < 32 || chr >= 127)) chr = ' ';
		
		switch (chr) {
			case ' ':
				punctuation = NO;
				if (!whitespace) {
					whitespace = YES;
					WriteBuffer(' ');
				}
				break;
				
			case '\n':
			case '\r':
				if (!punctuation && !whitespace) {
					punctuation = YES;
					WriteBuffer('.');
				} else {
					punctuation = NO;
				}
				
				if (!newline) {
					whitespace = YES;
					newline = YES;
					WriteBuffer('\n');
				}
				break;
				
			case ',': case '.': case '?': case ';': case ':': case '!':
				if (!punctuation) {
					punctuation = YES;
					WriteBuffer(chr);
				}
				break;
				
			default:
				whitespace = newline = punctuation = NO;
				WriteBuffer(chr);
		}
	}
	WriteBuffer(0);
	
	SpeakBuffer(channel, buffer, bufLen-1, 0);
	
	free(buffer);
	
	[text release];
	text = [[NSMutableString alloc] init];
}

- (void) zoomInterpreterRestart {
	[self zoomWaitingForInput];
}

// = Glk automation =


// Notifications about events that have occured in the view (when using this automation object for output)

- (void) receivedCharacters: (NSString*) characters					// Text has arrived at the specified text buffer window (from the game)
					 window: (int) windowNumber
				   fromView: (GlkView*) view {
	[text appendString: @"\n\n"];
	[text appendString: characters];
}

- (void) userTyped: (NSString*) userInput							// The user has typed the specified string into the specified window (which is any window that is waiting for input)
			window: (int) windowNumber
		 lineInput: (BOOL) isLineInput
		  fromView: (GlkView*) view {
	[text appendString: @"\n\n"];
	[text appendString: userInput];
	[self zoomWaitingForInput];
}

- (void) userClickedAtXPos: (int) xpos
					  ypos: (int) ypos
					window: (int) windowNumber
				  fromView: (GlkView*) view {
}

- (void) viewWaiting: (GlkView*) view {
	[self zoomWaitingForInput];
}

// Using this automation object for input

- (void) viewIsWaitingForInput: (GlkView*) view {
	[self zoomWaitingForInput];
}

@end
