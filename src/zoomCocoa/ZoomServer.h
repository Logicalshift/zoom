//
//  ZoomServer.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZoomProtocol.h"
#import "ztypes.h"
#import "file.h"

@class ZoomServer;
@class ZoomZMachine;

// Globals
extern NSAutoreleasePool* mainPool;
extern NSRunLoop*         mainLoop;

extern ZoomServer*        mainServer;
extern NSConnection*      mainConnection;

extern ZoomZMachine*      mainMachine;

// Utility functions
extern ZFile* open_file_from_object(NSObject<ZFile>* file);
extern ZDWord get_size_of_file(ZFile* file);

// The main Zoom object
@interface ZoomServer : NSObject<ZVendor> {

}

@end
