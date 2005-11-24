//
//  ZoomGlkWindowController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// WindowController for windows running a Glk interpreter
///
@interface ZoomGlkWindowController : NSWindowController {
	IBOutlet GlkView* glkView;								// The view onto the game this controller is running
}

@end
