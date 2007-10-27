#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import "ZoomSkein.h"
#import "ZoomMetadata.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

static NSString* zoomConfigDirectory() {
	NSArray* libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	
	NSEnumerator* libEnum;
	NSString* libDir;
	
	libEnum = [libraryDirs objectEnumerator];
	
	while (libDir = [libEnum nextObject]) {
		BOOL isDir;
		
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] fileExistsAtPath: zoomLib isDirectory: &isDir]) {
			if (isDir) {
				return zoomLib;
			}
		}
	}
	
	libEnum = [libraryDirs objectEnumerator];
	
	while (libDir = [libEnum nextObject]) {
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] createDirectoryAtPath: zoomLib
													   attributes:nil]) {
			return zoomLib;
		}
	}
	
	return nil;
}

OSStatus GeneratePreviewForURL(void *thisInterface, 
							   QLPreviewRequestRef preview,
							   CFURLRef cfUrl, 
							   CFStringRef contentTypeUTI, 
							   CFDictionaryRef options)
{
	NSURL* url = (NSURL*)cfUrl;
	NSData* skeinData = nil;
	ZoomSkein* skein = nil;
	ZoomStoryID* storyID = nil;
	
	// Read the data for this file
	if ([(NSString*)contentTypeUTI isEqualToString: @"uk.org.logicalshift.zoomsave"]) {
		// .zoomsave package
		
		// Read in the skein
		NSURL* skeinUrl = [NSURL URLWithString: [[url absoluteString] stringByAppendingString: @"/Skein.skein"]];
		skeinData = [NSData dataWithContentsOfURL: skeinUrl];
		
		// Work out the story ID
		NSURL* plistUrl = [NSURL URLWithString: [[url absoluteString] stringByAppendingString: @"/Info.plist"]];
		NSData* plist = [NSData dataWithContentsOfURL: plistUrl];
		
		if (plist != nil) {
			NSDictionary* plistDict = [NSPropertyListSerialization propertyListFromData: plist
																	   mutabilityOption: NSPropertyListImmutable
																				 format: nil
																	   errorDescription: nil];
			NSString* idString  = [plistDict objectForKey: @"ZoomStoryId"];
			if (idString != nil) {
				storyID = [[[ZoomStoryID alloc] initWithIdString: idString] autorelease];
			}
		}
		
	} else if ([(NSString*)contentTypeUTI isEqualToString: @"uk.org.logicalshift.glksave"]) {
		// .glksave package
		
		// Read in the skein
		NSURL* skeinUrl = [NSURL URLWithString: [[url absoluteString] stringByAppendingString: @"/Skein.skein"]];
		skeinData = [NSData dataWithContentsOfURL: skeinUrl];

		
		// Work out the story ID
		NSURL* plistUrl = [NSURL URLWithString: [[url absoluteString] stringByAppendingString: @"/Info.plist"]];
		NSData* plist = [NSData dataWithContentsOfURL: plistUrl];
		
		if (plist != nil) {
			NSDictionary* plistDict = [NSPropertyListSerialization propertyListFromData: plist
																	   mutabilityOption: NSPropertyListImmutable
																				 format: nil
																	   errorDescription: nil];
			NSString* idString  = [plistDict objectForKey: @"ZoomGlkGameId"];
			if (idString != nil) {
				storyID = [[[ZoomStoryID alloc] initWithIdString: idString] autorelease];
			}
		}
	}
	
	// Try to parse the skein
	if (skeinData) {
		skein = [[[ZoomSkein alloc] init] autorelease];
		if (![skein parseXmlData: skeinData]) {
			skein = nil;
		}
	}
	
	// If we've got a skein, then generate an attributed string to represent the transcript of play
	if (skein && [skein activeItem]) {
		NSMutableAttributedString* result = [[[NSMutableAttributedString alloc] init] autorelease];
		ZoomSkeinItem* activeItem = [skein activeItem];
		
		// Set up the attributes for the fonts
		NSFont* transcriptFont = [[NSFontManager sharedFontManager] fontWithFamily: @"Gill Sans"
																			traits: NSUnboldFontMask
																			weight: 5
																			  size: 12];
		NSFont* inputFont = [[NSFontManager sharedFontManager] fontWithFamily: @"Gill Sans"
																	   traits: NSBoldFontMask
																	   weight: 9
																	     size: 12];
		NSFont* titleFont = [[NSFontManager sharedFontManager] fontWithFamily: @"Gill Sans"
																	   traits: NSBoldFontMask
																	   weight: 9
																	     size: 18];
		if (!transcriptFont) transcriptFont = [NSFont systemFontOfSize: 12];
		if (!inputFont) inputFont = [NSFont systemFontOfSize: 12];
		if (!titleFont) titleFont = [NSFont boldSystemFontOfSize: 12];
		
		NSDictionary* transcriptAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
											  transcriptFont, NSFontAttributeName,
											  nil];
		NSDictionary* inputAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
										 inputFont, NSFontAttributeName,
										 nil];
		NSDictionary* titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
										 titleFont, NSFontAttributeName,
										 nil];
		NSAttributedString* newline = [[[NSAttributedString alloc] initWithString: @"\n"
																	   attributes: transcriptAttributes] autorelease];
		
		// Build the transcript
		while (activeItem != nil) {
			// Append this string
			NSAttributedString* inputString = nil;
			NSAttributedString* responseString = nil;
			
			if ([activeItem command]) {
				inputString = [[NSAttributedString alloc] initWithString: [activeItem command]
															  attributes: inputAttributes];				
			}
			if ([activeItem result]) {
				responseString = [[NSAttributedString alloc] initWithString: [activeItem result]
																 attributes: transcriptAttributes];				
			}
			
			if (responseString) {
				[result insertAttributedString: responseString
									   atIndex: 0];				
			}
			if (inputString && [activeItem parent]) {
				[result insertAttributedString: newline
									   atIndex: 0];
				[result insertAttributedString: inputString
									   atIndex: 0];				
			}
			
			// Finish up
			[inputString release];
			[responseString release];
			
			// Move up the tree
			activeItem = [activeItem parent];
		}
		
		// Add a title indicating which game this came from
		if (storyID) {
			// Write out the story ID
			[result insertAttributedString: newline
								   atIndex: 0];
			[result insertAttributedString: newline
								   atIndex: 0];
			[result insertAttributedString: [[[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"IFID: %@", [storyID description]]
																			 attributes: inputAttributes] autorelease]
								   atIndex: 0];
			
			// Try to read the metadata for this story, if there is any
			ZoomMetadata* metadata = nil;
			ZoomStory* story = nil;
			NSData* userData = [NSData dataWithContentsOfFile: [zoomConfigDirectory() stringByAppendingPathComponent: @"metadata.iFiction"]];
			if (userData) metadata = [[[ZoomMetadata alloc] initWithData: userData] autorelease];
			
			if (metadata) {
				story = [metadata containsStoryWithIdent: storyID]?[metadata findOrCreateStory: storyID]:nil;
			}
			
			if (story && [[story title] length] > 0) {
				[result insertAttributedString: newline
									   atIndex: 0];
				[result insertAttributedString: [[[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"Saved game from %@", [story title]]
																				 attributes: titleAttributes] autorelease]
									   atIndex: 0];				
			}
		}
		
		// Set the quicklook data
		NSData *theRTF = [result RTFFromRange:NSMakeRange(0, [result length]-1) documentAttributes:nil];
		QLPreviewRequestSetDataRepresentation(preview, (CFDataRef)theRTF, kUTTypeRTF, NULL);
	}
	
    return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
