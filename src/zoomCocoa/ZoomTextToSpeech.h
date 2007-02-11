//
//  ZoomTextToSpeech.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 21/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlkView/GlkAutomation.h>

//
// An output source that performs text-to-speech functions
//
@interface ZoomTextToSpeech : NSObject<GlkAutomation> {
	NSMutableString* text;
	NSSpeechSynthesizer* synth;
}

@end
