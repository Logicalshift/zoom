
#import "ZoomProtocol.h"

#define maxBufferCount 1024
NSString* ZBufferNeedsFlushingNotification = @"ZBufferNeedsFlushingNotification";

// Implementation of the various standard classes
@implementation ZHandleFile
- (id) init {
    self = [super init];

    if (self) {
        // Can't initialise without a valid file handle
        [self release];
        self = NULL;
    }

    return self;
}

- (id) initWithFileHandle: (NSFileHandle*) hdl {
    self = [super init];

    if (self) {
        handle = [hdl retain];
    }

    return self;
}

- (void) dealloc {
    [handle release];

    [super dealloc];
}

// Read
- (int) readByte {
    NSData* data = [handle readDataOfLength: 1];
    if (data == nil || [data length] < 1) return -1;

    return ((unsigned char*)[data bytes])[0];
}

- (unsigned int) readWord {
    NSData* data = [handle readDataOfLength: 2];
    if (data == nil || [data length] < 2) return 0xffffffff;

    const unsigned char* bytes = [data bytes];
    return (bytes[0]<<8)|bytes[1];
}

- (unsigned int) readDWord {
    NSData* data = [handle readDataOfLength: 4];
    if (data == nil || [data length] < 4) return 0xffffffff;

    const unsigned char* bytes = [data bytes];
    return (bytes[0]<<8)|bytes[1];
}

- (NSData*) readBlock: (int) length {
    NSData* data = [handle readDataOfLength: length];
    return data;
}

- (void) seekTo: (int) p {
    [handle seekToFileOffset: p];
}

// Write
- (void) writeByte: (int) byte {
    NSData* data = [NSData dataWithBytes: &byte
                                  length: 1];
    [handle writeData: data];
}

- (void) writeWord: (int) word {
    unsigned char bytes[2];

    bytes[0] = (word>>8);
    bytes[1] = word&0xff;

    NSData* data = [NSData dataWithBytes: bytes
                                  length: 2];

    [handle writeData: data];
}

- (void) writeDWord: (unsigned int) dword {
    unsigned char bytes[4];

    bytes[0] = (dword>>24);
    bytes[1] = (dword>>16);
    bytes[2] = (dword>>8);
    bytes[3] = dword&0xff;

    NSData* data = [NSData dataWithBytes: bytes
                                  length: 4];

    [handle writeData: data];
}

- (void) writeBlock: (NSData*) block {
    [handle writeData: block];
}

- (BOOL) sufferedError {
    return NO;
}

- (NSString*) errorMessage {
    return @"";
}

- (int) fileSize {
    unsigned long pos = [handle offsetInFile];

    [handle seekToEndOfFile];
    unsigned long res = [handle offsetInFile];

    [handle seekToFileOffset: pos];

    return res;
}

- (void) close {
    return; // Do nothing
}
@end

@implementation ZDataFile
- (id) init {
    self = [super init];

    if (self) {
        // Can't initialise without valid data
        [self release];
        self = NULL;
    }

    return self;
}

- (id) initWithData: (NSData*) dt {
    self = [super init];

    if (self) {
        data = [dt retain];
        pos = 0;
    }

    return self;
}

- (void) dealloc {
    [data release];
    
    [super dealloc];
}

- (int) readByte {
    if (pos >= [data length]) {
        return -1;
    }
    
    return ((unsigned char*)[data bytes])[pos++];
}

- (unsigned int) readWord {
    if ((pos+1) >= [data length]) {
        return 0xffffffff;
    }

    const unsigned char* bytes = [data bytes];

    unsigned int res =  (bytes[pos]<<8) | bytes[pos+1];
    pos+=2;

    return res;
}

- (unsigned int) readDWord {
    if ((pos+3) >= [data length]) {
        return 0xffffffff;
    }

    const unsigned char* bytes = [data bytes];

    unsigned int res =  (bytes[pos]<<24) | (bytes[pos+1]<<16) |
        (bytes[pos+2]<<8) | (bytes[pos+3]);
    pos+=4;

    return res;
}

- (NSData*) readBlock: (int) length {
    const unsigned char* bytes = [data bytes];

    if (pos >= [data length]) {
        return nil;
    }

    if ((pos + length) > [data length]) {
        int diff = (pos+length) - [data length];

        length -= diff;
    }

    NSData* res =  [NSData dataWithBytes: bytes + pos
                                  length: length];

    pos += length;

    return res;
}

- (void) seekTo: (int) p {
    pos = p;
    if (pos > [data length]) {
        pos = [data length];
    }
}

- (void) writeByte: (int) byte {
    return; // Do nothing
}

- (void) writeWord: (int) word {
    return; // Do nothing
}

- (void) writeDWord: (unsigned int) dword {
    return; // Do nothing
}

- (void) writeBlock: (NSData*) block {
    return; // Do nothing
}

- (BOOL) sufferedError {
    return NO;
}

- (NSString*) errorMessage {
    return @"";
}

- (int) fileSize {
    return [data length];
}

- (void) close {
    return; // Do nothing
}
@end

// = ZStyle =
NSString* ZStyleAttributeName = @"ZStyleAttribute";

@implementation ZStyle

- (id) init {
    self = [super init];
    if (self) {
        foregroundTrue = backgroundTrue = NULL;
        foregroundColour = 0;
        backgroundColour = 7;

        isFixed = isBold = isUnderline = isSymbolic = NO;
    }
    return self;
}

- (void) dealloc {
    if (foregroundTrue) [foregroundTrue release];
    if (backgroundTrue) [backgroundTrue release];
    [super dealloc];
}

- (void) setForegroundColour: (int) zColour {
    foregroundColour = zColour;
}

- (void) setBackgroundColour: (int) zColour {
    backgroundColour = zColour;
}

- (void) setForegroundTrue: (NSColor*) colour {
    if (foregroundTrue) [foregroundTrue release];
    if (colour)
        foregroundTrue = [colour retain];
    else
        foregroundTrue = nil;
}

- (void) setBackgroundTrue: (NSColor*) colour {
    if (backgroundTrue) [backgroundTrue release];
    if (colour)
        backgroundTrue = [colour retain];
    else
        backgroundTrue = nil;
}

- (void) setFixed: (BOOL) fixed {
    isFixed = fixed;
}

- (void) setBold: (BOOL) bold {
    isBold = bold;
}

- (void) setUnderline: (BOOL) underline {
    isUnderline = underline;
}

- (void) setSymbolic: (BOOL) symbolic {
    isSymbolic = symbolic;
}

- (void) setReversed: (BOOL) reversed {
    isReversed = reversed;
}

- (int) foregroundColour {
    return foregroundColour;
}

- (int) backgroundColour {
    return backgroundColour;
}

- (NSColor*) foregroundTrue {
    return foregroundTrue;
}

- (NSColor*) backgroundTrue {
    return backgroundTrue;
}

- (BOOL) reversed {
    return isReversed;
}

- (BOOL) fixed {
    return isFixed;
}

- (BOOL) bold {
    return isBold;
}

- (BOOL) underline {
    return isUnderline;
}

- (BOOL) symbolic {
    return isSymbolic;
}

- (id) copyWithZone: (NSZone*) zone {
    ZStyle* style;
    style = [[[self class] allocWithZone: zone] init];

    [style setForegroundColour: foregroundColour];
    [style setBackgroundColour: backgroundColour];
    [style setForegroundTrue: foregroundTrue];
    [style setBackgroundTrue: backgroundTrue];

    [style setReversed:  isReversed];
    [style setFixed:     isFixed];
    [style setBold:      isBold];
    [style setUnderline: isUnderline];
    [style setSymbolic:  isSymbolic];

    return style;
}

- (NSString*) description {
    return [NSString stringWithFormat: @"Style - bold: %@, underline %@, fixed %@, symbolic %@",
                        isBold?@"YES":@"NO",
                        isUnderline?@"YES":@"NO",
                        isFixed?@"YES":@"NO",
                        isSymbolic?@"YES":@"NO"];
}

- (void) encodeWithCoder: (NSCoder*) coder {
    int flags = (isBold?1:0) | (isUnderline?2:0) | (isFixed?4:0) | (isSymbolic?8:0) | (isReversed?16:0);
    
    [coder encodeValueOfObjCType: @encode(int) at: &flags];

    [coder encodeObject: foregroundTrue];
    [coder encodeObject: backgroundTrue];
    [coder encodeValueOfObjCType: @encode(int) at: &foregroundColour];
    [coder encodeValueOfObjCType: @encode(int) at: &backgroundColour];
}

- (id) initWithCoder: (NSCoder*) coder {
    self = [super init];
    if (self) {
        int flags;
        
        [coder decodeValueOfObjCType: @encode(int) at: &flags];
        isBold = (flags&1)?YES:NO;
        isUnderline = (flags&2)?YES:NO;
        isFixed = (flags&4)?YES:NO;
        isSymbolic = (flags&8)?YES:NO;
        isReversed = (flags&16)?YES:NO;

        foregroundTrue   = [[coder decodeObject] retain];
        backgroundTrue   = [[coder decodeObject] retain];
        
        [coder decodeValueOfObjCType: @encode(int) at: &foregroundColour];
        [coder decodeValueOfObjCType: @encode(int) at: &backgroundColour];
    }
    return self;
}

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    if ([encoder isBycopy]) return self;
    return [super replacementObjectForPortCoder:encoder];
}

- (BOOL) isEqual: (id) object {
    if (![(NSObject*)object isKindOfClass: [self class]]) {
        return NO;
    }

    ZStyle* obj = object;

    if ([obj bold]      == isBold &&
        [obj underline] == isUnderline &&
        [obj fixed]     == isFixed &&
        [obj symbolic]  == isSymbolic &&
        [obj reversed]  == isReversed &&
        [obj foregroundColour] == foregroundColour &&
        [obj backgroundColour] == backgroundColour &&
        ((foregroundTrue == nil && [obj foregroundTrue] == nil) ||
         ([[obj foregroundTrue] isEqual: foregroundTrue])) &&
        ((backgroundTrue == nil && [obj backgroundTrue] == nil) ||
         ([[obj backgroundTrue] isEqual: backgroundTrue]))) {
        return YES;
    }

    return NO;
}

@end

// == ZBuffer ==

// Buffer type strings
NSString* ZBufferWriteString = @"ZBWS";
NSString* ZBufferClearWindow = @"ZBCW";
NSString* ZBufferMoveTo      = @"ZBMT";
NSString* ZBufferEraseLine   = @"ZBEL";
NSString* ZBufferSetWindow   = @"ZBSW";

NSString* ZBufferPlotRect    = @"ZBPR";
NSString* ZBufferPlotText    = @"ZBPT";

@implementation ZBuffer

// Initialisation
- (id) init {
    self = [super init];
    if (self) {
        buffer = [[NSMutableArray allocWithZone: [self zone]] init];
    }
    return self;
}

- (void) dealloc {
    [buffer release];
    [super dealloc];
}

// NSCopying

- (id) copyWithZone: (NSZone*) zone {
    ZBuffer* buf;
    buf = [[[self class] allocWithZone: zone] init];

    [buf->buffer release];
    buf->buffer = [buffer mutableCopyWithZone: zone];

    return buf;
}

// NSCoding

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    // Allow bycopying
    if ([encoder isBycopy]) return self;
    return [super replacementObjectForPortCoder:encoder];
}

- (void) encodeWithCoder: (NSCoder*) coder {
    [coder encodeObject: buffer];
}

- (id) initWithCoder: (NSCoder*) coder {
    self = [super init];
    if (self) {
        [buffer release];
        buffer = [[coder decodeObject] retain];
    }
    return self;
}

// Buffering

// General window routines
- (void) writeString: (NSString*)          string
           withStyle: (ZStyle*)            style
            toWindow: (NSObject<ZWindow>*) window {
    NSArray* lastTime;

    // If we can, merge this write with the preceding one
    lastTime = [buffer lastObject];
    if (lastTime) {
        if ([[lastTime objectAtIndex: 0] isEqualToString: ZBufferWriteString]) {
            ZStyle* lastStyle             = [lastTime objectAtIndex: 2];

            if (lastStyle == style ||
                [lastStyle isEqual: style]) {
                NSObject<ZWindow>* lastWindow = [lastTime objectAtIndex: 3];
                if (lastWindow == window) {
                    NSMutableString* lastString   = [lastTime objectAtIndex: 1];

                    [lastString appendString: string];
					[self addedToBuffer];
                   return;
                }
            }
        }
    }

    // Create a new write
    [buffer addObject:
        [NSArray arrayWithObjects:
            ZBufferWriteString,
            [NSMutableString stringWithString: string],
            style,
            window,
            nil]];
	[self addedToBuffer];
}

- (void) clearWindow: (NSObject<ZWindow>*) window
           withStyle: (ZStyle*) style {
    [buffer addObject:
        [NSArray arrayWithObjects:
            ZBufferClearWindow,
            style,
            window,
            nil]];
	[self addedToBuffer];
}

// Upper window routines
- (void) moveTo: (NSPoint) newCursorPos
       inWindow: (NSObject<ZUpperWindow>*) window {
    [buffer addObject:
        [NSArray arrayWithObjects:
            ZBufferMoveTo,
            [NSValue valueWithPoint: newCursorPos],
            window,
            nil]];
	[self addedToBuffer];
}

- (void) eraseLineInWindow: (NSObject<ZUpperWindow>*) window
                 withStyle: (ZStyle*) style {
    [buffer addObject:
        [NSArray arrayWithObjects:
            ZBufferEraseLine,
            style,
            window,
            nil]];    
	[self addedToBuffer];
}

- (void) setWindow: (NSObject<ZUpperWindow>*) window
         startLine: (int) startLine
           endLine: (int) endLine {
    [buffer addObject:
        [NSArray arrayWithObjects:
            ZBufferSetWindow,
            [NSNumber numberWithInt: startLine],
            [NSNumber numberWithInt: endLine],
            window,
            nil]];
	[self addedToBuffer];
}

// Pixmap window routines
- (void) plotRect: (NSRect) rect
		withStyle: (ZStyle*) style
		 inWindow: (NSObject<ZPixmapWindow>*) window {
    [buffer addObject:
        [NSArray arrayWithObjects:
            ZBufferPlotRect,
			[NSValue valueWithRect: rect],
			style,
			window,
            nil]];
	[self addedToBuffer];
}

- (void) plotText: (NSString*) text
		  atPoint: (NSPoint) point
		withStyle: (ZStyle*) style
		 inWindow: (NSObject<ZPixmapWindow>*) win {
    [buffer addObject:
        [NSArray arrayWithObjects:
            ZBufferPlotText,
			[[text copy] autorelease],
			[NSValue valueWithPoint: point],
			style,
			win,
            nil]];
	[self addedToBuffer];
}

// Unbuffering
- (BOOL) empty {
    if ([buffer count] < 1)
        return YES;
    else
        return NO;
}

- (void) blat {
#ifdef DEBUG
	NSLog(@"Buffer: flushing... (%@)", buffer);
#endif
	
    NSEnumerator* bufEnum = [buffer objectEnumerator];
    NSArray*      entry;

    while (entry = [bufEnum nextObject]) {
        NSString* entryType = [entry objectAtIndex: 0];
#ifdef DEBUG
		NSLog(@"Buffer: %@", entryType);
#endif

        if ([entryType isEqualToString: ZBufferWriteString]) {
            NSString* str = [entry objectAtIndex: 1];
            ZStyle*   sty = [entry objectAtIndex: 2];
            NSObject<ZWindow>* win = [entry objectAtIndex: 3];

            [win writeString: str
                   withStyle: sty];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferWriteString(%@)", str);
#endif
        } else if ([entryType isEqualToString: ZBufferClearWindow]) {
            ZStyle* sty = [entry objectAtIndex: 1];
            NSObject<ZWindow>* win = [entry objectAtIndex: 2];

            [win clearWithStyle: sty];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferClearWindow");
#endif
        } else if ([entryType isEqualToString: ZBufferMoveTo]) {
            NSPoint whereTo = [[entry objectAtIndex: 1] pointValue];
            NSObject<ZUpperWindow>* win = [entry objectAtIndex: 2];

            [win setCursorPositionX: whereTo.x
                                  Y: whereTo.y];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferMoveTo(%g, %g)", whereTo.x, whereTo.y);
#endif
        } else if ([entryType isEqualToString: ZBufferEraseLine]) {
            ZStyle* sty = [entry objectAtIndex: 1];
            NSObject<ZUpperWindow>* win = [entry objectAtIndex: 2];

            [win eraseLineWithStyle: sty];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferEraseLine");
#endif
        } else if ([entryType isEqualToString: ZBufferSetWindow]) {
            int startLine = [[entry objectAtIndex: 1] intValue];
            int endLine   = [[entry objectAtIndex: 2] intValue];
            NSObject<ZUpperWindow>* win = [entry objectAtIndex: 3];

            [win startAtLine: startLine];
            [win endAtLine: endLine];
			
#ifdef DEBUG
			NSLog(@"Buffer: ZBufferSetWindow(%i, %i)", startLine, endLine);
#endif
		} else if ([entryType isEqualToString: ZBufferPlotRect]) {
			NSRect rect = [[entry objectAtIndex: 1] rectValue];
			ZStyle* style = [entry objectAtIndex: 2];
			NSObject<ZPixmapWindow>* win = [entry objectAtIndex: 3];
			
			[win plotRect: rect
				withStyle: style];
		} else if ([entryType isEqualToString: ZBufferPlotText]) {
			NSString* text = [entry objectAtIndex: 1];
			NSPoint point = [[entry objectAtIndex: 2] pointValue];
			ZStyle* style = [entry objectAtIndex: 3];
			NSObject<ZPixmapWindow>* win = [entry objectAtIndex: 4];
			
			[win plotText: text
				  atPoint: point
				withStyle: style];
        } else {
            NSLog(@"Unknown buffer type: %@", entryType);
        }
    }
}

// Notifications
- (void) addedToBuffer {
	bufferCount++;
	
	if (bufferCount > maxBufferCount) {
		[[NSNotificationCenter defaultCenter] postNotificationName: ZBufferNeedsFlushingNotification
															object: self];
		bufferCount = 0;
	}
}

@end

// = File wrappers =
@implementation ZPackageFile

- (id) initWithPath: (NSString*) path
		defaultFile: (NSString*) filename
		 forWriting: (BOOL) write {
	self = [super init];
	
	if (self) {
		BOOL failed = NO;
		
		forWriting = write;
		pos = 0;
		
		defaultFile = [filename copy];
		if (defaultFile == nil) defaultFile = @"save.qut";
		
		attributes = nil;
		
		if (forWriting) {
			// Setup for writing
			writePath = [path copy];
			wrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: [NSDictionary dictionary]];
			
			data = nil;
			writeData = [[NSMutableData alloc] init];
		} else {
			// Setup for reading
			writePath = nil; // No writing!
			writeData = nil;
			wrapper = [[NSFileWrapper alloc] initWithPath: path];
			
			if (![wrapper isDirectory]) {
				failed = YES;
			}
			
			data = [[[wrapper fileWrappers] objectForKey: defaultFile] retain];
			
			if (![data isRegularFile]) {
				failed = YES;
			}
		}
		
		if (wrapper == nil || failed) {
			// Couldn't open file
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (void) setAttributes: (NSDictionary*) attr {
	if (attributes) [attributes release];
	attributes = [attr copy];
}

- (void) dealloc {
	if (wrapper) [wrapper release];
	if (writePath) [writePath release];
	if (defaultFile) [defaultFile release];

	if (data) [data release];
	if (writeData) [writeData release];
	
	if (attributes) [attributes release];
	
	[super dealloc];
}

- (int) readByte {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return 0;
	}
	
	if (pos >= [[data regularFileContents] length]) return -1;
	
	return ((unsigned char*)[[data regularFileContents] bytes])[pos++];
}

- (unsigned int) readWord {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return 0;
	}
	
	if ((pos+1) >= [[data regularFileContents] length]) {
        return 0xffffffff;
    }
	
    const unsigned char* bytes = [[data regularFileContents] bytes];
	
    unsigned int res =  (bytes[pos]<<8) | bytes[pos+1];
    pos+=2;
	
    return res;	
}

- (unsigned int) readDWord {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return 0;
	}

    if ((pos+3) >= [[data regularFileContents] length]) {
        return 0xffffffff;
    }
	
    const unsigned char* bytes = [[data regularFileContents] bytes];
	
    unsigned int res =  (bytes[pos]<<24) | (bytes[pos+1]<<16) |
        (bytes[pos+2]<<8) | (bytes[pos+3]);
    pos+=4;
	
    return res;
}

- (NSData*) readBlock: (int) length {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return nil;
	}
	
    const unsigned char* bytes = [[data regularFileContents] bytes];
	
    if (pos >= [[data regularFileContents] length]) {
        return nil;
    }
	
    if ((pos + length) > [[data regularFileContents] length]) {
        int diff = (pos+length) - [[data regularFileContents] length];
		
        length -= diff;
    }
	
    NSData* res =  [NSData dataWithBytes: bytes + pos
                                  length: length];
	
    pos += length;
	
    return res;
}

- (void) seekTo: (int) p {
	pos = p;
}

- (void) writeByte: (int) byte {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	unsigned char b = byte;
	
	[writeData appendBytes: &b
					length: 1];
}

- (void) writeWord: (int) word {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	unsigned char b[2];
	
	b[0] = (word>>8)&0xff;
	b[1] = word&0xff;
	
	[writeData appendBytes: b
					length: 2];
}

- (void) writeDWord: (unsigned int) dword {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	unsigned char b[4];
	
	b[0] = (dword>>24)&0xff;
	b[1] = (dword>>16)&0xff;
	b[2] = (dword>>8)&0xff;
	b[3] = dword&0xff;
	
	[writeData appendBytes: b
					length: 4];
}

- (void) writeBlock: (NSData*) block {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	[writeData appendData: block];
}

- (BOOL) sufferedError {
	return NO;
}

- (NSString*) errorMessage {
	return nil;
}

- (int) fileSize {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return nil;
	}
	
	return [[data regularFileContents] length];
}

- (void) close {
	if (forWriting) {
		// Write out the file
		if ([[wrapper fileWrappers] objectForKey: defaultFile] != nil) {
			[wrapper removeFileWrapper: [[wrapper fileWrappers] objectForKey: defaultFile]];
		}
		
		[wrapper addRegularFileWithContents: writeData
						  preferredFilename: defaultFile];
		
		[wrapper writeToFile: writePath
				  atomically: YES
			 updateFilenames: YES];
		
		if (attributes) {
			[[NSFileManager defaultManager] changeFileAttributes: attributes
														  atPath: writePath];
		}
	}
}

- (void) addData: (NSData*) newData
	 forFilename: (NSString*) filename {
	if (!forWriting) {
		[NSException raise: @"ZoomFileWriteException" format: @"Tried to write to a file open for reading"];
		return;
	}
	
	[wrapper addRegularFileWithContents: newData
					  preferredFilename: filename];
}

- (NSData*) dataForFile: (NSString*) filename {
	if (forWriting) {
		[NSException raise: @"ZoomFileReadException" format: @"Tried to read from a file open for writing"];
		return nil;
	}
	
	return [[[wrapper fileWrappers] objectForKey: filename] regularFileContents];
}

@end
