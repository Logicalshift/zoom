//
//  ZoomZMachine.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZoomProtocol.h"
#import "ZoomServer.h"

extern NSAutoreleasePool* displayPool;

@interface ZoomZMachine : NSObject<ZMachine> {
    // Remote objects
    NSObject<ZDisplay>* display;
    NSObject<ZWindow>*  windows[3];
    NSMutableAttributedString* windowBuffer[3];

    // The file
    ZFile* machineFile;

    // Some pieces of state information
    NSMutableString* inputBuffer;
}

- (NSObject<ZDisplay>*) display;
- (NSObject<ZWindow>*)  windowNumber: (int) num;
- (NSMutableString*)    inputBuffer;

- (void) appendAttributedString: (NSAttributedString*) str
                       toWindow: (int) window;
- (void) flushBufferForWindow: (int) window;
- (void) clearBufferForWindow: (int) window;

@end
