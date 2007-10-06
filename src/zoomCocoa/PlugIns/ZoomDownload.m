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

+ (void) removeTemporaryDirectory {
	BOOL exists;
	BOOL isDir;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: downloadDirectory
												  isDirectory: &isDir];
	if (exists) {
		NSLog(@"Removing %@", downloadDirectory);
		[[NSFileManager defaultManager] removeFileAtPath: downloadDirectory
												 handler: nil];
	}
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
	// Finished with notifications
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	// Delete the temporary file
	if ([[NSFileManager defaultManager] fileExistsAtPath: tmpFile]) {
		NSLog(@"Removing: %@", tmpFile);
		[[NSFileManager defaultManager] removeFileAtPath: tmpFile
												 handler: nil];
	}
	
	// Delete the temporary directory
	BOOL isDir;
	if (tmpDirectory 
		&& [[NSFileManager defaultManager] fileExistsAtPath: tmpDirectory
												isDirectory: &isDir]) {
		if (isDir) {
			NSLog(@"Removing: %@", tmpDirectory);
			[[NSFileManager defaultManager] removeFileAtPath: tmpDirectory
													 handler: nil];
		}
	}
	
	// Kill any tasks
	if (task && [task isRunning]) {
		[task interrupt];
		[task terminate];
	}
	if (subtasks) {
		NSEnumerator* subtaskEnum = [subtasks objectEnumerator];
		NSTask* sub;
		while (sub = [subtaskEnum nextObject]) {
			if ([sub isRunning]) {
				[sub interrupt];
				[sub terminate];
			}
		}
	}

	// Release our resources
	[url release];
	
	if (connection)		[connection release];
	if (tmpFile)		[tmpFile release];
	if (tmpDirectory)	[tmpDirectory release];
	
	if (task)			[task release];
	if (subtasks)		[subtasks release];
	
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

// = Status events =

- (void) finished {
	// Kill any tasks
	if (task && [task isRunning]) {
		[task interrupt];
		[task terminate];
	}
	if (subtasks) {
		NSEnumerator* subtaskEnum = [subtasks objectEnumerator];
		NSTask* sub;
		while (sub = [subtaskEnum nextObject]) {
			if ([sub isRunning]) {
				[sub interrupt];
				[sub terminate];
			}
		}
	}

	[connection cancel];
	[connection release]; connection = nil;
	[tmpFile release]; tmpFile = nil;
	[downloadFile release]; downloadFile = nil;	
	[task release]; task = nil;
	[subtasks release]; subtasks = nil;
}

- (void) failed {
	[self finished];

	if (delegate && [delegate respondsToSelector: @selector(downloadFailed:)]) {
		[delegate downloadFailed: self];
	}
}

- (void) succeeded {
	[connection release];
	connection = nil;

	[task release]; task = nil;
	[subtasks release]; subtasks = nil;

	// Let the download delegate know that the download has finished
	if (delegate && [delegate respondsToSelector: @selector(downloadComplete:)]) {
		[delegate downloadComplete: self];
	}	
}

// = The unarchiver =

- (NSString*) directoryForUnarchiving {
	if (tmpDirectory != nil) return tmpDirectory;
	
	NSString* directory = [downloadDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"unarchived-%i", lastDownloadId]];
	
	// Pick a directory name that doesn't already exist
	while ([[NSFileManager defaultManager] fileExistsAtPath: directory]) {
		lastDownloadId++;
		NSString* directory = [downloadDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"unarchived-%i", lastDownloadId]];
	}
	
	// Create the directory
	if ([[NSFileManager defaultManager] createDirectoryAtPath: directory
												   attributes: nil]) {
		return tmpDirectory = [directory retain];
	} else {
		return nil;
	}
}

- (NSTask*) unarchiveFile: (NSString*) filename
			  toDirectory: (NSString*) directory {
	// Creates an NSTask that will unarchive the specified filename (which must be supplied as stdin) to the specified directory
	NSString* pathExtension = [[filename pathExtension] lowercaseString];
	NSString* withoutExtension = [filename stringByDeletingPathExtension];
	BOOL needNextStage = NO;
	NSTask* result = [[[NSTask alloc] init] autorelease];
	
	[result setLaunchPath: @"/usr/bin/env"];
	
	if ([pathExtension isEqualToString: @"zip"]) {
		// Unarchive as a .zip file
		[result setArguments: [NSArray arrayWithObjects:
			@"ditto",
			@"-x",
			@"-k",
			@"-",
			directory,
			nil]];
	} else if ([pathExtension isEqualToString: @"tar"]) {
		// Is a something.tar file
		[result setArguments: [NSArray arrayWithObjects:
			@"tar",
			@"-xC",
			directory,
			nil]];
	} else if ([pathExtension isEqualToString: @"gz"]
			   || [pathExtension isEqualToString: @"bz2"]
			   || [pathExtension isEqualToString: @"z"]) {
		// Is a something.gz file: need to do a two-stage task
		NSTask* nextStage = [self unarchiveFile: withoutExtension
									toDirectory: directory];
		
		// Pick the unarchiver to use
		NSString* unarchiver = @"gzip";
		if ([pathExtension isEqualToString: @"gz"])		unarchiver = @"gzip";
		if ([pathExtension isEqualToString: @"bz2"])	unarchiver = @"bzip2";
		if ([pathExtension isEqualToString: @"z"])		unarchiver = @"uncompress";
		
		// Create the unarchiver
		[result setArguments: [NSArray arrayWithObjects: 
			unarchiver,
			nil]];
		
		// Create the pipes to connect the next task to the unarchiver
		NSPipe* pipe = [NSPipe pipe];
		
		[nextStage setStandardInput: pipe];
		[result setStandardOutput: pipe];
		
		// Add the next stage to the list of subtasks
		if (subtasks == nil) subtasks = [[NSMutableArray alloc] init];
		[subtasks addObject: nextStage];
	} else if ([pathExtension isEqualToString: @"tgz"]) {
		return [self unarchiveFile: [[withoutExtension stringByAppendingPathExtension: @"tar"] stringByAppendingPathExtension: @"gz"]];
	} else if ([pathExtension isEqualToString: @"tbz"] || [pathExtension isEqualToString: @"tbz2"]) {
		return [self unarchiveFile: [[withoutExtension stringByAppendingPathExtension: @"tar"] stringByAppendingPathExtension: @"bz2"]];
	} else {
		// Default is just to copy the file
		NSString* destFile = [directory stringByAppendingPathComponent: [filename lastPathComponent]];
		[[NSFileManager defaultManager] createFileAtPath: destFile
												contents: [NSData data]
											  attributes: nil];

		[result setArguments: [NSArray arrayWithObjects: 
			@"cat",
			@"-",
			nil]];
		[result setStandardOutput: [NSFileHandle fileHandleForWritingAtPath: destFile]];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(taskDidTerminate:)
												 name: NSTaskDidTerminateNotification
											   object: result];
	return result;
}

- (void) unarchiveFile {
	// Create the unarchiving task
	[task release]; task = nil;
	task = [[self unarchiveFile: tmpFile
					toDirectory: [self directoryForUnarchiving]] retain];
	
	if (task == nil) {
		// Oops: couldn't create the task
		[self failed];
		return;
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath: tmpFile]) {
		// Oops, the download file doesn't exist
		[self failed];
		return;
	}
	
	// Set the input file handle for the main task
	NSLog(@"Unarchiving %@ to %@", tmpFile, tmpDirectory);
	[task setStandardInput: [NSFileHandle fileHandleForReadingAtPath: tmpFile]];
	
	// Notify the delegate that we're starting to unarchive the 
	if (delegate && [delegate respondsToSelector: @selector(download:completed:)]) {
		[delegate download: self
				 completed: -1];
	}
	if (delegate && [delegate respondsToSelector: @selector(downloadUnarchiving:)]) {
		[delegate downloadUnarchiving: self];
	}
	
	// Start the tasks
	if (subtasks != nil) {
		NSEnumerator* taskEnum = [subtasks objectEnumerator];
		NSTask* sub;
		while (sub = [taskEnum nextObject]) {
			[sub launch];
		}
	}
	[task launch];
}

// = NSURLConnection delegate =

- (NSString*) fullExtensionFor: (NSString*) filename {
	NSString* extension = [filename pathExtension];
	NSString* withoutExtension = [filename stringByDeletingPathExtension];
	
	if (extension == nil || [extension length] <= 0) return nil;
	
	NSString* extraExtension = [self fullExtensionFor: withoutExtension];
	if (extraExtension != nil) {
		return [extraExtension stringByAppendingPathExtension: extension];
	} else {
		return extension;
	}
}

- (void)  connection:(NSURLConnection *)conn
  didReceiveResponse:(NSURLResponse *)response {
	int status = 200;
	if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
		status = [(NSHTTPURLResponse*)response statusCode];
	}
	
	if (status >= 400) {
		// Failure: give up
		NSLog(@"Error: %i", status);
		
		[self failed];
		return;
	}
	
	expectedLength = [response expectedContentLength];
	downloadedSoFar = 0;
	
	// Create the download directory if it doesn't exist
	[self createDownloadDirectory];
	
	// Create the download file
	[tmpFile release];
	tmpFile = [downloadDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"download-%i", lastDownloadId++]];
	tmpFile = [tmpFile stringByAppendingPathExtension: [self fullExtensionFor: [response suggestedFilename]]];
	[tmpFile retain];
	
	if (downloadFile) {
		[downloadFile closeFile];
		[downloadFile release];
		downloadFile = nil;
	}
	NSLog(@"Downloading to %@", tmpFile);
	[[NSFileManager defaultManager] createFileAtPath: tmpFile
											contents: [NSData data]
										  attributes: nil];
	downloadFile = [[NSFileHandle fileHandleForWritingAtPath: tmpFile] retain];
	
	if (downloadFile == nil) {
		// Failed to create the download file
		NSLog(@"...Could not create file");
		
		[self failed];
		return;
	}
	
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
	[self failed];
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
		NSString* directory = [self directoryForUnarchiving];
		if (directory == nil) {
			// Couldn't create the directory
			[self failed];
			return;
		}
		
		// Unarchive the file if it's a zip or a tar file, or move it to the download directory
		[self unarchiveFile];
	}
}

// = NSTask delegate =

- (void) taskDidTerminate: (NSNotification*) not {
	// Do nothing if no task is running
	if (task == nil) return;
	
	// Check if all of the tasks have finished
	BOOL finished = YES;
	BOOL succeeded = YES;
	
	if (subtasks) {
		NSEnumerator* taskEnum = [subtasks objectEnumerator];
		NSTask* sub;
		while (sub = [taskEnum nextObject]) {
			if ([sub isRunning]) {
				finished = NO;
			} else if ([sub terminationStatus] != 0) {
				succeeded = NO;
			}
		}
	}
	if ([task isRunning]) {
		finished = NO;
	} else if ([task terminationStatus] != 0) {
		succeeded = NO;
	}
	
	if (!succeeded) {
		// Oops, failed
		NSLog(@"Failed to unarchive %@", tmpFile);
		[self failed];
		return;
	} else if (finished) {
		// Download has successfully completed
		NSLog(@"Unarchiving task succeeded");
		[self succeeded];
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
