//
//  ZoomServer.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ZoomServer.h"
#import "ZoomZMachine.h"

NSAutoreleasePool* mainPool = nil;
NSRunLoop*         mainLoop = nil;

ZoomServer*        mainServer = nil;
NSConnection*      mainConnection = nil;

ZoomZMachine*      mainMachine = nil;

@implementation ZoomServer

- (id<ZMachine>) createNewZMachine {
    if (mainMachine) {
        // Outside possibility
        return nil;
    }
    
    ZoomZMachine* res = [[ZoomZMachine alloc] init];

    // Don't allow any further ZMachines to be created
    // (A server that supports multple ZMachines may be a worthwhile
    // future extension, or it may not: consider what happens when
    // a ZMachine gets into an infinite loop)
    [self autorelease];
    [mainConnection registerName: nil];
    [mainConnection autorelease];

    mainConnection = nil;

    mainMachine = res;

    return [res autorelease];
}

@end

// == The main() function ==
int main(int argc, char** argv) {
    // Create the main autorelease pool and runloop
    mainPool = [[NSAutoreleasePool alloc] init];
    mainLoop = [NSRunLoop currentRunLoop];

    // Create the ZMachine object
    mainServer = [[ZoomServer alloc] init];
    [mainServer autorelease];

    // Advertise it for connection
    NSString* serverName;

    serverName = [NSString stringWithFormat: @"ZoomVendor-%i", getpid()];
#ifdef DEBUG
    NSLog(@"Zoom server %@ starting", serverName);
#endif
    
    mainConnection = [NSConnection defaultConnection];
    [mainConnection setRootObject: mainServer];
    if ([mainConnection registerName: serverName] == NO) {
        NSLog(@"Unable to create Zoom server object - aborting");
        [mainPool release];
        return 0;
    }

    // Main runloop
    while (mainConnection != nil || mainMachine != nil) {
        [mainPool release];
        mainPool = [[NSAutoreleasePool alloc] init];
        
        [mainLoop acceptInputForMode: NSDefaultRunLoopMode
                          beforeDate: [NSDate distantFuture]];
    }

#ifdef DEBUG
    NSLog(@"Finalising...");
#endif
    [mainPool release];
    
    return 0;
}