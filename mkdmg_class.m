/*
  mkdmg_class.m
  FreeDMG
 
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
 
 */

#import "mkdmg_class.h"
#include <stdio.h>
#include <unistd.h>

#define __version__ "0.2"


@implementation mkdmg_class

-(id) init
{
	[super init];
	NSSetUncaughtExceptionHandler(&exceptionHandler);
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

void exceptionHandler(NSException *exception){
	NSLog([exception name]);
}

#pragma mark UI

-(void) help
{
	printf("mkdmg version: " __version__ "\n");
	printf("usage: mkdmg -h (displays this message)\n");
	printf("	mkdmg [-v] [-e] [-c [AES-128 | AES-256]] [-o] -i image source\n");
	printf("	mkdmg -i image source1 source2 source3 ...\n");
	printf("	mkdmg [options] [-f  UDZO | UDCO | UDRW | UDRO | UDSP | UDSB | UDBZ | ... ] [-z 1..9] -i image source\n\n");
	printf("		-v: verbose mode\n");
	printf("		-e: internet enabled image\n");
	printf("		-c: encrypt image with optional strength\n");
	printf("		-o: overwrite existing files\n");
	printf("		-V: print mkdmg version and exit\n");
	printf("		-i: image file (this path may change, depending on image format)\n");
	printf("		-f: format of the image(examples: UDZO or UDCO)\n");
	printf("			-All compression formats supported in hdiutil should be available in mkdmg\n");
	printf("		-z: UDZO accepts 1..9 for zlib compression level\n");
}

#pragma mark DiskImaging

-(NSString*) format
{
	return format;
}

-(void) setFormat:(NSString*)newFormat
{
	format = [NSString stringWithString:newFormat];
}

-(void)setEncryptionType:(NSString*)newType
{
	encryptionType = [NSString stringWithString:newType];
}

-(NSString*) encryptionType
{
	return encryptionType;
}

-(int) compressionLevel
{
	return compressionLevel;
}

- (void) setCompressionLevel:(int)newCompressionLevel
{
	compressionLevel = newCompressionLevel;
}

- (NSString *) pathExtension
{
	NSString * pathExtension;
	
	if([[self format] isEqualToString:@"UDRW"] || [[self format] isEqualToString:@"UDRO"] || [[self format] isEqualToString:@"UDCO"] || 
		[[self format] isEqualToString:@"UDZO"] || [[self format] isEqualToString:@"UDBZ"] || [[self format] isEqualToString:@"UFBI"] || [[self format] isEqualToString:@"UDxx"]){
		pathExtension = [NSString stringWithString:@"dmg"];
	}
	else if([[self format] isEqualToString:@"UDTO"]){
		pathExtension = [NSString stringWithString:@"cdr"];
	}
	else if([[self format] isEqualToString:@"UDSP"]){
		pathExtension = [NSString stringWithString:@"sparseimage"];
	}	
	else if([[self format] isEqualToString:@"UDSB"]){
		pathExtension = [NSString stringWithString:@"sparsebundle"];
	}	
	else if([[self format] isEqualToString:@"RdWr"] || [[self format] isEqualToString:@"Rdxx"] || [[self format] isEqualToString:@"ROCo"] ||
			[[self format] isEqualToString:@"DC42"]){
		pathExtension = [NSString stringWithString:@"img"];
	}
	else
		pathExtension = [NSString stringWithString:@"dmg"];
	
	return pathExtension; 
}

-(BOOL) isWriteableDirectoryAtPath:(NSString*)path
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL status = NO;
	
	if([fileManager fileExistsAtPath:path isDirectory:nil])
	{
		if([fileManager createDirectoryAtPath:[path stringByAppendingPathComponent:@"mkdmgTestDir"] attributes:nil])
		{
			if([fileManager removeFileAtPath:[path stringByAppendingPathComponent:@"mkdmgTestDir"] handler:nil])
			{
				status = YES;
			}
			else
				status = NO;
		}
		else
			status = NO;
	}
	return status;
}

-(NSNumber*) imageSizeFromPaths:(NSArray*)paths
{
	
	int i = 0;
	double totalImageSize = 0, percent = 0, pathsCount = [paths count];
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *output, *temp;
	NSScanner *outputScanner;
	NSCharacterSet *whiteCharacterSet = [NSCharacterSet whitespaceCharacterSet];
	
	while (i < pathsCount)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// use du to calculate folder sizes
		if([manager fileExistsAtPath:[paths objectAtIndex:i]])
		{
			if(![[[paths objectAtIndex:i] lastPathComponent] isEqual:@".Trashes"]){
				output = [self openProgram:@"/usr/bin/du" withArguments:[NSArray arrayWithObjects: @"-skxP", [paths objectAtIndex:i], nil]];
				outputScanner = [[[NSScanner alloc] initWithString:output] autorelease];
				temp = [[[NSString alloc] init] autorelease];
				[outputScanner scanUpToCharactersFromSet:whiteCharacterSet intoString:&temp];
				if([temp doubleValue] < 0)
				{
				// error reported during calculation
					totalImageSize = -1;
					i = pathsCount;
				}
				else
					totalImageSize += [temp doubleValue];
			}
			i++;
			if(verbose){
				percent = ((i/pathsCount) * 100);
				NSLog(@"PERCENT:%f\n", percent);
			}
		}
		else{
			totalImageSize = -1;
			i = [paths count];
			percent = i;
		}
		[pool release];
	}
	
	
	NSLog(@"PERCENT:%d\n", -1);
	if(verbose)
		NSLog(@"Image size:%fK", totalImageSize);
	return [NSNumber numberWithDouble:totalImageSize];
}

-(id) createImageOfSize:(NSNumber*)size atPath:(NSString*)path
{
	if(![path isEqual:nil] && ([size doubleValue] > 0))
		return [self openProgram:@"/usr/bin/hdiutil" withArguments:
			[NSArray arrayWithObjects:@"create", @"-size", [[size stringValue] stringByAppendingString:@"k"], [path retain],nil]];
	else
		return [NSNumber numberWithInt:-1];
}

-(id) createSparseImageAtPath:(NSString*)path
{
	if(![path isEqual:nil])
	{
		return [self openProgram:@"/usr/bin/hdiutil" withArguments:
			[NSArray arrayWithObjects:@"create", @"-size", @"10000k", [path retain], nil]];
		
	}
	else
		return [NSNumber numberWithInt:-1];
}

-(id) getDevPathFromFile:(NSString*)file
{
	if(![file isEqual:nil]){
		
		NSDictionary *imageDict = [[NSDictionary alloc] initWithDictionary:[[self openProgram:@"/usr/bin/hdid" withArguments:[NSArray arrayWithObjects: @"-nomount", @"-plist", file, nil]] propertyList]];
		int i = 0;
		for(i=0;i < [[imageDict objectForKey:@"system-entities"] count]; ++i)
		{
			// find the "Apple_HFS" partition
			if([[[[imageDict objectForKey:@"system-entities"] objectAtIndex:i] objectForKey:@"content-hint"] isEqual:@"Apple_HFS"])
				return [[[[imageDict objectForKey:@"system-entities"] objectAtIndex:i] objectForKey:@"dev-entry"] autorelease];																  
		}
	}
	return NULL;
}

-(id) createFilesystem:(NSString*)fs withLabel:(NSString*)name atPath:(NSString*)path
{
	return [self openProgram:@"/sbin/newfs_hfs" withArguments:[NSArray arrayWithObjects: @"-v", name, path, nil]];
	
}

-(id) createMountPointAtPath:(NSString*)path
{
	return [self openProgram:@"/bin/mkdir" withArguments:[NSArray arrayWithObjects: path, nil]];
}

-(id) mountDevice:(NSString*)dev mountPoint:(NSString*)mntpt
{
	return [self openProgram: @"/sbin/mount" withArguments:
		[NSArray arrayWithObjects:@"-v", @"-t", @"hfs", @"-o", @"perm", dev, mntpt, nil]];
}

-(id) copyFiles:(NSArray*)files toPath:(NSString*)path
{
	/////
	// copy source files
	/////
	int i = 0, status = 0;
	double percent = 0, fileCount = [files count];
	
	while (i < fileCount)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

		NSString *source = [[[NSString alloc] initWithString:[files objectAtIndex:i]] autorelease];
		NSString *baseName = [[[NSString alloc] initWithString:[source lastPathComponent]] autorelease];
		NSString *temp = nil;
		
		if(![[source lastPathComponent] isEqual:@".Trashes"])
			temp = [[self openProgram:@"/usr/bin/ditto" withArguments:[NSArray arrayWithObjects:@"-rsrcFork", source, [[path stringByAppendingString:@"/"] stringByAppendingString:baseName], nil]] autorelease];
		else
			temp = @"0";
		
		if([temp intValue] == 0)
		{
			i++;
			if(verbose){
				percent = ((i/fileCount) * 100);
				NSLog(@"PERCENT:%f\n", percent);
			}
		}
		else
		{
			i = [files count];
			if(verbose){
				percent = 100;
				NSLog(@"PERCENT:%f\n", percent);
			}
		}
		if(![temp isEqual:nil])
			status = [temp intValue];
		[pool release];
	}
	return [NSNumber numberWithInt:status];
}

-(id) unmountDeviceWithMountPoint:(NSString*)mntpt
{
	NSLog(@"PERCENT:%d\n", -1);
	return [self openProgram:@"/sbin/umount" withArguments:[NSArray arrayWithObjects: mntpt, nil]];
}

-(id) ejectDevice:(NSString*)dev
{
	NSLog(@"PERCENT:%d", -1);
	return  [self openProgram:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"eject", dev, nil]];	
}

-(id) convertImageAtPath:(NSString*)path moveToPath:(NSString*)newPath
{
	// Variables
	int error = 0;
	NSString* temp;
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:1];
	
	// add basic convert options to arguments
	[arguments addObjectsFromArray:[NSArray arrayWithObjects:@"convert", path, @"-format", [self format],
		@"-o", newPath, nil]];
	
	// add optional encryption options to arguments
	if(encryption)
	{
		[arguments addObject:@"-encryption"];
		if(![self isTiger] && ![[self encryptionType] isEqual:@""])
		{
			[arguments addObject:[self encryptionType]];
		}
	}
	
	// add optional zlib compression with UDZO format to arguments
	if([[self format] isEqual:@"UDZO"])
	{
		[arguments addObject:@"-imagekey"];
		[arguments addObject: [@"zlib-level=" stringByAppendingString:[[NSNumber numberWithInt:[self compressionLevel]] stringValue]]];
	}
	// run hdiutil with arguments, and capture its output
	temp = [self openProgram:@"/usr/bin/hdiutil" withArguments:arguments];
	
	error = [temp intValue];
	
	return [NSNumber numberWithInt:error];
}

-(int) makeImageInternetEnabled:(NSString*)path
{
	// convert image at path into an internet-enabled disk image
	NSString *output = nil;
	output = [self openProgram:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"internet-enable", @"-quiet" , @"-yes", path ,nil]];
	return [output intValue];
	
}

// this is the cleanup function for the program.  
// This removes the /dev entry, and the /tmp mount point created when imaging
-(int) cleanupImage:(NSString*)imageName mountPoint:(NSString*)mountPoint
{
	NSFileManager * manager = [NSFileManager defaultManager];
	if([manager fileExistsAtPath:imageName])
		[self openProgram:@"/bin/rm" withArguments:[NSArray arrayWithObjects:imageName, nil]]; // Get rid of the ${ImageName}
    if([manager fileExistsAtPath:mountPoint])
		[self openProgram:@"/bin/rmdir" withArguments:[NSArray arrayWithObjects:mountPoint, nil]];  // and the ${MountPoint}
	return 0;
}

-(int) exitOnErrorWithImage:(NSString*)imagePath mountPoint:(NSString*)mountPointPath device:(NSString*)devicePath
{
	NSLog(@"__FUNCTION__");
	int exit_status = 0;
	NSString *exit_imagePath = [[[NSString alloc] initWithString:imagePath] autorelease],
		*exit_mountPointPath = [[[NSString alloc] initWithString:mountPointPath] autorelease],
		*exit_devicePath = [[[NSString alloc] initWithString:devicePath] autorelease];
	
	if(!(mountPointPath = nil))
		exit_status = [[self unmountDeviceWithMountPoint:exit_mountPointPath] intValue];
	else
		exit_status = 1;
	if(!(devicePath = nil))
		exit_status = [[self ejectDevice:exit_devicePath] intValue];
	else 
		exit_status = 1;
	if(!(imagePath = nil) && !(mountPointPath = nil))
		exit_status = [self cleanupImage:exit_imagePath mountPoint:exit_mountPointPath];
	else 
		exit_status = 1;
	return exit_status;
}

// main function

-(int) makeImage:(NSString*)path fromFiles:(NSArray*)files{
	// Variables
	int error = 0, processID = [[NSProcessInfo processInfo] processIdentifier];
	unsigned long long totalImageSize = 0;

	NSString 
	*output = nil,
	*volName = [[path lastPathComponent] stringByDeletingPathExtension],
	*tmpDir = @"/tmp/", 
	*devFil = nil,
	*processIDString = [[NSNumber numberWithInt:processID] stringValue],
	*imageFile = [NSString stringWithString:path];
	
	mountPoint = [NSString stringWithString:[tmpDir stringByAppendingString:[processIDString stringByAppendingString:@".mntpt"]]];
	imageName = [tmpDir stringByAppendingString:[[@"tmpfil." stringByAppendingString:[[NSNumber numberWithInt:processID] stringValue]] stringByAppendingString:@".dmg"]];
	devPath = nil;
	
	NSNumber *imageSize;
	NSFileManager *manager = [NSFileManager defaultManager];
	
	if (error == 0){
		/////////
		// Create the disk image file
		/////////
		
		// verify that all of the source files exist before we bother creating an image....
		int i;
		for(i = 0; i<[files count]; i++)
			if(![manager fileExistsAtPath:[files objectAtIndex:i]]){
				NSLog(@"Error: No such file or directory: %@", [files objectAtIndex:i]);
				return 100;
			}
		
		if(verbose)
			NSLog(@"Calculating image size...");
		imageSize = [self imageSizeFromPaths:files];
		
		// check to see if the machine's available disk space is enough (we double the proposed image size to be safe)
		if([[[manager fileSystemAttributesAtPath:@"/"] objectForKey:@"NSFileSystemFreeSize"] unsignedLongLongValue] > ([imageSize unsignedLongLongValue] * 2))
		{ 
			// bloat 2% of image size for overhead, and 10MB for things with lots in their resource forks
			totalImageSize = [imageSize unsignedLongLongValue];
			totalImageSize = totalImageSize + ((totalImageSize * 0.02) + 10240);
			imageSize = [NSNumber numberWithLongLong:totalImageSize];
			
			if(verbose)
				NSLog(@"Creating image: %@", imageName);
			
			output = [self createImageOfSize:imageSize atPath:imageName];
			
			if([output intValue] != 0)
			{
				error = 1;
				[self cleanupImage:imageName mountPoint:mountPoint];
			}
		}
		else
		{
			error = 11;
			NSLog(@"Error: Not enough free space.");
		}
	}
	if (error == 0){
		/////////
		// get disk image device location
		/////////
		
		output = [self getDevPathFromFile:imageName];
		
		if(output == nil)
		{
			error = 2;
			[self cleanupImage:imageName mountPoint:mountPoint];
		}
		else{
			devPath = [NSString stringWithString:output];
			devFil = [devPath lastPathComponent];
		}
	}
	if (error == 0){
		/////
		// create filesystem in image
		/////
		if(verbose)
			NSLog(@"Creating filesystem: %@", volName);
		output = [self createFilesystem:@"HFS+" withLabel:volName atPath:devPath];
		
		if([output intValue] != 0)
		{
			error = 4;
			[self cleanupImage:imageName mountPoint:mountPoint];
		}
	}
	if (error == 0){
		/////
		// create mountpoint
		/////
		
		if(verbose)
			NSLog(@"Creating mount point: %@", mountPoint);
		output = [self createMountPointAtPath:mountPoint];
		
		if([output intValue] != 0)
		{
			error = 5;
			[self cleanupImage:imageName mountPoint:mountPoint];
		}
	}
	if (error == 0){
		//////
		// mount image
		//////
		if(verbose)
			NSLog(@"Mounting device: %@", devPath);
		output = [self mountDevice:devPath mountPoint:mountPoint];
		
		if([output intValue] != 0)
		{
			error = 6;
			[self exitOnErrorWithImage:imageName mountPoint:mountPoint device:devPath];
		}
	}	
	
	if (error == 0){
		
		// copy source files
		if(verbose)
			NSLog(@"Copying files to image...");
		output = [self copyFiles:files toPath:mountPoint];
		
		if([output intValue] != 0)
		{
			error = 7;
			NSLog(@"Image name:%@ Mount Point:%@ Device:%@",imageName, mountPoint, devPath);
			[self exitOnErrorWithImage:imageName mountPoint:mountPoint device:devPath];
		}
	}
	
	if (error == 0){
		// unmount image
		
		if(verbose)
			NSLog(@"Un-mounting device: %@ with mount point: %@", devPath, mountPoint);
		output = [self unmountDeviceWithMountPoint:mountPoint];
		
		if([output intValue] != 0)
		{
			error = 8;
			[self exitOnErrorWithImage:imageName mountPoint:mountPoint device:devPath];
		}
	}
	if (error == 0){
		/////
		// eject device
		/////
		
		if(verbose)
			NSLog(@"Ejecting device: %@", devFil);
		
		output = [self ejectDevice:devFil];
		
		if([output intValue] != 0)
		{
			error = 88;
			[self exitOnErrorWithImage:imageName mountPoint:mountPoint device:devPath];
		}
		
	}
	
	if (error == 0){
		/////
		// convert image if needed
		/////
		
		if (![imageName isEqualToString:imageFile]){
			if(verbose)
				NSLog(@"Converting image:%@", imageName);
			error = [[self convertImageAtPath:imageName moveToPath:imageFile] intValue];
		}
		error = [self cleanupImage:imageName mountPoint:mountPoint];
	}
	
	if ((error == 0) && internetEnabled && !([[self format] isEqual:@"UDSP"]) && !([[self format] isEqual:@"UDSB"]) && !([[self format] isEqual:@"UDTO"]) 
		&& !([[self format] isEqual:@"RdWr"]) && !([[self format] isEqual:@"Rdxx"]) && !([[self format] isEqual:@"ROCo"]) 
		&& !([[self format] isEqual:@"DC42"]))
	{
		// make internet enabled image
		NSLog(@"Making internet enabled...");
		
		if([self makeImageInternetEnabled:imageFile] != 0)
			error = 77;
	}
	
	
	if (error == 0){
		/////
		//cleanup
		/////
		
		error = [self cleanupImage:imageName mountPoint:mountPoint];
		if(verbose && (error == 0))
			NSLog(@"Imaging was successful");
	}	
	return error;
}

#pragma mark Other

-(BOOL) isTiger
{
	NSString *operatingSystemVersion = [[NSProcessInfo processInfo] operatingSystemVersionString], *temp = [NSString stringWithString:@""];
	NSScanner *versionScanner = [NSScanner scannerWithString:operatingSystemVersion];
	
	if([versionScanner scanUpToString:@"(" intoString:&temp]){
		versionScanner = [NSScanner scannerWithString:temp];
		if([versionScanner scanString:@"Version 10.4" intoString:&temp])
			return TRUE;
		else
			return FALSE;
	}
	else
		return FALSE;
}


// this function will open a program with the arguments specified
// this will not be useful with all programs on the command line 

-(NSString*)openProgram:(NSString*)programPath withArguments:(NSArray*) arguments
{
	int terminationStatus = 1;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; 
	
	// Allocate the task to execute and the pipe to send the output to
	NSTask  *theTask = [[NSTask alloc] init];
	NSPipe  *thePipe = [[NSPipe alloc] init];
	// Get the file handle from the pipe (assumes thePipe was allocated!)
	NSFileHandle *theFileHandle = [thePipe fileHandleForReading];
	NSString *theString;
	
	if (theTask && thePipe){
		// Tell the task what command (program) to execute
		[theTask setLaunchPath:programPath];
		
		// Pass some arguments to the program
		[theTask setArguments:arguments];
		
		// Set thePipe as the standard output so we can see the results
		[theTask setStandardOutput:thePipe];
		
		//if(verbose)
		//	NSLog(@" uting %@ with arguments: %@", programPath, [arguments description]);
		
		// Launch the task
		[theTask launch];
		
		// Wait until the task exits
		[theTask waitUntilExit];
		
		terminationStatus = [theTask terminationStatus];	
		
		// Verify that the program completed without error
		if (terminationStatus == 0) {
			
			theString = [[NSString alloc] initWithData:[theFileHandle readDataToEndOfFile] 
											  encoding:NSUTF8StringEncoding];
			if(theString == nil)
				theString = [[NSString alloc] initWithString:[[NSNumber numberWithInt:terminationStatus] stringValue]];
		} 

		// if an error occured, return the error code.
		else
			theString = [[NSString alloc] initWithString:[[NSNumber numberWithInt:terminationStatus] stringValue]];
		
	}
	else {
		// If there was an errthePipeor, tell the user
		terminationStatus = -1;
		theString = [[NSString alloc] initWithString:[[NSNumber numberWithInt:terminationStatus] stringValue]];
		NSLog(@"An error occurred trying to allocate the task or pipe.");
	}
	
	if (thePipe) { [thePipe release]; thePipe = nil; }
	if (theTask) { [theTask release]; theTask = nil; }
	
	[pool release];
	
	return [theString autorelease];
}

-(int) evaluateInput:(const char **)argv count:(int)argc
{
	// set defaults and initialize variables
	NSMutableArray *sourceFiles = [NSMutableArray arrayWithCapacity:1];
	NSString *destinationPath = nil;
	int error = 0;
	verbose = FALSE;
	internetEnabled = FALSE;
	encryption = FALSE;
	overwrite = FALSE;
	format = [NSString stringWithString:@"UDZO"];
	encryptionType = @"";
	compressionLevel = 1;
	int opt, index;

	if (argc < 1){
		error = -1;
		[self help];
	}
	else{
		while ((opt = getopt(argc, argv, "Vhvoec:z:f:i:")) != -1) {
			switch (opt) {
				case 'V':
					printf("mkdmg version "__version__);
					return 0;
				case 'h':
					[self help];
					return 0;
				case 'v':
					verbose = TRUE;
					break;
				case 'o':
					overwrite = TRUE;
					break;
				case 'e':
					internetEnabled = TRUE;
					break;
				case 'c':
					encryption = TRUE;
					[self setEncryptionType:[NSString stringWithUTF8String:optarg]];
					break;
				case 'f':
					[self setFormat:[NSString stringWithUTF8String:optarg]];
					break;
				case 'z':
					if(optarg == nil)
						NSLog(@"Error: option -z requires an argument");
					else{
						if(0 < atoi(optarg) < 10)
							[self setCompressionLevel:atoi(optarg)];
						else
							[self setCompressionLevel:2];
					}
					break;
				case 'i':
					// if the path extension is ".app", ".nib", ".pkg", or ".mpkg", remove the extension before imaging 
					// (the Finder won't display the contents of volumes with these extensions).
					if([[[NSString stringWithUTF8String:optarg] pathExtension] isEqual:@"app"] || [[[NSString stringWithUTF8String:optarg] pathExtension] isEqual:@"nib"] || [[[NSString stringWithUTF8String:optarg] pathExtension] isEqual:@"pkg"] || [[[NSString stringWithUTF8String:optarg] pathExtension] isEqual:@"mpkg"])
						destinationPath = [[[NSString stringWithUTF8String:optarg] stringByDeletingPathExtension] stringByAppendingPathExtension:[self pathExtension]];
					else
						destinationPath = [NSString stringWithUTF8String:optarg];
					
					// if the path extension of the input matches the extension for the current image,
					if(![[destinationPath pathExtension] isEqual:[self pathExtension]])
						// attach the correct extension
						destinationPath = [destinationPath stringByAppendingPathExtension:[self pathExtension]];
					
					// if the file exists...
					if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath]){
						// ...and the user has chosen not to overwrite, report error
						if(!overwrite){
							NSLog(@"Error: File: %@ exists.", destinationPath);
							error = -3;
						}
						else{
							// if the user has chosen, and the file is deletable...
							if([[NSFileManager defaultManager] isDeletableFileAtPath:destinationPath]){
								// replace the file.
								if(![[NSFileManager defaultManager] removeFileAtPath:destinationPath handler:nil])
									error = -4;
							}
							else{
								error = -4;
								
							}
						}
					}
					// if the file does not exist, check that the future image location is writeable
					else if(![self isWriteableDirectoryAtPath:[destinationPath stringByDeletingLastPathComponent]]){
						NSLog(@"Error: %@ is read-only.", [destinationPath stringByDeletingLastPathComponent]);
						error = -4;
					}
					break;
				default: /* '?' */
					[self help];
					error = -2;
					break;
			}
		}
		if (optind >= argc){
			NSLog(@"Error: no source files specified");
			[self help];
			error = -1;
		}
		else
			for(index = optind; index < argc; index++)
				[sourceFiles addObject:[NSString stringWithUTF8String:argv[index]]];
	}
	
	if (error == 0)
	{
		NSLog(destinationPath);
		if(destinationPath == nil){
			NSLog(@"Error: destination image path is required");
			[self help];
			error = -20;
			return error;
		}
		else
			// create the image
			return [self makeImage:destinationPath fromFiles:sourceFiles];
	}
	else
		return error;
}

@end

