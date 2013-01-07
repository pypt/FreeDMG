/*
	File:		FDImageView.m
 
	Contains:	Drag and Drop with ImageView
 
	Author: 	eK
 
	Copyright (C) 2004-2008 Eddie Kelley <eddie@kelleycomputing.net>
 
	This file is part of FreeDMG
	
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
 
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
 
	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
	Change History (most recent first):
 
 02/2005		1.2	Changed drag operation to copy.
 04/2004		1.1	Modified by Eddie Kelley for use with FreeDMG program
 01/2002		initial version - Concepts from Apple sample source code
 */

#import "FDImageView.h"
#import "FDController.h"

@implementation FDImageView

-(void) awakeFromNib{
}

- (id)initWithCoder:(NSCoder *)coder
{
    /*------------------------------------------------------
	Init method called for Interface Builder objects
    --------------------------------------------------------*/
    if(self=[super initWithCoder:coder]){
		[super setEditable:FALSE];
        //register for all the image types we can display
        [self registerForDraggedTypes:[NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
    }
    return self;
}

#pragma mark Destination Operations

//Destination Operations
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
	method called whenever a drag enters our drop zone
	--------------------------------------------------------*/
    // Check if the pasteboard contains image data and source/user wants it copied
	if (NSDragOperationCopy) {
		highlight=YES;//highlight our drop zone
		[self setImage:[NSImage imageNamed:@"FreeDMG_largeMask.png"]];
		[self setNeedsDisplay: YES];
		return NSDragOperationCopy; //accept data as a copy operation
	}
    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
	method called whenever a drag exits our drop zone
    --------------------------------------------------------*/
    highlight=NO;//remove highlight of the drop zone
	[self setImage:[NSImage imageNamed:@"FreeDMG_large.png"]];
    [self setNeedsDisplay: YES];
}

-(void)drawRect:(NSRect)rect
{
    /*------------------------------------------------------
	draw method is overridden to do drop highlighing
    --------------------------------------------------------*/
	[super drawRect:rect];//do the usual draw operation to display the default image
    if(highlight){
        //highlight by overlaying a gray border
        [[NSColor grayColor] set];
        [NSBezierPath setDefaultLineWidth: 5];
        [NSBezierPath strokeRect: rect];
    }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
	method to determine if we can accept the drop
    --------------------------------------------------------*/
    highlight=NO;//finished with the drag so remove any highlighting
	[self setImage:[NSImage imageNamed:@"FreeDMG_large.png"]];
	[self setNeedsDisplay: YES];
    //just accept the data
    return NSDragOperationCopy;
} 

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
	method that should handle the drop data
    --------------------------------------------------------*/
	if([sender draggingSource] != self){
		// Get the drag-n-drop pasteboard
		NSPasteboard *myPasteboard=[sender draggingPasteboard];
		// set the view's drop array to equal the pasteboard's
		dropArray = [myPasteboard propertyListForType:NSFilenamesPboardType];
	}
    return YES;
}

-(void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[self setImage:[NSImage imageNamed:@"FreeDMG_large.png"]];
	[self sendAction:[self action] to:[self target]];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    /*------------------------------------------------------
	accept activation click as click in window
    --------------------------------------------------------*/
	
	[self setNeedsDisplay:YES];
    return YES;//so source doesn't have to be the active window
}

#pragma mark Data Accessors

- (NSArray*) dropArray{
	/*------------------------------------------------------
	return the dropArray object
    --------------------------------------------------------*/
	NSArray * passArray = [NSArray arrayWithArray:dropArray];
	return passArray;
}

@end
