//
//  ZoomSkeinXML.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkein.h"

static NSString* idForNode(ZoomSkeinItem* item) {
	// Unique ID for this item (we use the pointer as the value, as it's guaranteed unique for a unique node)
	return [NSString stringWithFormat: @"node-%p", item];
}

static NSString* xmlEncode(NSString* str) {
	return str;
}

@implementation ZoomSkein(ZoomSkeinXML)

// = XML data =

// Creating XML
- (NSString*) xmlData {
	// Structure summary (note to me: write this up properly later)
	
	// <Skein rootNode="<nodeID>" xmlns="http://www.logicalshift.org.uk/IF/Skein">
	//   <generator>Zoom</generator>
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
	[result appendString: 
		[NSString stringWithFormat: @"<Skein rootNode=\"%@\" xmlns=\"http://www.logicalshift.org.uk/IF/Skein\">\n",
			idForNode(rootItem)]];
	[result appendString: @"  <generator>Zoom</generator>\n"];
	
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
			[result appendFormat: @"    <command>%@</command>\n",
				xmlEncode([node command])];
		if ([node result] != nil)
			[result appendFormat: @"    <result>%@</result>\n",
				xmlEncode([node result])];
		if ([node annotation] != nil)
			[result appendFormat: @"    <annotation>%@</annotation>\n",
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
// Have to use expat: 

@end
