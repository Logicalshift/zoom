//
//  ZoomDownload.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomDownload.h"


@implementation ZoomDownload

// = Initialisation =

static NSString* downloadDirectory;
static int lastDownloadId = 0;

+ (void) initialize {
	// Pick a directory to store downloads in
	NSString* tempDir = NSTemporaryDirectory();
	int pid = (int)getpid();
	
	downloadDirectory = [[tempDir stringByAppendingPathComponent: [NSString stringWithFormat: @"Zoom-Downloads-%i", pid]] retain];
}

- (id) initWithUrl: (NSURL*) newUrl {
	self = [super init];
	
	if (self) {
		if (newUrl == nil) {
			[self release];
			return nil;
		}
		
		url = [newUrl copy];
	}
	
	return self;
}

- (void) dealloc {
	// Delete the temporary file
	if ([[NSFileManager defaultManager] fileExistsAtPath: tmpFile]) {
		[[NSFileManager defaultManager] removeFileAtPath: tmpFile
												 handler: nil];
	}

	// Release our resources
	[url release];
	
	if (connection)		[connection release];
	if (tmpFile)		[tmpFile release];
	if (tmpDirectory)	[tmpDirectory release];
	
	[super dealloc];
}

- (void) setDelegate: (id) newDelegate {
	delegate = newDelegate;
}

// = Starting the download =

- (void) startDownload {
	// Do nothing if this download is already running
	if (connection != nil) return;
	
	// Let the delegate know
	if (delegate && [delegate respondsToSelector: @selector(downloadStarting:)]) {
		[delegate downloadStarting: self];
	}
	
	NSLog(@"Downloading: %@", url);
	
	// Create a connection to download the specified URL
	NSURLRequest* request = [NSURLRequest requestWithURL: url];
	connection = [[NSURLConnection connectionWithRequest: request
												delegate: self] retain];
}

- (void) createDownloadDirectory {
	BOOL exists;
	BOOL isDir;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: downloadDirectory
												  isDirectory: &isDir];
	if (!exists) {
		[[NSFileManager defaultManager] createDirectoryAtPath: downloadDirectory
												   attributes: nil];
	} else if (!isDir) {
		[downloadDirectory autorelease];
		downloadDirectory = [[downloadDirectory stringByAppendingString: @"-1"] retain];
		[self createDownloadDirectory];
	}
}

// = NSURLConnection delegate =

- (void)  connection:(NSURLConnection *)conn
  didReceiveResponse:(NSURLResponse *)response {
	int status = 200;
	if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
		status = [(NSHTTPURLResponse*)response statusCode];
	}
	
	if (status >= 400) {
		// Failure: give up
		[connection cancel];
		[connection release]; connection = nil;
		[tmpFile release]; tmpFile = nil;
		[downloadFile release]; downloadFile = nil;

		if (delegate && [delegate respondsToSelector: @selector(downloadFailed:)]) {
			[delegate downloadFailed: self];
		}
		return;
	}
	
	expectedLength = [response expectedContentLength];
	downloadedSoFar = 0;
	
	// Create the download directory if it doesn't exist
	[self createDownloadDirectory];
	
	// Create the download file
	[tmpFile release];
	tmpFile = [downloadDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"download-%i", lastDownloadId++]];
	tmpFile = [tmpFile stringByAppendingPathExtension: [[response suggestedFilename] pathExtension]];
	[tmpFile retain];
	
	if (downloadFile) {
		[downloadFile closeFile];
		[downloadFile release];
		downloadFile = nil;
	}
	NSLog(@"Downloading to %@", tmpFile);
	downloadFile = [[NSFileHandle fileHandleForWritingAtPath: tmpFile] retain];
	
	if (delegate && [delegate respondsToSelector: @selector(downloading:)]) {
		[delegate downloading: self];
	}
}

- (void)connection:(NSURLConnection *)conn
  didFailWithError:(NSError *)error {
	// Delete the downloaded file
	if (downloadFile) {
		[downloadFile closeFile];
		[downloadFile release];
		downloadFile = nil;
		
		[[NSFileManager defaultManager] removeFileAtPath: tmpFile
												 handler: nil];
	}
	
	[tmpFile release];
	tmpFile = nil;
	
	NSLog(@"Download failed with error: %@", error);
	
	// Inform the delegate, and give up
	[connection cancel];
	[connection release]; connection = nil;
	[tmpFile release]; tmpFile = nil;
	[downloadFile release]; downloadFile = nil;
	
	if (delegate && [delegate respondsToSelector: @selector(downloadFailed:)]) {
		[delegate downloadFailed: self];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	// Write to the download file
	if (downloadFile) {
		[downloadFile writeData: data];
	}
	
	// Let the delegate know of the progress
	downloadedSoFar += [data length];
	
	if (expectedLength != nil) {
		float proportion = ((double)downloadedSoFar)/((double)expectedLength);
		
		if (delegate && [delegate respondsToSelector: @selector(download:completed:)]) {
			[delegate download: self
					 completed: proportion];
		}
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn {
	if (downloadFile) {
		// Finish writing the file
		[downloadFile closeFile];
		[downloadFile release];
		downloadFile = nil;
		
		// Create the download directory
		
		// Unarchive the file if it's a zip or a tar file, or move it to the download directory
	}
	
	// Finished with the connection
	[connection release];
	connection = nil;
	
	// Let the download delegate know that the download has finished
	if (delegate && [delegate respondsToSelector: @selector(downloadComplete:)]) {
		[delegate downloadComplete: self];
	}
}

// = Getting the download directory =

- (NSURL*) url {
	return url;
}

- (NSString*) downloadDirectory {
	return tmpDirectory;
}


@end
