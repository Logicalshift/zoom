//
//  main.m
//  Zoom
//
//  Created by Andrew Hunter on Wed Jun 25 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#define DEBUG_BUILD

#import <Cocoa/Cocoa.h>

#include <sys/types.h>
#include <unistd.h>

#include "ifmetadata.h"

#ifdef DEBUG_BUILD
static void reportLeaks(void) {
    // List just the unreferenced memory
    char flup[256];
    sprintf(flup, "/usr/bin/leaks -nocontext %i", getpid());
    system(flup);
}
#endif

int main(int argc, const char *argv[])
{
#ifdef DEBUG_BUILD
    atexit(reportLeaks);
#endif
	
	NSData* mdata = [NSData dataWithContentsOfFile: @"/Users/ahunter/testdata.xml"];
	IFMetadata* md = IFMD_Parse([mdata bytes], [mdata length]);
	
	NSString* str = (NSString*)IFStrCpyCF(md->stories[0].data.title);	
	NSLog(@"%@", str);
	[str release];
	
	IFMD_Free(md);
	
    return NSApplicationMain(argc, argv);
}
