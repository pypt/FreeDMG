/*
	File:		FDImageView.h
 
	Contains:	Drag and Drop using NSImageView
 
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
 
 01/2002		initial version
 */

#import <Cocoa/Cocoa.h>

@interface FDImageView : NSImageView
{
    BOOL highlight;//highlight the drop zone
	NSArray *dropArray;
}

- (NSArray*)dropArray;
- (id)initWithCoder:(NSCoder *)coder;
@end
