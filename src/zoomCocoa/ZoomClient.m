//
//  ZoomClient.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ZoomClient.h"
#import "ZoomProtocol.h"
#import "ZoomClientController.h"

@implementation ZoomClient

- (id) init {
    self = [super init];

    if (self) {
        // Start up a server task
        zoomServerTask = [[NSTask alloc] init];

        [zoomServerTask setLaunchPath: [[NSBundle mainBundle] pathForResource: @"ZoomServer" ofType: nil]];
        [zoomServerTask launch];
        
        // Get a ZMachine
        NSObject<ZVendor>* theVendor = nil;
        NSString* connectionName = [NSString stringWithFormat: @"ZoomVendor-%i",
            [zoomServerTask processIdentifier]];

        int tries = 0;
        int sleepTime = 320;
        while (theVendor == nil && [zoomServerTask isRunning] && tries < 15) {
            // Try and create a connection
            theVendor =
            [[NSConnection rootProxyForConnectionWithRegisteredName: connectionName
                                                               host: nil] retain];

            // Wait a while
            tries++;

            usleep(sleepTime);
            sleepTime = sleepTime*2;
        }
        [theVendor setProtocolForProxy: @protocol(ZVendor)];

        if (tries >= 7 && theVendor == nil) {
            NSLog(@"Failed to create server object");
            [self release];
            return nil;
        }

        if (theVendor == nil) {
            NSLog(@"Unable to get ZMachine vendor object");
            [self release];
            return nil;
        }
        
        zMachine = [[theVendor createNewZMachine] retain];

        if (zMachine == nil) {
            NSLog(@"Unable to create ZMachine");
            
            [theVendor release];
            [self release];
            return nil;
        }

        [theVendor release];
    }

    return self;
}

- (void) dealloc {
    [zMachine release];
    [zoomServerTask terminate];
    [zoomServerTask release];
    
    [super dealloc];
}

/*
- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"ZoomClient";
}
*/

- (void) makeWindowControllers {
    ZoomClientController* controller = [[ZoomClientController allocWithZone: [self zone]] init];

    [self addWindowController: [controller autorelease]];
}

- (NSData *)dataRepresentationOfType:(NSString *)type {
    // Implement to provide a persistent data representation of your document OR remove this and implement the file-wrapper or file path based save methods.
    return nil;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)type {
    // Implement to load a persistent data representation of your document OR remove this and implement the file-wrapper or file path based load methods.
    [zMachine loadStoryFile: data];
    
    return YES;
}

- (NSObject<ZMachine>*) zMachine {
    return zMachine;
}

@end
