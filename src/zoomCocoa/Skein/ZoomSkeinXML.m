//
//  ZoomSkeinXML.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkein.h"

#include <expat.h>

static NSString* idForNode(ZoomSkeinItem* item) {
	// Unique ID for this item (we use the pointer as the value, as it's guaranteed unique for a unique node)
	return [NSString stringWithFormat: @"node-%p", item];
}

static NSString* xmlEncode(NSString* str) {
	int x;
	
	// Grr, Cocoa has no 'append character' thing in NSMutableString, which is daft
	// To avoid being slower than a turtle embedded in cement, do everything manually
	static unichar* res = nil;
	int resLen = 0;
	int maxLen = 0;
	
	inline void append(unichar chr) {
		while (resLen >= maxLen) {
			maxLen += 256;
			res = realloc(res, sizeof(unichar)*maxLen);
		}
		
		res[resLen++] = chr;
	}
	inline void appendStr(NSString* str) {
		int x;
		for (x=0; x<[str length]; x++) {
			append([str characterAtIndex: x]);
		}
	}
	
	// Actually convert the string
	for (x=0; x<[str length]; x++) {
		unichar chr = [str characterAtIndex: x];
		
		if (chr == '\n') {
			append('\n');
		} else if (chr == '&') {
			appendStr(@"&amp;");
		} else if (chr == '<') {
			appendStr(@"&lt;");
		} else if (chr == '"') {
			appendStr(@"&quot;");
		} else if (chr == '\'') {
			appendStr(@"&apos;");
		} else if (chr < 0x20) {
			// Ignore
		} else {
			// NOTE/FIXME: Surrogate characters are not handled correctly
			// May, I suppose, cause a problem with chinese IF
			append(chr);
		}
	}
	
	return [NSString stringWithCharacters: res
								   length: resLen];
}

@implementation ZoomSkein(ZoomSkeinXML)

// = XML data =

// Creating XML
- (NSString*) xmlData {
	// Structure summary (note to me: write this up properly later)
	
	// <Skein rootNode="<nodeID>" xmlns="http://www.logicalshift.org.uk/IF/Skein">
	//   <generator>Zoom</generator>
	//   <activeItem nodeId="<nodeID" />
	//   <item nodeId="<nodeID>">
	//     <command/>
	//     <result/>
	//     <annotation/>
	//     <played>YES/NO</played>
	//     <changed>YES/NO</changed>
	//     <temporary score="score">YES/NO</temporary>
	//     <children>
	//       <child nodeId="<nodeID>"/>
	//     </children>
	//   </item>
	// </Skein>
	//
	// nodeIDs are string uniquely identifying a node: any format
	// A node must not be a child of more than one item
	// All item fields are optional.
	// Root item usually has the command '- start -'
	
	NSMutableString* result = [[[NSMutableString alloc] init] autorelease];
	
	// Write header
	[result appendFormat: 
		@"<Skein rootNode=\"%@\" xmlns=\"http://www.logicalshift.org.uk/IF/Skein\">\n",
			idForNode(rootItem)];
	[result appendString: @"  <generator>Zoom</generator>\n"];
	[result appendFormat: @"  <activeNode nodeId=\"%@\" />\n", idForNode(activeItem)];
	
	// Write items
	NSMutableArray* itemStack = [NSMutableArray array];
	[itemStack addObject: rootItem];
	
	while ([itemStack count] > 0) {
		// Pop from the stack
		ZoomSkeinItem* node = [[itemStack lastObject] retain];
		[itemStack removeLastObject];
		
		// Push any children of this node
		NSEnumerator* childEnum = [[node children] objectEnumerator];
		ZoomSkeinItem* childNode;
		while (childNode = [childEnum nextObject]) {
			[itemStack addObject: childNode];
		}
		
		// Generate the XML for this node
		[result appendFormat: @"  <item nodeId=\"%@\">\n",
			idForNode(node)];
		
		if ([node command] != nil)
			[result appendFormat: @"    <command xml:space=\"preserve\">%@</command>\n",
				xmlEncode([node command])];
		if ([node result] != nil)
			[result appendFormat: @"    <result xml:space=\"preserve\">%@</result>\n",
				xmlEncode([node result])];
		if ([node annotation] != nil)
			[result appendFormat: @"    <annotation xml:space=\"preserve\">%@</annotation>\n",
				xmlEncode([node annotation])];
		
		[result appendFormat: @"    <played>%@</played>\n",
			[node played]?@"YES":@"NO"];
		[result appendFormat: @"    <changed>%@</changed>\n",
			[node changed]?@"YES":@"NO"];
		[result appendFormat: @"    <temporary score=\"%i\">%@</temporary>\n",
			[node temporaryScore], [node temporary]?@"YES":@"NO"];
		
		if ([[node children] count] > 0) {
			[result appendString: @"    <children>\n"];
			
			childEnum = [[node children] objectEnumerator];
			while (childNode = [childEnum nextObject]) {
				[result appendFormat: @"      <child nodeId=\"%@\" />\n",
					idForNode(childNode)];
			}
			
			[result appendString: @"    </children>\n"];
		}
		
		[result appendString: @"  </item>\n"];
		
		[node release];
	}
	
	// Write footer
	[result appendString: @"</Skein>\n"];
	
	return result;
}

// Parsing the XML
// Have to use expat: Apple's own XML parser is not available in Jaguar
// The Cocoa XML parser is pretty crappy anyway...
- (void) parseXmlData: (NSData*) data {
}

@end
