//
//  ZoomTextView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZoomUpperWindow.h"

@class ZoomUpperWindow;
@interface ZoomTextView : NSTextView {
    NSMutableArray* pastedLines; // Array of arrays ([NSValue<rect>, NSAttributedString])
}

- (void) pasteUpperWindowLinesFrom: (ZoomUpperWindow*) win;
- (void) clearPastedLines;

@end
