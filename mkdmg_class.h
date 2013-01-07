/*
 mkdmg_class.h
 FreeDMG

 Created by Eddie Kelley on 8/10/04.
 
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


	A command line program that will make disk image files. 
	As many source files as the user chooses can be secured into images of the .dmg, .img, .cdr, and .sparseimge formats
	Encryption (password protection) can be applied to images
	Images can be made internet enabled
	This program can be forced to overwrite existing files automatically

 Change history (most recent first)
 
	10/12/08 0.2	   -eK- Minor version change
						mkdmg now uses getopts to parse arguments
						Verifies existance of source files before imaging
 
	12/9/2007 0.1.6.6  -eK- Minor beta version change
						Added support for sparsebundles (available in 10.5)
 
	11/1/2007 0.1.6.5  -eK- Minor beta version change
						Changed -getDevPathFromFile: - now works with images using a guid partition scheme (Intel machines)
 
	09/11/2005 0.1.6.4 -eK- Minor beta version change
						Added bzip2 support for Mac OS 10.4+
 
	05/17/1005 0.1.6.3 -eK- Minor beta version change
						Now displays progress using "puppetstrings" for parsing by other applications
 
	04/15/2005 0.1.6.2 -eK- Minor beta bersion change
						No longer attempts to copy ".Trashes" files
						Fixed bug - non-removal of temp file on error
 
	04/7/2005 0.1.6.1 -eK-	Minor Beta version change
						Added -o command line option (overwrites files with same label as image)
						Now removes pathnames from anything following: ".app", ".pkg", ",mpkg", ".nib"
			
	04/5/2005 0.1.6 -eK-	Minor version change
						Added zlib compression level option (1..9)
 
	04/2/2005 0.1.5	-eK-	Minor version change
						Added compression options
						Added encryption option

	03/17/2005 0.1.4.3 -eK- bug fixes -
						repairs major memory allocation problems present in 0.1.4.2
						no longer removes path extensions from image path

	01/29/2005 0.1.4.2 -eK bug fixes -
						no longer accepts input without source specified after -s flag
						NSAutoreleasePool used in while loops to release memory more efficiently

	01/15/2005 0.1.4.1 -eK- bug fixes -
						checks for locked volume or read-only dir for chosen imaging location
	
	12/29/2004 0.1.4 -eK- bug fixes -
						reverted to old imageSizeFromPath function after repairing bug in du calculations function.
						made sub-process into individual functions


	10/24/2004 0.1.3 -eK- bug fixes - 
						  re-wrote imageSizeFromPaths to get around multiple source file limit
						  no longer uses 'du' to determine file sizes (uses NSFileManager)
						  program now checks available disk space before imaging

	09/12/2004 0.1.2 -eK- added -v (verbose) option
						 added -e (internet enabled disk image) option

	08/30/2004 0.1.1 -eK- added -format option
			user can now specify UDZO vs. UDCO compression

	08/15/2004 0.1 -eK- initial version
*/

#import <Foundation/Foundation.h>

@interface mkdmg_class : NSObject{

}

// Variables
BOOL verbose, internetEnabled, encryption, overwrite, puppetStrings;
int compressionLevel;
NSString * format, *encryptionType, *mountPoint, *imageName, *devPath;

// SIG handler
void exceptionHandler(NSException *exception);

	/* 
	Help function.  This procedure will output the help (usage) to stdout
	Input: none
	Output: none
	Prerequisites: none
*/
-(void) help;

/* 
	evaluateInput function.  This procedure will output 0 if the input is valid, -1 on error
	Input: NSMutableArray - input arguments
	Output: int
	Prerequisites: none
*/

// set disk image format
-(void) setFormat:(NSString*)newFormat;

// get disk image format string
-(NSString*) format;

// set th encryption type (of AES-128 or AES-256 on leopard)
-(void)setEncryptionType:(NSString*)newType;

-(NSString*) encryptionType;

/* 
 evaluateInput function.  
 This procedure evaluates arguments passed to the mkdmg program,
 and determines how to handle input (this kicks off the imaging process).
 Input: char** (arguments), argc (argument count)
 Output: int
 Prerequisites: input should not be nil; 
 should match format as specified in usage
 */

-(int) evaluateInput:(const char**)argv count:(int)argc;

/* 
	Cleanup function.  This procedure removes 'imageName' from /tmp, and unmounts 'mountPoint'
	Input: NSString (imageName), NSString (mountPoint)
	Output: int
	Prerequisites: input should not be nil
*/

-(int) cleanupImage:(NSString*)imageName mountPoint:(NSString*)mountPoint;

/* 
		make specified image (path) into an internet-enabled image
		Input:NSString(path) - path to image
		Output: int - hdiutil error/return code 
 */
-(int) makeImageInternetEnabled:(NSString *)path;

/* 
	makeImage function.  This procedure will will make an image at 'path' from 'files'
	Input: NSString (path for new image), NSArray (files to image)
	Output: int
	Prerequisites: path should not exist; files should not be nil
*/
-(int) makeImage:(NSString*)path fromFiles:(NSArray*)files;

/* 
	imageSizeFromPaths function.  This procedure will output the size of 'paths'
	Input: NSArray (paths of files to calculate)
	Output: NSNumber (estimated size of image needed to copy all files in 'files')
	Prerequisites: paths should not be nil
*/

-(NSNumber*) imageSizeFromPaths:(NSArray*)paths;

/* 
	openProgram: withArguments function.  This procedure will output the result of executing
		'programPath' with arguments 'arguments'
	Input: NSString 'programPath', NSArray 'arguments'
	Output: results (NSString)
	Prerequisites: program should exist on disk, and should accept arguments
*/

-(NSString*) openProgram:(NSString*)programPath withArguments:(NSArray*) arguments;

/* 
 isTiger function.  This procedure will output YES if system is 10.4, otherwise NO
 Input: none
 Output: BOOL
 Prerequisites: none
 */

-(BOOL) isTiger;

@end
