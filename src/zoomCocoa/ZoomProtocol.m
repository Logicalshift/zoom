#import "ZoomProtocol.h"

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
