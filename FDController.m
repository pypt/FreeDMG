/*
	File: FDController.m
 
	Written by: eK
 
	Implementation of FDController class
	
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

#import "FDController.h"

@implementation FDController

-(id) init
{
	self = [super init];
	
	progressStrings = [[NSArray alloc] initWithObjects:
		@"Calculating image size...",
		@"Creating image:",
		@"Device path",
		@"Creating filesystem:",
		@"Creating mount point:",
		@"Mounting device:",
		@"Copying files to image...",
		@"Un-mounting device:",
		@"Ejecting device:",
		@"Converting image:",
		@"Imaging was successful",
		@"Preparing imaging engine...",
		@"Reading Apple_HFS",
		@"Terminating imaging engine...",
		@"Adding resources...",
		@"Initializing...",
		@"Imaging...",
		@"Verifying...",
		@"Checksumming",
		@"Verification completed...",
		@"Attaching...",
		@"Finishing...",
		@"created:",
		nil];
	
	// supported SLA languages
	languages = [[NSArray alloc] initWithObjects:
		@"German",
		@"English",
		@"Spanish",
		@"French",
		@"Italian",
		@"Japanese",
		@"Dutch",
		@"Swedish",
		@"Brazilian Portugese",
		@"Simplified Chinese",
		@"Traditional Chinese",
		@"Danish",
		@"Finnish",
		@"French Canadian",
		@"Korean",
		@"Norwegian",
		nil];
	
	return self;
}

-(void) dealloc
{
	[progressStrings release];
	[languages release];
	[volumes release];
	[devices release];
	
	[super dealloc];
}

-(void)awakeFromNib{
	
	// Make sure both mkdmg and hdiutil exist, otherwise, exit
	if(![[NSBundle mainBundle] pathForResource:@"mkdmg" ofType:nil]){
		NSRunAlertPanel(@"FreeDMG", NSLocalizedString(@"mkdmg_Warning", @"mkdmg not found. Re-install FreeDMG."), NSLocalizedString(@"OK", @"OK"), @"", @"");
		[NSApp terminate:self];
	}
	else if(![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/hdiutil"]){
		NSRunAlertPanel(@"FreeDMG", NSLocalizedString(@"hdiutil_Warning", @"hdiutil not found. Re-install Mac OS X."), NSLocalizedString(@"OK", @"OK"), @"", @"");
		[NSApp terminate:self];
		
	}
	
	// set verbose, and factory defaults before trying to read preferences (in case a preference is not set).
	freeDMGRunning = NO;
	verbose = YES;
	internetEnabled = NO;
	compression = [NSString stringWithString:@"UDZO"];
	compressionLevel = [NSNumber numberWithInt:9];
	convertFormat = [NSString stringWithString:@"UDZO"];
	prompt = YES;
	encryption = NO;
	overwrite = NO;
	quit = YES;
	doQuit = NO;
	hasQuit = YES;
	volumeFormat = @"HFS+";
	imageDropAction = [NSNumber numberWithInt:0];
	limitSegmentSize = FALSE;
	limitSegmentSizeByte = @"MB";
	segmentSize = [NSNumber numberWithDouble:1];
	burnRunning = FALSE;
	gotMedia = FALSE;
	
	FDToolbarNewItemIdentifier = @"FDNewImage";
	FDToolbarConvertItemIdentifier = @"FDConvertImage";
	FDToolbarResizeItemIdentifier = @"FDResizeImage";
	FDToolbarVerifyItemIdentifier = @"FDVerifyImage";
	FDToolbarMountItemIdentifier = @"FDMountImage";
	FDToolbarInspectItemIdentifier = @"FDInspectImage";
	FDToolbarEjectItemIdentifier = @"FDEjectImage";
	FDToolbarLogItemIdentifier = @"FDShowHideLog";
	FDToolbarInternetItemIdentifier = @"FDInternetImage";
	FDToolbarBurnItemIdentifier = @"FDBurnImage";
	FDToolbarSLAItemIdentifier = @"FDSLAImage";
	
	// create instance of standard user defaults
	defaults = [NSUserDefaults standardUserDefaults];
	
	// update preferences panel
	[self updatePreferencesPanel];
	
	[volumesMenu setDelegate:self];
	[volumesMenu setAutoenablesItems:TRUE];
	[volumesMenu setTitle:NSLocalizedString(@"Create_Volume", @"Create from Volume")];
	[volumesMenuItem setSubmenu:volumesMenu];

	// setup toolbar
	mainToolbar = [[[NSToolbar alloc] initWithIdentifier:@"FreeDMGToolbar"] autorelease];
	[mainToolbar setDelegate:self];
	[FreeDMGWindow setToolbar:mainToolbar];
	[mainToolbar setConfigurationFromDictionary:[defaults objectForKey:@"NSToolbar Configuration FreeDMGToolbar"]];
	[mainToolbar setAutosavesConfiguration:TRUE];
	[mainToolbar setAllowsUserCustomization:TRUE];
	
	// create folder to store SLA in during license attachment process
	system([[@"mkdir -p " stringByAppendingString:[NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/FreeDMG/SLAs"]] UTF8String]);
	[SLATextView setRichText:TRUE];
	
	volumes = [[NSArray alloc] initWithArray:[self volumes]];
	// disabled devices menu due to crashing in 10.6
	//devices = [[NSArray alloc] initWithArray:[self devices]];
		
}

// callback happens before the application finished launching.
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	if(quit){
		doQuit = YES;
		hasQuit = NO;
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{	
	if(!hasQuit)
		doQuit = NO;	
}

// callback by other applications (Finder) telling us to openFiles:file
- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{

	if(quit && doQuit){

		hasQuit = YES;
	}	else{

		hasQuit = NO;
		doQuit = NO;
	}
	
	if(![freeDMGTask isRunning]){
		return [self createImageWithFiles:[NSArray arrayWithObjects:filename, nil]];
	}else
		return FALSE;
}

// callback by other applications (Finder) telling us to openFiles:files
- (BOOL)application:(NSApplication *)sender openFiles:(NSArray *)files
{	
	if(quit && doQuit)
		hasQuit = YES;
	else{
		hasQuit = NO;
		doQuit = NO;
	}
	
	if(![freeDMGTask isRunning])
		return [self createImageWithFiles:files];
	else
		return FALSE;
}

// If the user attempts to close the window, 
-(BOOL)windowShouldClose:(id)sender
{
	// quit when idle
	if(![freeDMGTask isRunning]){
		[NSApp terminate:self];
		return YES;
	}
	else
	{
		int choice = NSAlertDefaultReturn;
		
		NSString *title = [NSString stringWithString:NSLocalizedString(@"Quit_Confirmation", @"FreeDMG is currently imaging. Are you sure that you want to quit?")];
		choice = NSRunAlertPanel(title,	NSLocalizedString(@"Quit_Warning", @"Quitting now can result in an incomplete image"),NSLocalizedString(@"Cancel", @"Cancel"), NSLocalizedString(@"Quit", @"Quit"), @"");
        if (choice == NSAlertDefaultReturn) { 
			/* Cancel termination */
            return NO;
        }
		else
		{
			[freeDMGTask stopProcess];
			[NSApp terminate:self];
			return YES;
		}
	}
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app {
	// Determine if task is running...
    if ([freeDMGTask isRunning]) {
        int choice = NSAlertDefaultReturn;
		
		NSString *title = [NSString stringWithString:NSLocalizedString(@"Quit_Confirmation", @"FreeDMG is currently imaging. Are you sure that you want to quit?")];
		choice = NSRunAlertPanel(title,	NSLocalizedString(@"Quit_Warning", @"Quitting now can result in an incomplete image"),NSLocalizedString(@"Cancel", @"Cancel"), NSLocalizedString(@"Quit", @"Quit"), @"");
        if (choice == NSAlertDefaultReturn) { 
			/* Cancel termination */
            return NSTerminateCancel;
        }
		else
		{
			[freeDMGTask stopProcess];
		}
    }
    return NSTerminateNow;
}

// delegate method for save panels (verifies name in regards to 
//- (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag
//{
//	return filename;
//}
	
#pragma mark Accessors

- (id) objectForKey:(NSString *)key
{
	if([defaults objectForKey:key] != nil)
		return [defaults objectForKey:key];
	else
	{
		return nil;
	}
}

- (void) setValue:(id)newValue forKey:(NSString *)key
{
	NSLog(@"Setting value:%@ for key:%@", newValue, key);
	if([defaults objectForKey:key] != nil){
		NSMutableDictionary *tempDict = [NSMutableDictionary dictionaryWithCapacity:1];
		[tempDict addEntriesFromDictionary:[defaults objectForKey:@"hybridTypes"]];
		[tempDict setObject:newValue forKey:key];
		[defaults setObject:tempDict forKey:@"hybridTypes"];
		[defaults synchronize];
		
		NSLog(@"Finished setting value:%@ for key:%@", [defaults objectForKey:key], key);
	}
}

- (NSMutableArray *) hybridTypes
{
	if([defaults objectForKey:@"hybridTypes"] != nil)
		return [defaults objectForKey:@"hybridTypes"];
	else
	{
		return [NSMutableArray arrayWithCapacity:1];
	}
}

- (void) setHybridTypes:(NSMutableArray *)hybridTypes
{
	[defaults setObject:hybridTypes forKey:@"hybridTypes"];
}

// return the useable (as determined by diskutil -list) device attached (eg. /dev/disk0, /dev/disk1, etc.)
-(NSArray *) devices
{
	// diskutil is pretty slow, but offers structured (plist) output
//	NSDictionary *deviceDict = [[NSDictionary alloc] initWithDictionary:[[self openProgram:@"/usr/sbin/diskutil" withArguments:[NSArray arrayWithObjects:@"list", @"-plist", nil]] propertyList]];
//	NSLog([[deviceDict objectForKey:@"AllDisks"] description]);
//	return [[deviceDict objectForKey:@"AllDisks"] autorelease];
	
	// Note: disktool is faster, but doesn't offer xml output 
	// Apple does not recommend using disktool in the man page?
	//NSMutableString *deviceString = [[NSMutableString alloc] initWithString:[self openProgram:@"/usr/sbin/disktool" withArguments:[NSArray arrayWithObjects:@"-l", nil]]];
//	[deviceString replaceOccurrencesOfString:@"***Disk Appeared ('" withString:@"" options:nil range:NSMakeRange(0, [deviceString length])];
//	[deviceString replaceCharactersInRange:	NSUnionRange([deviceString rangeOfString:@"',Mountpoint = '"], [deviceString rangeOfString:@"')\n"]) withString:@"\n"];
//
//	return [deviceString componentsSeparatedByString:@"\n"];
	
	// Note: disktool is faster, but doesn't offer xml output 
	// Apple does not recommend using disktool in the man page?
	// To get acceptable speed, we're using disktool (sorry Apple)
	// This allows for imaging on launch (which doesn't happen with sluggish diskutil)
	NSMutableString *deviceString = [[NSMutableString alloc] initWithString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict><key>devices</key><array>\n"];
	[deviceString appendString:[self openProgram:@"/usr/sbin/disktool" withArguments:[NSArray arrayWithObjects:@"-l", nil]]];
	NSRange devStringRange = NSMakeRange(0, [deviceString length]);

	[deviceString replaceOccurrencesOfString:@"***Disk Appeared ('" withString:@"<dict>\n<key>disk</key>\n<string>" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"',Mountpoint = '" withString:@"</string>\n<key>mountpoint</key>\n<string>" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"', fsType = '" withString:@"</string>\n<key>fstype</key>\n<string>" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"', volName = '" withString:@"</string>\n<key>volname</key>\n<string>" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"')" withString:@"</string>\n</dict>\n" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"\n\n" withString:@"" options:nil range:devStringRange];
	[deviceString appendString:@"</array></dict></plist>"];
	
	//NSLog(deviceString);
	NSDictionary *deviceDict = [[NSMutableDictionary alloc] initWithDictionary:[deviceString propertyList]];
	
	//NSLog([deviceDict description]);
	NSMutableArray *deviceArray = [[NSMutableArray alloc] initWithCapacity:1];
	
	int i;
	for(i = 0;i < [[deviceDict objectForKey:@"devices"] count]; ++i){
		if(![[[[deviceDict objectForKey:@"devices"] objectAtIndex:i] objectForKey:@"fstype"] isEqual:@"afpfs"])
			[deviceArray addObject:[[[deviceDict objectForKey:@"devices"] objectAtIndex:i] objectForKey:@"disk"]];
	}
	//NSLog([devices description]);
	[deviceDict release];
	[deviceString release];
	
	return [deviceArray autorelease];
	
}

-(NSDictionary *) deviceDict
{
	// diskutil is pretty slow, but offers structured (plist) output
	//	NSDictionary *deviceDict = [[NSDictionary alloc] initWithDictionary:[[self openProgram:@"/usr/sbin/diskutil" withArguments:[NSArray arrayWithObjects:@"list", @"-plist", nil]] propertyList]];
	//	NSLog([[deviceDict objectForKey:@"AllDisks"] description]);
	//	return [[deviceDict objectForKey:@"AllDisks"] autorelease];
	
	// Note: disktool is faster, but doesn't offer xml output 
	// Apple does not recommend using disktool in the man page?
	//NSMutableString *deviceString = [[NSMutableString alloc] initWithString:[self openProgram:@"/usr/sbin/disktool" withArguments:[NSArray arrayWithObjects:@"-l", nil]]];
	//	[deviceString replaceOccurrencesOfString:@"***Disk Appeared ('" withString:@"" options:nil range:NSMakeRange(0, [deviceString length])];
	//	[deviceString replaceCharactersInRange:	NSUnionRange([deviceString rangeOfString:@"',Mountpoint = '"], [deviceString rangeOfString:@"')\n"]) withString:@"\n"];
	//
	//	return [deviceString componentsSeparatedByString:@"\n"];
	
	// Note: disktool is faster, but doesn't offer xml output 
	// Apple does not recommend using disktool in the man page?
	// To get acceptable speed, we're using disktool (sorry Apple)
	// This allows for imaging on launch (which doesn't happen with sluggish diskutil)
	NSMutableString *deviceString = [[NSMutableString alloc] initWithString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict><key>devices</key><array>\n"];
	[deviceString appendString:[self openProgram:@"/usr/sbin/disktool" withArguments:[NSArray arrayWithObjects:@"-l", nil]]];
	NSRange devStringRange = NSMakeRange(0, [deviceString length]);
	
	[deviceString replaceOccurrencesOfString:@"***Disk Appeared ('" withString:@"<dict>\n<key>disk</key>\n<string>" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"',Mountpoint = '" withString:@"</string>\n<key>mountpoint</key>\n<string>" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"', fsType = '" withString:@"</string>\n<key>fstype</key>\n<string>" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"', volName = '" withString:@"</string>\n<key>volname</key>\n<string>" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"')" withString:@"</string>\n</dict>\n" options:nil range:devStringRange];
	[deviceString replaceOccurrencesOfString:@"\n\n" withString:@"" options:nil range:devStringRange];
	[deviceString appendString:@"</array></dict></plist>"];
	
	//NSLog(deviceString);
	NSDictionary *deviceDict = [[NSMutableDictionary alloc] initWithDictionary:[deviceString propertyList]];
	
	//NSLog([deviceDict description]);
	//NSMutableArray *deviceArray = [[NSMutableArray alloc] initWithCapacity:1];
//	
//	int i;
//	for(i = 0;i < [[deviceDict objectForKey:@"devices"] count]; ++i){
//		if(![[[[deviceDict objectForKey:@"devices"] objectAtIndex:i] objectForKey:@"fstype"] isEqual:@"afpfs"])
//			[deviceArray addObject:[[[deviceDict objectForKey:@"devices"] objectAtIndex:i] objectForKey:@"disk"]];
//	}
//	//NSLog([devices description]);
//	[deviceDict release];
//	[deviceString release];
	
	return [deviceDict autorelease];
	
}


- (NSArray *) volumes
{	
	// Clean, but slow
//	NSDictionary *deviceDict = [[NSDictionary alloc] initWithDictionary:[[self openProgram:@"/usr/sbin/diskutil" withArguments:[NSArray arrayWithObjects:@"list", @"-plist", nil]] propertyList]];
//	NSLog([[deviceDict objectForKey:@"VolumesFromDisks"] description]);
//	return [[deviceDict objectForKey:@"VolumesFromDisks"] autorelease];
	
	// Alternately, just get the list of files (excluding .DS_Store)
	// at the default /Volumes directory from FileManager
	NSMutableArray *volumesArray = [NSMutableArray arrayWithCapacity:1];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// get a list of items in the /Volumes directory
	[volumesArray addObjectsFromArray:[fileManager directoryContentsAtPath:@"/Volumes"]];
	
	// remove .DS_Store from list of options
	if([volumesArray containsObject:@".DS_Store"])
		[volumesArray removeObject:@".DS_Store"];
	return volumesArray;
}

- (NSString *) compression
{
	if([defaults objectForKey:@"compression"] != nil)
		compression = [NSString stringWithString:[defaults objectForKey:@"compression"]];
	else{
		compression = @"UDZO";
		[defaults setObject:compression forKey:@"compression"];
	}
	
	return compression;
}

- (void) setCompression:(NSString*)newCompression
{
	compression = [NSString stringWithString:newCompression];
	[defaults setObject:compression forKey:@"compression"];
}

- (NSNumber *) compressionLevel
{
	return [defaults objectForKey:@"compressionLevel"];
}

- (void) setCompressionLevel:(NSNumber*)newCompressionLevel
{
	compressionLevel = newCompressionLevel;
	[defaults setObject:compressionLevel forKey:@"compressionLevel"];
}

- (NSString *) convertFormat
{
	if([defaults objectForKey:@"convertFormat"] != nil){
		convertFormat = [NSString stringWithString:[defaults objectForKey:@"convertFormat"]];
	}
	else{
		convertFormat = @"UDZO";
		[defaults setObject:convertFormat forKey:@"convertFormat"];
	}
	
	return convertFormat;
}

- (void) setConvertFormat:(NSString*)newFormat
{
	convertFormat = [NSString stringWithString:newFormat];
	[defaults setObject:convertFormat forKey:@"convertFormat"];
	[sPanel setRequiredFileType:[self convertFormat]];
}

- (NSString *) encryptionType
{
	return [defaults objectForKey:@"encryptionType"];
}

- (void) setEncryptionType:(NSString*)newType
{
	encryptionType = [NSString stringWithString:newType];
	[defaults setObject:newType forKey:@"encryptionType"];
}

- (NSString *) pathExtension
{
	NSString * pathExtension, *compressionFormat = [NSString stringWithString:[self compression]];
	
	if(([compressionFormat isEqualToString:@"UDRW"] == TRUE) || 
	   ([compressionFormat isEqualToString:@"UDRO"] == TRUE) || 
	   ([compressionFormat isEqualToString:@"UDCO"] == TRUE) || 
	   ([compressionFormat isEqualToString:@"UDZO"] == TRUE) || 
	   ([compressionFormat isEqualToString:@"UFBI"] == TRUE) || 
	   ([compressionFormat isEqualToString:@"UDxx"] == TRUE))
	{
		pathExtension = [NSString stringWithString:@"dmg"];
	}
	else if([compressionFormat isEqualToString:@"UDTO"] == TRUE)
	{
		pathExtension = [NSString stringWithString:@"cdr"];
	}
	else if([compressionFormat isEqualToString:@"UDSP"] == TRUE)
	{
		pathExtension = [NSString stringWithString:@"sparseimage"];
	}	
	else if([compressionFormat isEqualToString:@"UDSB"] == TRUE)
	{
		pathExtension = [NSString stringWithString:@"sparsebundle"];
	}
	else if(([compressionFormat isEqualToString:@"RdWr"]  == TRUE) ||
			([compressionFormat isEqualToString:@"Rdxx"]  == TRUE) ||
			([compressionFormat isEqualToString:@"ROCo"]  == TRUE) ||
			([compressionFormat isEqualToString:@"DC42"] == TRUE)){
		pathExtension = [NSString stringWithString:@"img"];
	}
	else
		pathExtension = [NSString stringWithString:@"dmg"];
	
	return pathExtension; 
}

- (NSString *) convertPathExtension
{
	NSString * pathExtension, *fmt = [NSString stringWithString:[self convertFormat]];
	
	if(([fmt isEqualToString:@"UDRW"] == TRUE) || 
	   ([fmt isEqualToString:@"UDRO"] == TRUE) || 
	   ([fmt isEqualToString:@"UDCO"] == TRUE) || 
	   ([fmt isEqualToString:@"UDZO"] == TRUE) || 
	   ([fmt isEqualToString:@"UFBI"] == TRUE) || 
	   ([fmt isEqualToString:@"UDxx"] == TRUE))
	{
		pathExtension = [NSString stringWithString:@"dmg"];
	}
	else if([convertFormat isEqualToString:@"UDTO"] == TRUE)
	{
		pathExtension = [NSString stringWithString:@"cdr"];
	}
	else if([fmt isEqualToString:@"UDSP"] == TRUE)
	{
		pathExtension = [NSString stringWithString:@"sparseimage"];
	}	
	else if([fmt isEqualToString:@"UDSB"] == TRUE)
	{
		pathExtension = [NSString stringWithString:@"sparsebundle"];
	}
	else if(([fmt isEqualToString:@"RdWr"]  == TRUE) ||
			([fmt isEqualToString:@"Rdxx"]  == TRUE) ||
			([fmt isEqualToString:@"ROCo"]  == TRUE) ||
			([fmt isEqualToString:@"DC42"] == TRUE)){
		pathExtension = [NSString stringWithString:@"img"];
	}
	else
		pathExtension = [NSString stringWithString:@"dmg"];
	
	return pathExtension; 
}

#pragma mark Delegate Methods

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
	
    return [NSArray arrayWithObjects:
		
		// FreeDMG toolbar items
		FDToolbarLogItemIdentifier,
		FDToolbarNewItemIdentifier,
		FDToolbarConvertItemIdentifier,
		FDToolbarResizeItemIdentifier,
		FDToolbarInternetItemIdentifier,
		FDToolbarVerifyItemIdentifier,
		FDToolbarInspectItemIdentifier,		
		FDToolbarMountItemIdentifier,
		FDToolbarBurnItemIdentifier,
		FDToolbarSLAItemIdentifier,
		
		// Apple provided toolbar items
		//NSToolbarPrintItemIdentifier,
		//        NSToolbarShowColorsItemIdentifier,
		//        NSToolbarShowFontsItemIdentifier,
        NSToolbarCustomizeToolbarItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
        NSToolbarSpaceItemIdentifier,
        NSToolbarSeparatorItemIdentifier, nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
	
    return [NSArray arrayWithObjects:
		FDToolbarNewItemIdentifier,
		FDToolbarConvertItemIdentifier,
		FDToolbarInternetItemIdentifier,
		FDToolbarVerifyItemIdentifier, 
		NSToolbarSeparatorItemIdentifier,
		FDToolbarLogItemIdentifier, nil];
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdentifier
  willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier] autorelease];
	
    if ([itemIdentifier isEqual: FDToolbarNewItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_New", @"New Image")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_New", @"New Image")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_New_Tip", @"Create a disk image")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_new.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(createBlankImage:)];
    } 	
	else if ([itemIdentifier isEqual: FDToolbarVerifyItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_Verify", @"Verify Image")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_Verify", @"Verify Image")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_Verify_Tip", @"Verify a disk image")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_verify.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(verifyImage:)];
    }  	
	else if ([itemIdentifier isEqual: FDToolbarResizeItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_Resize", @"Resize")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_Resize", @"Resize Image")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_Resize_Tip", @"Resize a disk image")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_resize.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(resizeImage:)];
    } 
	else if ([itemIdentifier isEqual: FDToolbarInternetItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_Internet_Enable", @"Internet Enable Image")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_Internet_Enable", @"Internet Enable Image")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_Internet_Enable_Tip", @"Internet Enable a disk image")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_internet.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(makeInternetEnabled:)];
    } 
	
	else if ([itemIdentifier isEqual: FDToolbarConvertItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_Convert", @"Convert Image")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_Convert", @"Convert Image")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_Convert_Tip", @"Convert a disk image")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_convert.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(convertImage:)];
    } 
	else if ([itemIdentifier isEqual: FDToolbarMountItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_Mount", @"Mount Image")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_Mount", @"Mount Image")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_Mount_Tip", @"Mount a disk image")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_mount.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(mount:)];
    } 
	else if ([itemIdentifier isEqual: FDToolbarInspectItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_Get_Info", @"Get Info")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_Get_Info", @"Get Info")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_Get_Info_Tip", @"Get Info")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_info.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(getInfo:)];
    } 
	else if ([itemIdentifier isEqual: FDToolbarEjectItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_Eject", @"Eject Image")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_Eject", @"Eject Image")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_Eject_Tip", @"Eject a disk image")];
		[toolbarItem setImage:[NSImage imageNamed:@"Eject.tiff"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(ejectImage:)];
    } 		
	else if ([itemIdentifier isEqual: FDToolbarLogItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_Log", @"Show/Hide Log")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_Log", @"Show/Hide Log")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_Log_Tip", @"Show/Hide Log Drawer")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_log.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(showHideLogAction:)];
    } 	
	else if ([itemIdentifier isEqual: FDToolbarBurnItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_Burn", @"Burn Image")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_Burn", @"Burn Image")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_Burn_Tip", @"Burn a disk image")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_burn.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(burnImage:)];
    }	
	else if ([itemIdentifier isEqual: FDToolbarSLAItemIdentifier]) {
		// Set the text label to be displayed in the 
		// toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Toolbar_SLA", @"Add SLA")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Toolbar_SLA", @"Add SLA")];
		
		// Set up a reasonable tooltip, and image
		// you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip:NSLocalizedString(@"Toolbar_SLA_Tip", @"Add Software License Agreement to Image")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar_sla.png"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(addSLAToImage:)];
    }	
	else 
		
	{
		// itemIdentifier referred to a toolbar item that is not
		// provided or supported by us or Cocoa 
		// Returning nil will inform the toolbar
		// that this kind of item is not supported 
		toolbarItem = nil;
    }
    return toolbarItem;
}

- (void) toggleToolbarShown:(id)sender
{
	if([[sender title] isEqualToString:@"Hide Toolbar"])
		[mainToolbar setVisible:FALSE];
	else
		[mainToolbar setVisible:TRUE];
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
	NSLog(@"Text did end editing: %@", [aNotification description]);
	
	if([[aNotification object] isEqual:SLATextView])
	{
		[self saveSLAStringValue];
	}
	else if([[aNotification object] isEqual: resizeProjectedTextField])
	{
		[resizeSlider setDoubleValue:[resizeProjectedTextField doubleValue]];
	}
}

#pragma mark Methods

// Logging to our log pane
- (void)FDLog:(NSString*)logOutput 
{
	[[logTextView textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:[logOutput stringByAppendingString:@"\n"]] autorelease]];
}

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


// create new image, specifying size, filesystem, and volumename 
-(int) createImage:(NSString*)imagePath ofSize:(NSNumber*)imageSizeInMB withFilesystem:(NSString*)imageFilesystem volumeName:(NSString*)imageVolumeName type:(NSString*)imageType
{
	int status = 0;
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:1];
	
	[arguments addObject:@"create"];
	
	// specify image size
	[arguments addObject:@"-megabytes"];
	if(![[imageSizeInMB stringValue] isEqualToString:@"0"])
		[arguments addObject:[imageSizeInMB stringValue]];
	else
		[arguments addObject:[[NSNumber numberWithInt:40] stringValue]];
	
	// if the imageVolumeName is specified, use that
	if(imageVolumeName != nil){
		[arguments addObject:@"-volname"];
		[arguments addObject:imageVolumeName];
	}
	
	// if the imageFilesystem is not specified, make HFS+ the default
	[arguments addObject:@"-fs"];
	
	if(imageFilesystem != nil){
		[arguments addObject:imageFilesystem];
	}
	else{
		[arguments addObject:@"HFS+"];
	}
	
	// specify image type
	
	if(imageType != nil)
	{
		[arguments addObject:@"-type"];
		[arguments addObject:imageType];
	}
	
	// add optional encryption options to arguments
	if(encryption){
		[arguments addObject:@"-encryption"];
		if(![[self encryptionType] isEqual:@""])
		{
			[arguments addObject:[self encryptionType]];
		}
	}
	
	// check if the user has chosen to overwrite
	if(overwrite){
		[arguments addObject:@"-ov"];
	}
	
	//  verbose
	if(verbose)
		[arguments addObject:@"-verbose"];
	
	[arguments addObject:@"-puppetstrings"];
		
	// specify the image path
	[arguments addObject:imagePath];
	
	// launch the task
	status = [self openTask:@"/usr/bin/hdiutil" withArguments:arguments];
	
	return status;
}

// create disk image from files
-(int) createImageWithFiles:(NSArray*)files
{
	int status = 0;
	BOOL isDir = FALSE;
	NSString *path = nil, *imagePath = nil, *filePath = nil;
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:1];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Check to make sure our tool is still hanging out in our package
	if(![[NSBundle mainBundle] pathForResource:@"mkdmg" ofType:nil])
	{
		NSRunAlertPanel(@"FreeDMG", NSLocalizedString(@"mkdmg_Warning", @"mkdmg tool not found.  Re-install FreeDMG."), NSLocalizedString(@"OK", @"OK"), @"", @"");
		status = -1;
	}
	else
		path = [NSString stringWithString:[[NSBundle mainBundle] pathForResource:@"mkdmg" ofType:nil]];
	
	// if the mkdmg tool is present, proceed
	if (status == 0)
	{
		// set image file path
		filePath = [NSString stringWithString:[files objectAtIndex:0]];
				
			
		// if the user has chosen to skip prompt, and has dropped one file or folder,
		// set the source (filePath), and destination (imagePath) based on source name
		if(prompt && ![[filePath stringByDeletingLastPathComponent] isEqual:@"/Volumes"] && ([files count] == 1))
		{
			imagePath = [[[files objectAtIndex:0] 
				stringByDeletingLastPathComponent]
					stringByAppendingPathComponent:[[files objectAtIndex:0] lastPathComponent]];
		}
		else if(([[[filePath lastPathComponent] pathExtension] isEqualToString: @"dmg"] || 
				 [[[filePath lastPathComponent] pathExtension] isEqualToString: @"img"] || 
				 [[[filePath lastPathComponent] pathExtension] isEqualToString: @"cdr"] ||
				 [[[filePath lastPathComponent] pathExtension] isEqualToString: @"sparseimage"] ||
				 [[[filePath lastPathComponent] pathExtension] isEqualToString: @"sparsebundle"]) &&
				[files count] == 1)
		{
			// if the file is a disk image, we don't want to query for save destination
		}
		// otherwise, query the user for save destination.
		else
		{
			sPanel = [NSSavePanel savePanel];
			[sPanel setAccessoryView:ConvertView];
			
			if ([sPanel runModalForDirectory:nil file:[[filePath lastPathComponent] stringByAppendingPathExtension:[self pathExtension]]] == NSOKButton) {
				
				imagePath = [NSString stringWithString:[sPanel filename]];
			}
			else{
				status = 1;
				[statusTextField setStringValue:@"Idle"];
				[imageProgress stopAnimation:self];
			}
		}	
		
		// Check to see if the source is a single file/folder
		if(([files count] == 1) && (status == 0))
		{
			// if a disk image is dropped - mount it
			if ([[[filePath lastPathComponent] pathExtension] isEqualToString: @"dmg"] ||
				[[[filePath lastPathComponent] pathExtension] isEqualToString: @"img"] || 
				[[[filePath lastPathComponent] pathExtension] isEqualToString: @"sparseimage"] ||
				[[[filePath lastPathComponent] pathExtension] isEqualToString: @"sparsebundle"] ||
				[[[filePath lastPathComponent] pathExtension] isEqualToString: @"cdr"] ||
				[[[filePath lastPathComponent] pathExtension] isEqualToString: @"iso"])
			{
				switch([[imageDropMatrix selectedCell] tag]){
					case 1:
						status = [self burnImageAtPath:filePath];
						break;
					case 2:
						status = [self convertImage:filePath format:[self compression] outfile:[filePath stringByAppendingPathExtension:[self pathExtension]]];
						break;
					case 3:
						status = [self segmentImageAtPath:filePath segmentName:[filePath lastPathComponent] segmentSize:[segmentSizeButton title]];
						break;
					case 4:
						status = [self imageInfoAtPath:filePath];
						break;
					case 5:
						status = [self verifyImageAtPath:imagePath];
						break;
					case 6:
						status = [self checksumImageAtPath:imagePath type:@"CRC32"];
						break;
					case 7:
						status = [self scanImageForRestore:imagePath blockOnly:FALSE];
						break;
					default:
						status = [self mountImage:filePath];
						break;
				}
			}
			
			// if a single folder or Volume is dropped - image it
			else if([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && isDir && (status == 0))
			{
				// one folder was dropped - image it
				status = [self createImage:imagePath fromFolder:filePath];
			}
		}
		
		// image multiple source files, or single files (other than folders) use mkdmg
		if(status == 0 && !isDir){
			compression = [defaults objectForKey:@"compression"];
			compressionLevel = [defaults objectForKey:@"compressionLevel"];
			
			// set arguments
			if(verbose)
				[arguments addObject:@"-v"];
			if(internetEnabled)
				[arguments addObject:@"-e"];
			if(encryption)
			{
				[arguments addObject:@"-c"];
				if(![[self encryptionType] isEqual:@""])
					[arguments addObject:[self encryptionType]];
				else
					[arguments addObject:@"AES-128"];
			}
			if(overwrite)
				[arguments addObject:@"-o"];
			[arguments addObject:@"-f"];
			[arguments addObject:compression];
			if([compression isEqual:@"UDZO"]){
				[arguments addObject:@"-z"];
				[arguments addObject:[compressionLevel stringValue]];
			}
			[arguments addObject:@"-i"];
			[arguments addObject:imagePath];
			[arguments addObjectsFromArray:files];
			
			status = [self openTask:path withArguments:arguments];			
		}
	}
	return status;
}

-(int) createImage:(NSString*)imagePath fromFolder:(NSString*)sourcePath
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDir;
	int status = 0;
	
	// check to see that the source path exists, and is a folder
	if([fileManager fileExistsAtPath:sourcePath isDirectory:&isDir] && isDir)
	{
		
		NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:1];
		
		[arguments addObject:@"create"];
		[arguments addObject:@"-srcfolder"];
		[arguments addObject:sourcePath];
		
		// add optional segment limit for image to arguments
		//		if(limitSegmentSize){
		//			[arguments addObject:@"-segmentSize"];
		//			[arguments addObject:[[limitSegmentSizeTextField stringValue] stringByAppendingString:[limitSegmentSizeButton title]]];
		//		}
		
		[arguments addObject:imagePath];
		[arguments addObject:@"-format"];
		[arguments addObject:[self compression]];
		
		// add optional zlib compression with UDZO format to arguments
		if([[self compression] isEqual:@"UDZO"])
		{
			[arguments addObject:@"-imagekey"];
			[arguments addObject: [@"zlib-level=" stringByAppendingString:[[self compressionLevel] stringValue]]];
		}
		
		// add optional encryption options to arguments
		if(encryption){
			[arguments addObject:@"-encryption"];
			if(!![[self encryptionType] isEqual:@""]){
				[arguments addObject:[self encryptionType]];
			}
		}
		// check if the user has chosen to overwrite
		if(overwrite)
			[arguments addObject:@"-ov"];
		
		if(verbose)
			[arguments addObject:@"-verbose"];

		[arguments addObject:@"-puppetstrings"];
			
		status = [self openTask:@"/usr/bin/hdiutil" withArguments:arguments];
	}
	else
		status = 1;
	return status;
}

-(int) createImage:(NSString*)imagePath fromDevice:(NSString*)sourcePath
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	int status = 0;
	
	// check to see that the source path exists, and is a folder
	if([fileManager fileExistsAtPath:sourcePath])
	{
		
		NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:1];
		
		[arguments addObject:@"create"];
		[arguments addObject:@"-srcdevice"];
		[arguments addObject:sourcePath];
		[arguments addObject:imagePath];
		
		// add optional segment limit for image to arguments
		if(limitSegmentSize){
			[arguments addObject:@"-segmentSize"];
			[arguments addObject:[[limitSegmentSizeTextField stringValue] stringByAppendingString:[limitSegmentSizeButton title]]];
		}
		
		[arguments addObject:@"-format"];
		[arguments addObject:[self compression]];
		
		// add optional zlib compression with UDZO format to arguments
		if([[self compression] isEqual:@"UDZO"])
		{
			[arguments addObject:@"-imagekey"];
			[arguments addObject: [@"zlib-level=" stringByAppendingString:[[self compressionLevel] stringValue]]];
		}
		
		// add optional encryption options to arguments
		if(encryption){
			[arguments addObject:@"-encryption"];
			if([[self encryptionType] isEqual:@""]){
				[arguments addObject:[self encryptionType]];
			}
		}
		
		// check if the user has chosen to overwrite
		if(overwrite){
			[arguments addObject:@"-ov"];
		}
		
		if(verbose)
			[arguments addObject:@"-verbose"];
		
		[arguments addObject:@"-puppetstrings"];
		
		status = [self openTask:@"/usr/bin/hdiutil" withArguments:arguments];
	}
	else
		status = 1;
	return status;
}

// mount disk image function
-(int) mountImage:(NSString*)path
{
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:1];
	
	[args addObjectsFromArray:[NSArray arrayWithObjects: path, nil]];
	
//		[args addObject:@"-puppetstrings"];
	
	return [self openTask:@"/usr/bin/open" withArguments:args];
}

-(int) ejectImage:(NSString*)path
{
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:1];
	
	[args addObjectsFromArray:[NSArray arrayWithObjects: @"eject", path, nil]];
	
	[args addObject:@"-puppetstrings"];
	
	return [self openTask:@"/usr/bin/hdiutil" withArguments:args];
}

// convert disk image function
-(int) convertImage:(NSString*)image format:(NSString*)format outfile:(NSString*)file
{
	int status = 1;
	NSMutableArray * args = [NSMutableArray arrayWithCapacity:1];
	
	// required convert options
	[args addObject:@"convert"];
	[args addObject:@"-format"];
	[args addObject:format];
	[args addObject:@"-o"];
	[args addObject:file];
	
	// optional convert options
	if([format isEqual:@"UDZO"]){
		[args addObject:@"-imagekey"];
		[args addObject: [@"zlib-level=" stringByAppendingString:[compressionLevel stringValue]]];
	}
	if(encryption){
		[args addObject:@"-encryption"];
		if(![self isTiger] && ![[self encryptionType] isEqual:@""]){
			[args addObject:[self encryptionType]];
		}
	}
	if(overwrite)
		[args addObject:@"-ov"];
	[args addObject:@"-puppetstrings"];
	
	// image path
	[args addObject:image];
	
	// execute the program
	status = [self openTask:@"/usr/bin/hdiutil" withArguments:args];
	
	return status;
}

// make internet enabled function
-(int) makeInternetEnabledAtPath:(NSString*)path
{
	int status = 1;
	
	status = [self openTask:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"internet-enable", @"-yes", path, nil]];
	
	return status;
}

// compact image function
-(int) compactImageAtPath:(NSString*)path
{
	int status = 1;
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:1];
	
	[args addObjectsFromArray:[NSArray arrayWithObjects: @"compact", path, nil]];
	
	[args addObject:@"-puppetstrings"];
	
	status = [self openTask:@"/usr/bin/hdiutil" withArguments:args];
	
	return status;
}

// scan image for restore function
-(int) scanImageForRestore:(NSString*)imagePath blockOnly:(BOOL)blockonly
{
    int status = 1;
    if(!blockonly)
        status = [self openTask:@"/usr/sbin/asr" withArguments:[NSArray arrayWithObjects:@"-imagescan", imagePath, nil]];
    else
        status = [self openTask:@"/usr/sbin/asr" withArguments:[NSArray arrayWithObjects:@"-imagescan", @"-blockonly", imagePath, nil]];
    return status;
}


// image info function
- (int) imageInfoAtPath:(NSString*) imagePath
{
    BOOL isDir;
    NSFileManager * fileManager = [NSFileManager defaultManager];
    
    if([fileManager fileExistsAtPath:imagePath isDirectory:&isDir] && !isDir)
        return [self openTask:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"imageinfo", imagePath, nil]];
    else
        return 1;
}

// image verify function
- (int) verifyImageAtPath:(NSString*) imagePath
{
    BOOL isDir;
    NSFileManager * fileManager = [NSFileManager defaultManager];
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:1];
	
	[args addObjectsFromArray:[NSArray arrayWithObjects: @"verify", imagePath, nil]];
	
	[args addObject:@"-puppetstrings"];
	
    if([fileManager fileExistsAtPath:imagePath isDirectory:&isDir] && !isDir)
        return [self openTask:@"/usr/bin/hdiutil" withArguments:args];
    else
        return 1;
}

// checksum image function
- (int) checksumImageAtPath:(NSString*) imagePath type:(NSString*) type
{
    BOOL isDir;
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:1];
	
	[args addObjectsFromArray:[NSArray arrayWithObjects: @"checksum", imagePath, @"-type", type, nil]];
	
	[args addObject:@"-puppetstrings"];
	
    if([fileManager fileExistsAtPath:imagePath isDirectory:&isDir] && !isDir)
        return [self openTask:@"/usr/bin/hdiutil" withArguments:args];
    else
        return 1;
}

- (int) changePasswordOfImageAtPath:(NSString*)path
{
	BOOL isDir;
    NSFileManager * fileManager = [NSFileManager defaultManager];
    
    if([fileManager fileExistsAtPath:path isDirectory:&isDir] && !isDir)
        return [self openTask:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"chpass", path, nil]];
    else
        return 1;
}


- (int) burnImageAtPath:(NSString*)path
{
	BOOL isDir;
	burnRunning = FALSE;
	gotMedia = FALSE;
	
    NSFileManager * fileManager = [NSFileManager defaultManager];
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:1];
	DRNotificationCenter *burnNotification = [DRNotificationCenter currentRunLoopCenter];
	[burnNotification addObserver:self selector:@selector(burnEvent:) name:nil object:nil];
	
	[args addObjectsFromArray:[NSArray arrayWithObjects: @"burn", path, nil]];
	
	[args addObject:@"-puppetstrings"];
	
    if([fileManager fileExistsAtPath:path isDirectory:&isDir] && !isDir)
        return [self openTask:@"/usr/bin/hdiutil" withArguments:args];
    else
        return 1;
}

- (IBAction) burnEvent:(id)sender
{
	
	//DRDeviceCurrentWriteSpeedKey = 0; 
	//    DRDeviceIsBusyKey = 0; 
	//    DRDeviceIsTrayOpenKey = 0; 
	//    DRDeviceMaximumWriteSpeedKey = 0; 
	//    DRDeviceMediaStateKey = DRDeviceMediaStateNone; 
	//	
	
	//NSLog([sender name]);
	//NSLog([[[sender object] status] description]);
	
	if([[[[sender object] status] objectForKey:@"DRDeviceMediaStateKey"] isEqualToString:@"DRDeviceMediaStateNone"])
	{
		if(burnRunning == TRUE)
		{
			if([[[[sender object] status] objectForKey:@"DRDeviceMediaStateKey"] isEqualToString:@"DRDeviceMediaStateNone"] &&
			   !([[[[sender object] status] objectForKey:@"DRDeviceIsBusyKey"] intValue]) &&
			   !gotMedia)
			{
				// user closed drawer without inserting media
				burnRunning = FALSE;
				[freeDMGTask stopProcess];
			}
		}
		
	}
	else if([[[[sender object] status] objectForKey:@"DRDeviceMediaStateKey"] isEqualToString:@"DRDeviceMediaStateInTransition"])
	{		
		// we have started a burn
		burnRunning = TRUE;	
	}
	else if([[[[sender object] status] objectForKey:@"DRDeviceMediaStateKey"] isEqualToString:@"DRDeviceMediaStateMediaPresent"])
	{
		gotMedia = TRUE;
	}
}

- (int) segmentImageAtPath:(NSString*)path segmentName:(NSString*)name segmentSize:(NSString*)size
{
	BOOL isDir;
    NSFileManager * fileManager = [NSFileManager defaultManager];
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:1];
	
	[args addObjectsFromArray:[NSArray arrayWithObjects: @"segment", @"-segmentSize", size, @"-o", name, path, nil]];
	
	[args addObject:@"-puppetstrings"];
	
    if([fileManager fileExistsAtPath:path isDirectory:&isDir] && !isDir)
        return [self openTask:@"/usr/bin/hdiutil" withArguments:args];
    else
        return 1;
}

- (int) resizeImageAtPath:(NSString*)path size:(NSNumber *)sizeInMB
{
	BOOL isDir;
    NSFileManager * fileManager = [NSFileManager defaultManager];
    
    if([fileManager fileExistsAtPath:path isDirectory:&isDir] && !isDir)
        return [self openTask:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"resize", @"-size", [[sizeInMB stringValue] stringByAppendingString:@"m"], [resizeImageTextField stringValue], nil]];
    else
        return 1;
}

- (int) flattenImageAtPath:(NSString*)path
{
	BOOL isDir;
    NSFileManager * fileManager = [NSFileManager defaultManager];
    
    if([fileManager fileExistsAtPath:path isDirectory:&isDir] && !isDir)
        return [self openTask:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"flatten", path, nil]];
    else
        return 1;
}

- (int) unflattenImageAtPath:(NSString*)path
{
	BOOL isDir;
    NSFileManager * fileManager = [NSFileManager defaultManager];
    
    if([fileManager fileExistsAtPath:path isDirectory:&isDir] && !isDir)
        return [self openTask:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"unflatten", path, nil]];
    else
        return 1;
}

- (NSArray *) resizeLimitsForImage:(NSString*)path
{
	
	// obtain the resize values from hdiutil using the "-plist" option
	NSString * output = [self openProgram:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"resize", @"-limits", path, @"-plist", nil]];
	NSDictionary *imageDict = [[NSDictionary alloc] initWithDictionary:[output propertyList]];
	NSMutableArray *imageArray = [NSMutableArray arrayWithCapacity:1];
	
	// insert the image's content-size into an array
	// check to see if there is a size listed
	if([imageDict objectForKey:@"content-length"] != nil)
		[imageArray addObject:[imageDict objectForKey:@"content-length"]];
	
	// check to see if there is a minimum size listed
	if([imageDict objectForKey:@"content-min-length"] != nil)
		[imageArray addObject:[imageDict objectForKey:@"content-min-length"]];
	else
		[imageArray addObject:[imageDict objectForKey:@"content-length"]];
	
	// check to see if there is a maximum size listed
	if([imageDict objectForKey:@"content-max-length"] != nil)
		[imageArray addObject:[imageDict objectForKey:@"content-max-length"]];
	else
		[imageArray addObject:[imageDict objectForKey:@"content-length"]];
	
	[imageDict release];
		
	return imageArray;
}

- (double) MBFromSectors:(double)sectors
{
	return (sectors/2048);
}

- (double) GBFromSectors:(double)sectors
{
	return (sectors/2097152);
}

// create image function
-(IBAction) createImage:(id)sender
{
	if(!freeDMGRunning){
		[imageProgress setUsesThreadedAnimation:TRUE];
		[imageProgress startAnimation:self];
		[statusTextField setStringValue:NSLocalizedString(@"Imaging", @"Imaging...")];
		
		[self updatePreferencesPanel];
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:TRUE];
		[panel setCanChooseFiles:TRUE];
		[panel setAllowsMultipleSelection:TRUE];
		[panel setTitle:NSLocalizedString(@"Create", @"Create Image from Files")];
		
		if ([panel runModal] == NSOKButton) {
			
			if([self createImageWithFiles:[panel filenames]] == 0)
			{
				[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
			}
			else
			{
				[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
			}
		}
		else
		{
			[imageProgress stopAnimation:self];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

-(IBAction) dropAction:(id)sender
{
	if(!freeDMGRunning)
		[self createImageWithFiles:[sender dropArray]];
}

#pragma mark SLA methods

- (void) saveSLAStringValue
{
	if([SLATableView selectedRow] != -1)
	{
		NSMutableArray *SLAs = [NSMutableArray arrayWithCapacity:1];
		[SLAs addObjectsFromArray:[defaults objectForKey:@"SLAs"]];
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:1];
		[info addEntriesFromDictionary:[SLAs objectAtIndex:[SLATableView selectedRow]]];
		[info setObject:[SLATextView RTFFromRange:NSMakeRange(0, [[SLATextView textStorage] length])] forKey:@"string"];
		[SLAs replaceObjectAtIndex:[SLATableView selectedRow] withObject:info];
		[defaults setObject:SLAs forKey:@"SLAs"];
		[defaults synchronize];
		[SLATableView reloadData];
	}
}

- (int) addCarbonResourcesToImage:(NSString *) imagePath
{
	NSFileManager * fileManager = [NSFileManager defaultManager];
	int status = 1;
	if([fileManager fileExistsAtPath:@"/Developer/Tools/Rez"]){
		if([fileManager fileExistsAtPath:[[NSBundle mainBundle] pathForResource:@"SLA.r" ofType:nil]]){
			NSArray *arguments = [[NSArray alloc] initWithObjects:@"/Developer/Headers/FlatCarbon/AEDataModel.r",
										@"/Developer/Headers/FlatCarbon/AEObjects.r",
										@"/Developer/Headers/FlatCarbon/AERegistry.r",
										@"/Developer/Headers/FlatCarbon/AEUserTermTypes.r",
										@"/Developer/Headers/FlatCarbon/AEWideUserTermTypes.r",
										@"/Developer/Headers/FlatCarbon/ASRegistry.r",
										@"/Developer/Headers/FlatCarbon/AVComponents.r",
										@"/Developer/Headers/FlatCarbon/Appearance.r",
										@"/Developer/Headers/FlatCarbon/AppleEvents.r",
										@"/Developer/Headers/FlatCarbon/ApplicationServices.r",
										@"/Developer/Headers/FlatCarbon/BalloonTypes.r",
										@"/Developer/Headers/FlatCarbon/Balloons.r",
										@"/Developer/Headers/FlatCarbon/Carbon.r",
										@"/Developer/Headers/FlatCarbon/CarbonEvents.r",
										@"/Developer/Headers/FlatCarbon/CodeFragmentTypes.r",
										@"/Developer/Headers/FlatCarbon/CodeFragments.r",
										@"/Developer/Headers/FlatCarbon/Collections.r",
										@"/Developer/Headers/FlatCarbon/CommResources.r",
										@"/Developer/Headers/FlatCarbon/Components.r",
										@"/Developer/Headers/FlatCarbon/ConditionalMacros.r",
										@"/Developer/Headers/FlatCarbon/ControlDefinitions.r",
										@"/Developer/Headers/FlatCarbon/Controls.r",
										@"/Developer/Headers/FlatCarbon/CoreServices.r",
										@"/Developer/Headers/FlatCarbon/DatabaseAccess.r",
										@"/Developer/Headers/FlatCarbon/DesktopPrinting.r",
										@"/Developer/Headers/FlatCarbon/Devices.r",
										@"/Developer/Headers/FlatCarbon/Dialogs.r",
										@"/Developer/Headers/FlatCarbon/Displays.r",
										@"/Developer/Headers/FlatCarbon/EPPC.r",
										@"/Developer/Headers/FlatCarbon/FileTypesAndCreators.r",
										@"/Developer/Headers/FlatCarbon/Finder.r",
										@"/Developer/Headers/FlatCarbon/FinderRegistry.r",
										@"/Developer/Headers/FlatCarbon/Folders.r",
										@"/Developer/Headers/FlatCarbon/Fonts.r",
										@"/Developer/Headers/FlatCarbon/Gestalt.r",
										@"/Developer/Headers/FlatCarbon/IAExtractor.r",
										@"/Developer/Headers/FlatCarbon/Icons.r",
										@"/Developer/Headers/FlatCarbon/ImageCodec.r",
										@"/Developer/Headers/FlatCarbon/ImageCompression.r",
										@"/Developer/Headers/FlatCarbon/InputSprocket.r",
										@"/Developer/Headers/FlatCarbon/IntlResources.r",
										@"/Developer/Headers/FlatCarbon/IsochronousDataHandler.r",
										@"/Developer/Headers/FlatCarbon/LocationManager.r",
										@"/Developer/Headers/FlatCarbon/MacTypes.r",
										@"/Developer/Headers/FlatCarbon/MacWindows.r",
										@"/Developer/Headers/FlatCarbon/Menus.r",
										@"/Developer/Headers/FlatCarbon/MixedMode.r",
										@"/Developer/Headers/FlatCarbon/NetworkSetup.r",
										@"/Developer/Headers/FlatCarbon/OSUtils.r",
										@"/Developer/Headers/FlatCarbon/OTConfig.r",
										@"/Developer/Headers/FlatCarbon/OpenTransport.r",
										@"/Developer/Headers/FlatCarbon/OpenTransportKernel.r",
										@"/Developer/Headers/FlatCarbon/OpenTransportProtocol.r",
										@"/Developer/Headers/FlatCarbon/OpenTransportProviders.r",
										@"/Developer/Headers/FlatCarbon/PCCardEnablerPlugin.r",
										@"/Developer/Headers/FlatCarbon/PPCToolbox.r",
										@"/Developer/Headers/FlatCarbon/Palettes.r",
										@"/Developer/Headers/FlatCarbon/Pict.r",
										@"/Developer/Headers/FlatCarbon/PictUtils.r",
										@"/Developer/Headers/FlatCarbon/Processes.r",
										@"/Developer/Headers/FlatCarbon/QTSMovie.r",
										@"/Developer/Headers/FlatCarbon/QTStreamingComponents.r",
										@"/Developer/Headers/FlatCarbon/QuickTime.r",
										@"/Developer/Headers/FlatCarbon/QuickTimeComponents.r",
										@"/Developer/Headers/FlatCarbon/Quickdraw.r",
										@"/Developer/Headers/FlatCarbon/Script.r",
										@"/Developer/Headers/FlatCarbon/Slots.r",
										@"/Developer/Headers/FlatCarbon/Sound.r",
										@"/Developer/Headers/FlatCarbon/SoundComponents.r",
										@"/Developer/Headers/FlatCarbon/SoundInput.r",
										@"/Developer/Headers/FlatCarbon/SysTypes.r",
										@"/Developer/Headers/FlatCarbon/TextCommon.r",
										@"/Developer/Headers/FlatCarbon/TranslationExtensions.r",
										@"/Developer/Headers/FlatCarbon/Types.r",
										@"/Developer/Headers/FlatCarbon/UnicodeConverter.r",
										@"/Developer/Headers/FlatCarbon/UnicodeUtilities.r",
										@"/Developer/Headers/FlatCarbon/Video.r",
										@"/Developer/Headers/FlatCarbon/Windows.r", 
										[[NSBundle mainBundle] pathForResource:@"SLA.r" ofType:nil],
										@"-a",
										@"-o",
										imagePath, nil];
			
			[self FDLog:[@"Adding Carbon and basic SLA resources to image: " stringByAppendingString:imagePath]];
			[statusTextField setStringValue:NSLocalizedString(@"SLA_AddingCarbon", @"Adding Carbon and basic SLA resources to image...")];
			
			status = [[self openProgram:@"/Developer/Tools/Rez" withArguments:arguments] intValue];
			
			[arguments release];
		}
		else{
			[self FDLog:@"The file \"SLA.r\" could not be found inside the FreeDMG bundle. Please re-install FreeDMG."];
			return 5;
		}
	}
	else{
		[self FDLog:@"Rez not found at path: /Developer/Tools/Rez. Please install Xcode tools."];
		return 6;
	}
	return status;
}

- (int) addResourcesFromSource:(NSString *) resourcesPath toImage:(NSString *) imagePath
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	int status = 0;
	NSString * resourceID = [[NSString alloc] initWithString:[[resourcesPath lastPathComponent] stringByDeletingPathExtension]];
	
	// verify that the paths passed are not NULL
	if((imagePath != NULL) && (resourcesPath != NULL)){
		// verify that the image exists
		if([fileManager fileExistsAtPath:imagePath]){
			// verify that the resources path exists (FreeDMG creates this directory: ~/Library/Preferences/FreeDMG at startup)
			// if this does not exist, FreeDMG's package has been monkeyed-vit
			if([fileManager fileExistsAtPath:[resourcesPath stringByDeletingLastPathComponent]]){
				// verify that Rez is installed (Xcode tools must be installed).
				if([fileManager fileExistsAtPath:@"/Developer/Tools/Rez"]){
					// add all arguments for Rez to add this resource
					NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:1];
					[arguments addObject:resourcesPath];
					// we want to append the resources, so that we don't corrupt the image
					[arguments addObject:@"-a"];
					[arguments addObject:@"-o"];
					[arguments addObject:imagePath];
					
					[self FDLog:[[[@"Adding resources with id: " stringByAppendingString:resourceID] stringByAppendingString: @" to image: "] stringByAppendingString:imagePath]];
					[statusTextField setStringValue:[[NSLocalizedString(@"SLA_AddingResources", @"Adding resources with id: ") stringByAppendingString:resourceID] stringByAppendingString:@"..."]];
					
					status = [[self openProgram:@"/Developer/Tools/Rez" withArguments:arguments] intValue];
					
					if(status != 0){
						[self FDLog:@"Error adding resources"];
						status = 11;
					}
				}
				else{
					[self FDLog:@"Error: Developer tools not installed"];
					status = 6;
				}
			}
			else{
				[self FDLog:[@"Error: SLAs directory not found at: " stringByAppendingString:resourcesPath]];
				status = 7;
			}
			
		}
		else{
			[self FDLog:[@"Error: image not found at: " stringByAppendingString:imagePath]];
			status = 8;
		}
	}
	else{
		[self FDLog:@"Error: path to resources or image is null"];
		status = 9;
	}
	[resourceID release];
	return status;
}

- (int) createResourcesAtPath:(NSString *) resourcePath
				   withAttributedString:(NSAttributedString *) resourceString
					   withID:(int)resourceID
				   withLocale:(NSString *)locale
{
	
	resourcePath = [resourcePath stringByDeletingPathExtension];
	resourcePath = [resourcePath stringByAppendingPathExtension:@"rtf"];
	
	NSAttributedString *astr = [[NSAttributedString alloc] initWithAttributedString:resourceString];
	// as you know, attributes strings can contain size, color, link, and more
	// so we had better store text as attributed string
	NSData *data = [astr RTFFromRange:NSMakeRange(0, [astr length])
				   documentAttributes:nil];
	[astr release];
	if ([data writeToFile:resourcePath atomically:YES] ) {
		if([self openProgram:[[NSBundle mainBundle] pathForResource:@"rtf2r" ofType:nil] withArguments:[NSArray arrayWithObjects:@"-l", [[NSNumber numberWithInt:resourceID] stringValue], resourcePath, nil]] > 0)
			return 0;
		else
			return 1;
	}
	return 1;
}

- (int) createResourcesForEnabledSLAs
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	int SLAcount = [[defaults objectForKey:@"SLAs"] count],  status = 0;
	NSMutableArray *allResources = [[NSMutableArray alloc] initWithArray:[defaults objectForKey:@"SLAs"]];
	NSMutableArray *enabledResources = [[NSMutableArray alloc] init];
	
	if(SLAcount > 0)
	{
		int i = 0;
		
		while(i < SLAcount)
		{
			if([[[allResources objectAtIndex:i] objectForKey:@"enabled"] boolValue] == TRUE)
			{
				[enabledResources addObject:[allResources objectAtIndex:i]];
			}
			i++;
		}
		if([enabledResources count] > 0)
		{
			i = 0;
			while((i < [enabledResources count]) && status == 0)
			{				
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				NSString *resourcesName = [[[NSString alloc] initWithString:[[[[enabledResources objectAtIndex:i] objectForKey:@"id"] stringValue] stringByAppendingPathExtension:@"r"]] autorelease];
				NSString *resourcesPath = [[[NSString alloc] initWithString:[[NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/FreeDMG/SLAs/"] stringByAppendingString:resourcesName]] autorelease];
				NSAttributedString *resourcesString = [[[NSAttributedString alloc] initWithData:[[enabledResources objectAtIndex:i] objectForKey:@"string"]  options:nil documentAttributes:nil error:nil] autorelease];
				NSString *resourcesLocale = [[[NSString alloc] initWithString:[[enabledResources objectAtIndex:i] objectForKey:@"language"]] autorelease];
				NSNumber *resourcesID = [[[[enabledResources objectAtIndex:i] objectForKey:@"id"] copyWithZone:nil] autorelease];
				[self FDLog:[@"Creating resources with id:" stringByAppendingString:[resourcesID stringValue]]];
				[statusTextField setStringValue:[NSLocalizedString(@"SLA_CreatingResources", @"Creating resources with id: ") stringByAppendingString:[resourcesID stringValue]]];
				status = [self createResourcesAtPath:resourcesPath
								withAttributedString:resourcesString
											  withID:[resourcesID intValue]
										  withLocale:resourcesLocale];
				[pool drain];
				i++;
			}
		}
	}
	[allResources release];
	[enabledResources release];
	[pool release];
	
	return status;
}


#pragma mark Preferences Actions

- (void) updatePreferencesPanel
{
	// read preferences for 'verbose', and set UI
	if([defaults objectForKey:@"verbose"] != nil){
		verbose = [defaults boolForKey:@"verbose"];
		[verboseButton setState:verbose];
		[accVerboseButton setState:verbose];
	}
	else
		[defaults setBool:verbose forKey:@"verbose"];
	
	// read preferences for 'internetEnabled', and set UI
	if([defaults objectForKey:@"internetEnabled"] != nil){
		internetEnabled = [defaults boolForKey:@"internetEnabled"];
		[internetEnabledButton setState:internetEnabled];
		[accInternetButton setState:internetEnabled];
	}
	else
		[defaults setBool:internetEnabled forKey:@"internetEnabled"];
	
	// read preferences for 'compression', and set UI
	if([defaults objectForKey:@"compression"] != nil){
		compression = [defaults stringForKey:@"compression"];
	}
	else
		[defaults setObject:[self compression] forKey:@"compression"];
	
	// read preferences for "compressionLevel" and set UI
	if([defaults objectForKey:@"compressionLevel"] != nil)
	{
		compressionLevel = [defaults objectForKey:@"compressionLevel"];
		[compressionLevelSlider setIntValue:[compressionLevel intValue]];
	}
	else
		[defaults setObject:compressionLevel forKey:@"compressionLevel"];
	
	// read preferences for 'convertFormat', and set UI
	if([defaults objectForKey:@"convertFormat"] != nil){
		convertFormat = [defaults stringForKey:@"convertFormat"];
	}
	else
		[defaults setObject:[self convertFormat] forKey:@"convertFormat"];
	
	// set compression buttons	
	if([compression isEqual:@"UDRW"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UDRW", @"UDRW - UDIF read/write image")];
	else if([compression isEqual:@"UDRO"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UDRO", @"UDRO - UDIF read-only image")];
	else if([compression isEqual:@"UDCO"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UDCO", @"UDCO - UDIF ADC-compressed image")];
	else if([compression isEqual:@"UFBI"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UFBI", @"UFBI - UDIF entire image with MD5 checksum")];	
	else if([compression isEqual:@"UDTO"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UDTO", @"UDTO - DVD/CD-R master for export")];	
	else if([compression isEqual:@"UDxx"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UDxx", @"UDxx - UDIF stub image")];	
	else if([compression isEqual:@"UDSP"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UDSP", @"UDSP - SPARSE (growable with content)")];
	else if([compression isEqual:@"UDSB"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UDSB", @"UDSB - SPARSE bundle (growable with content)")];	
	else if([compression isEqual:@"RdWr"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"RdWr", @"RdWr - NDIF read/write image (deprecated)")];	
	else if([compression isEqual:@"Rdxx"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"Rdxx", @"Rdxx - NDIF read-only image (Disk Copy 6.3.3 format)")];		
	else if([compression isEqual:@"ROCo"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"ROCo", @"ROCo - NDIF compressed image (deprecated)")];		
	else if([compression isEqual:@"DC42"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"DC42", @"DC42 - Disk Copy 4.2 image")];
	else if([compression isEqual:@"UDBZ"])
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UDBZ", @"UDBZ - UDIF bzip2-compressed image (OS X 10.4+ only)")];
	else{
		[compressionButton selectItemWithTitle:NSLocalizedString(@"UDZO", @"UDZO - UDIF zlib-compressed image")];
		[compressionLevelSlider setEnabled:TRUE];
	}
	
	// set convert format buttons	
	if([convertFormat isEqual:@"UDRW"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UDRW", @"Read/Write")];
	else if([convertFormat isEqual:@"UDRO"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UDRO", @"Read-only")];
	else if([convertFormat isEqual:@"UDCO"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UDCO", @"Compressed")];
	else if([convertFormat isEqual:@"UFBI"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UFBI", @"Compressed")];
	else if([convertFormat isEqual:@"UDTO"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UDTO", @"DVD/CD-R master")];
	else if([convertFormat isEqual:@"UDxx"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UDxx", @"Compressed")];
	else if([convertFormat isEqual:@"UDSP"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UDSP", @"Sparse")];
	else if([convertFormat isEqual:@"UDSB"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UDSB", @"Sparse bundle")];
	else if([convertFormat isEqual:@"RdWr"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_RdWr", @"Read/Write (Mac OS 9)")];
	else if([convertFormat isEqual:@"Rdxx"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_Rdxx", @"Read-only (Mac OS 9)")];
	else if([convertFormat isEqual:@"ROCo"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_ROCo", @"Compressed (Mac OS 9)")];
	else if([convertFormat isEqual:@"DC42"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_DC42", @"Compressed")];
	else if([convertFormat isEqual:@"UDBZ"])
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UDBZ", @"Compressed (bzip2)")];			
	else
		[convertFormatButton selectItemWithTitle:NSLocalizedString(@"Convert_UDZO", @"Compressed (zlib)")];
	
	//read preferences for type and set UI
	if([defaults objectForKey:@"type"] != nil)
	{
		if([[defaults objectForKey:@"type"] isEqualToString:@"SPARSE"])
			[newTypeButton selectItemWithTitle:NSLocalizedString(@"New_Sparse", @"sparseimage")];
		else if([[defaults objectForKey:@"type"] isEqualToString:@"SPARSEBUNDLE"])
			[newTypeButton selectItemWithTitle:NSLocalizedString(@"New_Sparsebundle", @"sparsebundle")];
		else
			[newTypeButton selectItemWithTitle:NSLocalizedString(@"New_Read_Write", @"read/write disk image")];
	}
	
	// read preferences for 'encryption', and set UI
	if([defaults objectForKey:@"encryption"] != nil){
		encryption = [defaults boolForKey:@"encryption"];
		if(encryption){
			if(![[self encryptionType] isEqual:@""]){
				if([[self encryptionType] isEqual:@"AES-256"])
				{
					[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
					[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
					[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
					[accPasswordButton setState:encryption];
				}
				else if([[self encryptionType] isEqual:@"AES-128"])
				{
					[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
					[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
					[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
					[accPasswordButton setState:encryption];
				}
				
			}
			else{
				[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
				[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
				[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
				[accPasswordButton setState:encryption];
			}
		}
		else{
			[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];
			[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];
			[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];		
			[accPasswordButton setState:encryption];
		}
	}
	else
		[defaults setBool:encryption forKey:@"encryption"];
	
	// read preferences for 'prompt', and set UI
	if([defaults objectForKey:@"prompt"] != nil){
		prompt = [defaults boolForKey:@"prompt"];
		[promptButton setState:prompt];
		[accPromptButton setState:prompt];
	}
	else
		[defaults setBool:prompt forKey:@"prompt"];
	
	// read preferences for "quit" and set UI
	if([defaults objectForKey:@"quit"] != nil)
	{
		quit = [defaults boolForKey:@"quit"];
		[quitButton setState:quit];
	}
	else
		[defaults setBool:quit forKey:@"quit"];
	
	// read preferences for 'overwrite', and set UI
	if([defaults objectForKey:@"overwrite"] != nil){
		overwrite = [defaults boolForKey:@"overwrite"];
		[overwriteButton setState:overwrite];
		[accOverwriteButton setState:overwrite];
		
	}
	else
		[defaults setBool:overwrite forKey:@"overwrite"];
	
	// read preferences for 'imageDropAction', and set UI
	if([defaults objectForKey:@"imageDropAction"] != nil){
		imageDropAction = [defaults objectForKey:@"imageDropAction"];
		[imageDropMatrix selectCellWithTag:[imageDropAction intValue]];
	}
	else
		[defaults setObject:imageDropAction forKey:@"imageDropAction"];
	
	// read preferences for 'volumeFormat', and set UI
	if([defaults objectForKey:@"volumeFormat"] != nil){
		volumeFormat = [defaults objectForKey:@"volumeFormat"];
		[volumeFormatButton selectItemWithTitle:volumeFormat];
	}
	else
		[defaults setObject:volumeFormat forKey:@"volumeFormat"];
	
	// read preferences for 'logPosition', and set UI
	//if([defaults objectForKey:@"logPosition"] != nil){
//		logPosition = [defaults objectForKey:@"logPosition"];
//		[logPositionButton selectItemWithTitle:logPosition];
//		
//		// Clear log position menu selection
//		int i = 0;
//		while (i < [[logPositionMenu itemArray] count])
//		{
//			[[[logPositionMenu itemArray] objectAtIndex:i] setState:0];
//			i++;
//		}
//		
//		// Set log position menu selection
//		[[logPositionMenu itemWithTitle:logPosition] setState:1];
//	}
//	else
//		[defaults setObject:logPosition forKey:@"logPosition"];
	
	// read preferences for 'logPosition', and set UI
	if([defaults objectForKey:@"logPosition"] != nil){
		logPosition = [defaults objectForKey:@"logPosition"];
		[logPositionButton selectItemWithTag:[logPosition intValue]];
		
		// Clear log position menu selection
		int i = 0;
		while (i < [[logPositionMenu itemArray] count])
		{
			[[[logPositionMenu itemArray] objectAtIndex:i] setState:0];
			i++;
		}
		
		// Set log position menu selection
		[[logPositionMenu itemWithTag:[logPosition intValue]] setState:1];
	}
	else
		[defaults setObject:logPosition forKey:@"logPosition"];
	
	//read preferences for 'limitSegmentSize', and set UI
	if([defaults boolForKey:@"limitSegmentSize"] != nil){
		limitSegmentSize = [defaults boolForKey:@"limitSegmentSize"];
		[limitSegmentButton setState:limitSegmentSize];
	}
	else
	{
		[defaults setBool:limitSegmentSize forKey:@"limitSegmentSize"];
		[limitSegmentButton setState:limitSegmentSize];
	}
	
	//read preferences for 'limitSegmentSizeByte', and set UI
	if([defaults objectForKey:@"limitSegmentSizeByte"] != nil){
		limitSegmentSizeByte = [defaults objectForKey:@"limitSegmentSizeByte"];
		[limitSegmentSizeButton selectItemWithTitle:limitSegmentSizeByte];
	}
	else
		[defaults setObject:limitSegmentSizeByte forKey:@"limitSegmentSizeByte"];
	
	//read preferences for 'segmentSize', and set UI
	if([defaults objectForKey:@"segmentSize"] != nil){
		segmentSize = [defaults objectForKey:@"segmentSize"];
		[limitSegmentSizeTextField setDoubleValue:[segmentSize doubleValue]];
		
	}
	else
		[defaults setObject:segmentSize forKey:@"segmentSize"];
	
	if(limitSegmentSize)
	{
		[limitSegmentSizeButton setEnabled:TRUE];
		[limitSegmentSizeTextField setEnabled:TRUE];
	}
	else
	{
		[limitSegmentSizeButton setEnabled:FALSE];
		[limitSegmentSizeTextField setEnabled:FALSE];
	}
	
}

-(IBAction) beginPreferencesPanel:(id)sender
{
	// set preferences before displaying
	[self updatePreferencesPanel];
	
	// display preferences window
	[NSApp beginSheet:Preferences
	   modalForWindow:[NSApp mainWindow]
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:nil];
}

-(IBAction) endPreferencesPanel:(id)sender
{
	[self endPreferencesPanel];
}

-(void) endPreferencesPanel
{
	[Preferences orderOut:self];
    [NSApp endSheet:Preferences];
}

- (IBAction) beginSLAPanel:(id)sender
{
	[defaults synchronize];
	[SLATableView reloadData];
	// display Software License Agreement panel
	[NSApp beginSheet:SLA
	   modalForWindow:[NSApp mainWindow]
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:nil];
}

- (IBAction) endSLAPanel:(id)sender
{
	[SLA orderOut:self];
    [NSApp endSheet:SLA];
}


-(IBAction) compressionButtonAction:(id)sender
{
	// set compression slider to un-enabled, unless the user is choosing UDZO format
	[compressionLevelSlider setEnabled:FALSE];
	
	// set compression format
	if([[sender title] isEqual:NSLocalizedString(@"UDRW", @"UDRW - UDIF read/write image")])
		compression = [NSString stringWithString:@"UDRW"];	
	else if([[sender title] isEqual:NSLocalizedString(@"UDRO", @"UDRO - UDIF read-only image")])
		compression = [NSString stringWithString:@"UDRO"];
	else if([[sender title] isEqual:NSLocalizedString(@"UDCO", @"UDCO - UDIF ADC-compressed image")])
		compression = [NSString stringWithString:@"UDCO"];	
	else if([[sender title] isEqual:NSLocalizedString(@"UFBI", @"UFBI - UDIF entire image with MD5 checksum")])
		compression = [NSString stringWithString:@"UFBI"];
	else if([[sender title] isEqual:NSLocalizedString(@"UDTO", @"UDTO - DVD/CD-R master for export")])
		compression = [NSString stringWithString:@"UDTO"];
	else if([[sender title] isEqual:NSLocalizedString(@"UDxx", @"UDxx - UDIF stub image")])
		compression = [NSString stringWithString:@"UDxx"];
	else if([[sender title] isEqual:NSLocalizedString(@"UDSP", @"UDSP - SPARSE (growable with content)")])
		compression = [NSString stringWithString:@"UDSP"];
	else if([[sender title] isEqual:NSLocalizedString(@"UDSB", @"UDSB - SPARSE bundle (growable with content)")])
		compression = [NSString stringWithString:@"UDSB"];
	else if([[sender title] isEqual:NSLocalizedString(@"RdWr", @"RdWr - NDIF read/write image (deprecated)")])
		compression = [NSString stringWithString:@"RdWr"];
	else if([[sender title] isEqual:NSLocalizedString(@"Rdxx", @"Rdxx - NDIF read-only image (Disk Copy 6.3.3 format)")])
		compression = [NSString stringWithString:@"Rdxx"];
	else if([[sender title] isEqual:NSLocalizedString(@"ROCo", @"ROCo - NDIF compressed image (deprecated)")])
		compression = [NSString stringWithString:@"ROCo"];
	else if([[sender title] isEqual:NSLocalizedString(@"DC42", @"DC42 - Disk Copy 4.2 image")])
		compression = [NSString stringWithString:@"DC42"];	
	else if([[sender title] isEqual:NSLocalizedString(@"UDBZ", @"UDBZ - UDIF bzip2-compressed image (OS X 10.4+ only)")])
		compression = [NSString stringWithString:@"UDBZ"];
	else{
		compression = [NSString stringWithString:@"UDZO"];	
		[compressionLevelSlider setEnabled:TRUE];
	}
	[self setCompression:compression];
	[self updatePreferencesPanel];
	
}

- (IBAction) encryptionButtonAction:(id)sender
{
	if([[sender title] isEqual:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")])
	{
		encryption = TRUE;
		[defaults setBool:encryption forKey:@"encryption"];
		encryptionType = [NSString stringWithString:@"AES-128"];
		[defaults setObject:encryptionType forKey:@"encryptionType"];
		[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		[accPasswordButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		
	}
	else if([[sender title] isEqual:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")])
	{
		encryption = TRUE;
		[defaults setBool:encryption forKey:@"encryption"];
		encryptionType = [NSString stringWithString:@"AES-256"];
		[defaults setObject:encryptionType forKey:@"encryptionType"];
		[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		[accPasswordButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		
	}
	else{
		encryption = FALSE;
		[defaults setBool:encryption forKey:@"encryption"];
		[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];
		[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];
		[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];		
		[accPasswordButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];		
	}
	[defaults synchronize];
	
	
}

-(IBAction) verboseButtonAction:(id)sender
{
	if ([sender state] == 1)
		verbose = YES;
	else
		verbose = NO;
	
	// save setting to standard user defaults
	[defaults setBool:verbose forKey:@"verbose"];
}

-(IBAction) internetEnabledButtonAction:(id)sender
{
	if ([sender state] == 1)
		internetEnabled = YES;
	else
		internetEnabled = NO;
	
	// save setting to standard user defaults
	[defaults setBool:internetEnabled forKey:@"internetEnabled"];
}

-(IBAction) promptButtonAction:(id)sender
{
	if ([sender state] == 1)
		prompt = YES;
	else
		prompt = NO;
	
	// save setting to standard user defaults
	[defaults setBool:prompt forKey:@"prompt"];
	
}

- (IBAction) segmentSizeButtonAction:(id)sender
{
}


- (IBAction) quitButtonAction:(id)sender
{
	if ([sender state] == 1)
		quit = YES;
	else
		quit = NO;
	
	// save setting to standard user defaults
	[defaults setBool:quit forKey:@"quit"];
}

- (IBAction) overwriteButtonAction:(id)sender
{
	if ([sender state] == 1)
		overwrite = YES;
	else
		overwrite = NO;
	
	// save setting to standard user defaults
	[defaults setBool:overwrite forKey:@"overwrite"];
}

-(IBAction) okButtonAction:(id)sender
{
	// write user defaults to disk
	[defaults synchronize];
	
	// end preferences sheet
	[self endPreferencesPanel];
}

- (IBAction) compressionLevelSliderAction:(id)sender
{
	// set the compression level from the slider
	compressionLevel = [NSNumber numberWithInt:[sender intValue]];
	[self setCompressionLevel:compressionLevel];
	// set user defaults to this value
	[defaults setObject:compressionLevel forKey:@"compressionLevel"];
}

- (IBAction) volumeFormatButtonAction:(id)sender
{
	volumeFormat = [NSString stringWithString:[sender title]];
	[defaults setObject:volumeFormat forKey:@"volumeFormat"];
}

- (IBAction) logPositionButtonAction:(id)sender
{
	logPosition = [NSNumber numberWithInt:[sender selectedTag]];
	[defaults setObject:logPosition forKey:@"logPosition"];
	[defaults synchronize];
	
	// Clear log position menu selection
	int i = 0;
	while (i < [[logPositionMenu itemArray] count])
	{
		[[[logPositionMenu itemArray] objectAtIndex:i] setState:0];
		i++;
	}
	
	// Set log position menu selection
	[[[logPositionMenu itemArray] objectAtIndex:[[defaults objectForKey:@"logPosition"] intValue]] setState:1];
	
	[self showHideLogAction:self];
	[self showHideLogAction:self];
}

- (IBAction) logPositionMenuAction:(id)sender
{
	//NSLog([sender title]);
	logPosition = [NSNumber numberWithInt:[sender tag]];
	[defaults setObject:logPosition forKey:@"logPosition"];
	[defaults synchronize];
	
	// Clear log position menu selection
	int i = 0;
	while (i < [[[sender menu] itemArray] count])
	{
		[[[[sender menu] itemArray] objectAtIndex:i] setState:0];
		i++;
	}
	
	// Set log position menu selection
	[sender setState:1];
	
	// Set log button selection
	[logPositionButton selectItemWithTag:[sender tag]];
	
	[self showHideLogAction:self];
	[self showHideLogAction:self];
	
}

- (IBAction) imageDropMatrixAction:(id)sender
{
	imageDropAction = [NSNumber numberWithInt:[[sender selectedCell] tag]];
	[defaults setObject:imageDropAction forKey:@"imageDropAction"];
}

- (IBAction) limitSegmentButtonAction:(id)sender
{	
	// save setting to standard user defaults
	if([sender state] == 1)
	{
		limitSegmentSize = TRUE;
		[limitSegmentSizeTextField setEnabled:TRUE];
		[limitSegmentSizeButton setEnabled:TRUE];
	}
	else
	{
		limitSegmentSize = FALSE;
		[limitSegmentSizeTextField setEnabled:FALSE];
		[limitSegmentSizeButton setEnabled:FALSE];
	}
	
	[defaults setBool:limitSegmentSize forKey:@"limitSegmentSize"];
	[defaults synchronize];
}

- (IBAction) limitSegmentSizeButtonAction:(id)sender
{
	limitSegmentSizeByte = [NSString stringWithString:[sender titleOfSelectedItem]];
	
	[defaults setObject:limitSegmentSizeByte forKey:@"limitSegmentSizeByte"];
	[defaults synchronize];
}

- (IBAction) limitSegmentSizeTextFieldAction:(id)sender
{
	segmentSize = [NSNumber numberWithDouble:[sender doubleValue]];
	
	[defaults setObject:segmentSize forKey:@"segmentSize"];
	[defaults synchronize];
}

- (IBAction) scrubButtonAction:(id)sender
{
	
}

#pragma mark Images Menu Actions

- (void)menuNeedsUpdate:(NSMenu *)menu
{	
	//NSLog(@"Menu needs update: %@", [menu description]);
	
	if([[menu title] isEqualToString:NSLocalizedString(@"Create_Volume", @"Create from Volume")] && [[imagesMenu itemWithTitle:NSLocalizedString(@"Create_Volume", @"Create from Volume")] isEnabled]){
		// setup volumes menu - clear entries first
		int i = 0;
		if([[volumesMenu itemArray] count] > 0)
			while(i < [[volumesMenu itemArray] count])
			{
				[volumesMenu removeItemAtIndex:i];
			}
		// add entries to volumes menu
		i = 0;
		//NSMutableArray *volumeList = [NSMutableArray arrayWithArray:[self volumes]];  
		for(i = 0; i < [volumes count]; ++i){
			[volumesMenu addItemWithTitle:[volumes objectAtIndex:i] action:@selector(createFromVolume:) keyEquivalent:@""];
		}
		[volumesMenu setDelegate:self];
		[volumesMenu setAutoenablesItems:TRUE];
		[volumesMenu setTitle:NSLocalizedString(@"Create_Volume", @"Create from Volume")];
		[volumesMenuItem setSubmenu:volumesMenu];
	}
	
	//if([[menu title] isEqualToString:NSLocalizedString(@"Create_Device", @"Create from Device")] && [[imagesMenu itemWithTitle:NSLocalizedString(@"Create_Device", @"Create from Device")] isEnabled]){
//		// setup device menu - clear entries first
//		int i = 0;
//		if([[devicesMenu itemArray] count] > 0)
//			while(i < [[devicesMenu itemArray] count])
//			{
//				[devicesMenu removeItemAtIndex:i];
//			}
//		
//		// add entries to device menu
//		i = 0;
//		//NSMutableArray *devicesList = [NSMutableArray arrayWithArray:[self devices]];  //set to devices or volumes function
//		while(i < [devices count]){
//			[devicesMenu addItemWithTitle:[devices objectAtIndex:i] action:@selector(createFromDevice:) keyEquivalent:@""];
//			i++;
//		}
//		[devicesMenu setDelegate:self];
//		[devicesMenu setAutoenablesItems:TRUE];
//		[volumesMenu setTitle:NSLocalizedString(@"Create_Device", @"Create from Device")];
//		[devicesMenuItem setSubmenu:devicesMenu];
//		
//	}
}

- (IBAction) mount:(id)sender
{
	if(![freeDMGTask isRunning]){
		// choose the source image
		NSOpenPanel *oPanel = [NSOpenPanel openPanel];
		[oPanel setCanChooseDirectories:FALSE];      
		[oPanel setCanChooseFiles:TRUE];
		[oPanel setTitle:NSLocalizedString(@"Mount Image", @"Choose image to mount")];
		
		if ([oPanel runModalForDirectory:nil file:nil types:[NSArray arrayWithObjects:@"dmg", @"iso", @"sparseimage", @"sparsebundle", @"img", @"cdr", nil]] == NSOKButton) {
			[self mountImage:[[oPanel filenames] objectAtIndex:0]];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
		
	}
}

- (IBAction) createFromFolder:(id)sender
{
	if(![freeDMGTask isRunning]){
		// variables
		NSString *sourceFolder = nil, *destinationImage = nil;
		int status = 0;
		
		// choose the source folder
		NSOpenPanel *oPanel = [NSOpenPanel openPanel];
		[oPanel setCanChooseDirectories:TRUE];      
		[oPanel setCanChooseFiles:FALSE];
		[oPanel setTitle:NSLocalizedString(@"SourceFolder", @"Choose source folder")];
		
		if ([oPanel runModal] == NSOKButton) {
			sourceFolder = [[oPanel filenames] objectAtIndex:0];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
			status = 1;
		}
		
		// choose the save destination (and format?)
		if(status == 0){			
			sPanel = [NSSavePanel savePanel];
			[sPanel setAccessoryView:ConvertView];
			[sPanel setTitle:NSLocalizedString(@"SaveAs", @"Save As")];
			
			if ([sPanel runModalForDirectory:[sourceFolder stringByDeletingLastPathComponent] file:[[sourceFolder stringByAppendingPathExtension:[self pathExtension]] lastPathComponent]] == NSOKButton) {
				if([[[sPanel filename] pathExtension] isEqualToString:@"app"] || [[[sPanel filename] pathExtension] isEqualToString:@"nib"] || [[[sPanel filename] pathExtension] isEqualToString:@"pkg"])
					destinationImage = [[sPanel filename] stringByDeletingPathExtension];
				else
					destinationImage = [sPanel filename];
			}
			else
			{
				status = 1;
			}
		}
		
		// image the file
		if((status == 0))
		{
			status = [self createImage:destinationImage fromFolder:sourceFolder];
		}
		else
			status = -1;
	}
	
}

- (IBAction) createFromVolume:(id)sender
{
	if(![freeDMGTask isRunning]){
		// variables
		NSString *sourceVolume = [@"/Volumes/" stringByAppendingString:[sender title]], *destinationImage = nil;
		int status = 0;
		
		// choose the save destination (and format?)
		if(status == 0){			
			sPanel = [NSSavePanel savePanel];
			[sPanel setAccessoryView:ConvertView];
			[sPanel setTitle:NSLocalizedString(@"Save As", @"Save As")];
			
			if ([sPanel runModalForDirectory:nil file:[[sourceVolume stringByAppendingPathExtension:[self pathExtension]] lastPathComponent]] == NSOKButton) {
				destinationImage = [sPanel filename];
			}
			else
			{
				status = 1;
			}
		}
		
		// image the file
		if((status == 0))
		{
			status = [self createImage:destinationImage fromFolder:sourceVolume];
		}
		else
			status = -1;
	}
	
}

- (IBAction) createFromDevice:(id)sender
{	
	if(![freeDMGTask isRunning]){
		// variables
		NSString *sourceDevice = nil, *destinationImage = nil;
		int status = 0;
		
		sourceDevice = [NSString stringWithString:[sender title]];
		if(status == 0){
			//NSSavePanel *
			sPanel = [NSSavePanel savePanel];
			[sPanel setAccessoryView:ConvertView];
			[sPanel setTitle:[NSLocalizedString(@"Imaging", @"Imaging: ") stringByAppendingString:[sender title]]];
			
			if ([sPanel runModalForDirectory:nil file:[sourceDevice stringByAppendingPathExtension:[self pathExtension]]] == NSOKButton) {
				destinationImage = [sPanel filename];
			}
			else
			{
				status = 1;
			}
		}
		
		// image the device
		if((status == 0))
		{
			status = [self createImage:destinationImage fromDevice:sourceDevice];
		}
		else
			status = -1;
	}
	
}

- (IBAction) createBlankImage:(id)sender
{
	if(![freeDMGTask isRunning]){
		// variables
		int status = 0;
		NSString *destinationPath;
		
		// choose the save destination (and format?)		
		sPanel = [NSSavePanel savePanel];
		[sPanel setAccessoryView:NewView];
		[sPanel setTitle:NSLocalizedString(@"SaveAs", @"Save As")];
		
		if ([sPanel runModal] == NSOKButton) {
			destinationPath = [sPanel filename];
		}
		else
		{
			status = 1;
		}
		
		// image the file
		if(status == 0)
		{
			status = [self createImage:destinationPath ofSize:[NSNumber numberWithDouble:[newSizeTextField doubleValue]] withFilesystem:[newFilesystemButton title] volumeName:[newNameTextField stringValue] type:[defaults objectForKey:@"type"]];
			
		}
		else
			status = -1;
	}
	
}

-(IBAction) convertImage:(id)sender
{
	if(![freeDMGTask isRunning]){
		// variables
		NSString *sourceImage = nil, *destinationImage = nil;
		int status = 0;
		
		// open the source disk image
		NSOpenPanel *oPanel = [NSOpenPanel openPanel];
		[oPanel setCanChooseDirectories:FALSE];
		[oPanel setTitle:NSLocalizedString(@"Toolbar_Convert", @"Convert")];
		
		if ([oPanel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			sourceImage = [[oPanel filenames] objectAtIndex:0];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
			status = 1;
		}
		
		// choose the save destination (and format?)
		if(status == 0){
			sPanel = [NSSavePanel savePanel];
			[sPanel setAccessoryView:ConvertView];
			[sPanel setTitle:NSLocalizedString(@"Toolbar_Convert", @"Convert")];
			[sPanel setRequiredFileType:[self convertPathExtension]];
			[sPanel setExtensionHidden:FALSE];
			
			if ([sPanel runModalForDirectory:nil file:[sourceImage lastPathComponent]] == NSOKButton) {
		//		if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_UDRW", @"Read/Write")])
//					format = @"UDRW";
//				else if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_UDRO", @"Read-only")])
//					format = @"UDRO";
//				else if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_UDZO", @"Compressed (zlib)")])
//					format = @"UDZO";
//				else if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_UDBZ", @"Compressed (bzip2)")])
//					format = @"UDBZ";
//				else if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_UDTO", @"DVD/CD-R master")])
//					format = @"UDTO";
//				else if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_Sparse", @"Sparse")])
//					format = @"UDSP";
//				else if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_SparseBundle", @"Sparse bundle")])
//					format = @"UDSB";
//				else if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_RdWr", @"Read/Write (Mac OS 9)")])
//					format = @"RdWr";
//				else if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_Rdxx", @"Read-only (Mac OS 9)")])
//					format = @"Rdxx";
//				else if([[convertFormatButton title] isEqualToString:NSLocalizedString(@"Convert_ROCo", @"Compressed (Mac OS 9)")])
//					format = @"ROCo";
				destinationImage = [sPanel filename];
			}
			else
			{
				status = 1;
			}
		}
		
		// convert the file
		if((status == 0) && !(destinationImage == nil) && !(sourceImage == nil))
		{
			status = [self convertImage:sourceImage format:[self convertFormat] outfile:destinationImage];
		}
		else
			status = -1;
	}
}

-(IBAction) makeInternetEnabled:(id)sender
{
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setTitle:NSLocalizedString(@"InternetEnabled", @"Make Internet Enabled")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg", nil]] == NSOKButton) {
			[self makeInternetEnabledAtPath:[[panel filenames] objectAtIndex:0]];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

-(IBAction) scanForRestore:(id)sender
{
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setTitle:NSLocalizedString(@"ScanRestore", @"Scan for Restore")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			[self scanImageForRestore:[[panel filenames] objectAtIndex:0] blockOnly:FALSE];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

-(IBAction) scanForBlockRestore:(id)sender
{
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setTitle:NSLocalizedString(@"ScanRestore", @"Scan for Block Restore")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			[self scanImageForRestore:[[panel filenames] objectAtIndex:0] blockOnly:TRUE];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

-(IBAction) getInfo:(id)sender
{
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setTitle:NSLocalizedString(@"GetInfo", @"Get Info")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			[self imageInfoAtPath:[[panel filenames] objectAtIndex:0]];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

-(IBAction) compactImage:(id)sender
{	
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setTitle:NSLocalizedString(@"Compact", @"Compact Image")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			[self compactImageAtPath:[[panel filenames] objectAtIndex:0]];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

- (IBAction) verifyImage:(id)sender
{
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setTitle:NSLocalizedString(@"Verify", @"Verify Image")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			[self verifyImageAtPath:[[panel filenames] objectAtIndex:0]];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

- (IBAction) checksumImage:(id)sender
{		
	/* 
	Verify types:
	 
	 UDIF-CRC32 - CRC-32 image checksum
	 UDIF-MD5 - MD5 image checksum
	 DC42 - Disk Copy 4.2
	 CRC28 - CRC-32 (NDIF)
	 CRC32 - CRC-32
	 MD5 - MD5
	 SHA - SHA
	 SHA1 - SHA-1
	 SHA256 - SHA-256
	 SHA384 - SHA-384
	 SHA512 - SHA-512
	 */
	
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setTitle:NSLocalizedString(@"Checksum", @"Checksum Image")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", @"iso", nil]] == NSOKButton) {
			if([[sender title] isEqual:@"CRC-32 image checksum..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"UDIF-CRC32"];
			else if([[sender title] isEqual:@"MD5 image checksum..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"UDIF-MD5"];
			else if([[sender title] isEqual:@"Disk Copy 4.2..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"DC42"];
			else if([[sender title] isEqual:@"CRC-32 (NDIF)..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"CRC28"];
			else if([[sender title] isEqual:@"CRC-32..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"CRC23"];
			else if([[sender title] isEqual:@"MD5..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"MD5"];
			else if([[sender title] isEqual:@"SHA..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"SHA"];
			else if([[sender title] isEqual:@"SHA-1..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"SHA1"];
			else if([[sender title] isEqual:@"SHA-256..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"SHA256"];
			else if([[sender title] isEqual:@"SHA-384..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"SHA384"];
			else if([[sender title] isEqual:@"SHA-512..."])
				[self checksumImageAtPath:[[panel filenames] objectAtIndex:0] type:@"SHA512"];
			
			
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

- (IBAction) changePassword:(id)sender
{
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setExtensionHidden:FALSE];
		[panel setTitle:NSLocalizedString(@"Password", @"Change Password")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			[self changePasswordOfImageAtPath:[[panel filenames] objectAtIndex:0]];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

- (IBAction) burnImage:(id)sender
{
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setExtensionHidden:FALSE];
		[panel setTitle:NSLocalizedString(@"Burn", @"Burn Image")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			[self burnImageAtPath:[[panel filenames] objectAtIndex:0]];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

- (IBAction) segmentImage:(id)sender
{
	if(![freeDMGTask isRunning]){
		// variables
		NSString *sourceImage = nil, *destinationImage = nil, *segmentSizeString = [NSString stringWithString:@"10m"];
		int status = 0;
		
		// open the source disk image
		NSOpenPanel *oPanel = [NSOpenPanel openPanel];
		[oPanel setCanChooseDirectories:FALSE];
		[oPanel setTitle:NSLocalizedString(@"Segment", @"Segment Image:")];
		
		if ([oPanel runModalForTypes:[NSArray arrayWithObjects:@"dmg", @"img", nil]] == NSOKButton) {
			sourceImage = [[oPanel filenames] objectAtIndex:0];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
			status = 1;
		}
		
		// choose the save destination (and format?)
		if(status == 0){
			sPanel = [NSSavePanel savePanel];
			[sPanel setAccessoryView:SegmentView];
			[sPanel setTitle:NSLocalizedString(@"Segment_Save", @"Save Segments:")];
			[sPanel setMessage:NSLocalizedString(@"Segment_Location", @"Select a location, name, and size for the segments created.")];
			[sPanel setRequiredFileType:@"dmg"];
			[sPanel setExtensionHidden:FALSE];
			
			if ([sPanel runModal] == NSOKButton) {
				segmentSizeString = [NSString stringWithString:[segmentSizeButton title]];
				destinationImage = [sPanel filename];
			}
			else
			{
				status = 1;
			}
		}
		
		// segment the file
		if((status == 0) && !(destinationImage == nil) && !(sourceImage == nil))
		{
			status = [self segmentImageAtPath:sourceImage segmentName:destinationImage segmentSize:segmentSizeString];
		}
		else
			status = -1;
	}
}

- (IBAction) addSLAToImage:(id)sender
{		
	if([SLATableView selectedRow] >= 0)
		[self saveSLAStringValue];
	
	int status = 0;
	int SLAcount = [[defaults objectForKey:@"SLAs"] count], i = 0, enabledSLAcount = 0;
	
	// make sure there is at least one enabled SLA
	while(i < SLAcount)
	{
		if([[[[defaults objectForKey:@"SLAs"] objectAtIndex:i] objectForKey:@"enabled"] boolValue] == TRUE)
		{
			enabledSLAcount++;
		}
		i++;
	}
	
	if(enabledSLAcount < 1) status = 2;
	
	if((status == 0) && (SLAcount > 0))
	{
		if(![freeDMGTask isRunning]){
			[imageProgress startAnimation:self];
			// variables
			NSString *sourceImage = nil;
			[logTextView setString:@""];

			// open the source disk image
			NSOpenPanel *oPanel = [NSOpenPanel openPanel];
			[oPanel setCanChooseDirectories:FALSE];
			[oPanel setTitle:NSLocalizedString(@"Toolbar_SLA", @"Add Software License Agreement to Image")];
			
			if ([oPanel runModalForTypes:[NSArray arrayWithObjects:@"dmg", @"img", nil]] == NSOKButton) {
				sourceImage = [[oPanel filenames] objectAtIndex:0];
				[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
				[self endSLAPanel:self];
				status = [self createResourcesForEnabledSLAs];
				//NSLog(@"create status: %i", status);
				if((status == 0) || (status == 1))
				{
					i=0;
					[self FDLog:[@"Unflattening image: " stringByAppendingString:sourceImage]];
					[statusTextField setStringValue:NSLocalizedString(@"Unflattening_Image", @"Unflattening image...")];
					// unflatten image
					status = [[self openProgram:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"unflatten", sourceImage, nil]] intValue];
					if(status == 0){
						status = [self addCarbonResourcesToImage:sourceImage];
						if(status == 0){
							
							while((i < [[defaults objectForKey:@"SLAs"] count]) && (status == 0)){
								if([[[[defaults objectForKey:@"SLAs"] objectAtIndex:i] objectForKey:@"enabled"] boolValue] == TRUE){
									NSString *resources = [[[NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/FreeDMG/SLAs/"] stringByAppendingPathComponent:[[[[defaults objectForKey:@"SLAs"] objectAtIndex:i] objectForKey:@"id"] stringValue]] stringByAppendingPathExtension:@"r"];
									status = [self addResourcesFromSource:resources toImage:sourceImage];
									if(status == 0){
										// resource creation was sucessful for the locale with resource ID (5000 + i)
										[self FDLog:[@"Successfully added SLA with locale ID: " stringByAppendingString:[[[[defaults objectForKey:@"SLAs"] objectAtIndex:i] objectForKey:@"id"] stringValue]]]; 
									}
									else{
										// an error occurred while adding resources
										switch (status){											
											case(6):
												NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_Xcode_Error", @"Developer tools (Xcode) not installed. SLA creation is not possible. To enable this feature, install Apple's Xcode tools from the Mac OS X Install discs or http://developer.apple.com."),@"OK", @"", @"");
												break;
											case(7):
												NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_Folder_Error", @"The folder located at ~/Library/Preferences/FreeDMG/SLAs cannot be found. Please quit and relaunch FreeDMG to re-create this directory"),@"OK", @"", @"");
												break;
											case(8):
												NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_ImageExists_Error", @"The selected image can't be found. Please try again."),@"OK", @"", @"");
												break;
											case(9):
												NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_ImagePath_Error", @"Error: the path to the resources or image is null. Please try again"),@"OK", @"", @"");
												break;
											case(10):
												NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_Unflatten_Error", @"An error occurred while unflattening the disk image. The image may not be a compressed read-only UDIF image. Use the \"Convert\" operation to convert the image to the correct type."),@"OK", @"", @"");
												break;
											case(11):
												NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_ResourceAttach_Error", @"An error occurred while adding the enabled resources to the selected image. Please review the log for more details."),@"OK", @"", @"");
												break;
											case(12):
												NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_Flatten_Error", @"An error occurred while flattening the disk image. Please try again."),@"OK", @"", @"");
										}
									}
								}
								i++;
							}
						}
						else{
							switch(status){
								case(5):
									NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_CarbonResourceAttach_Error", @"An error occurred while adding Carbon resources to the selected image. Please review the log for more details."),@"OK", @"", @"");
									break;
								case(6):
									NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_Xcode_Error", @"Developer tools (Xcode) not installed. SLA creation is not possible. To enable this feature, install Apple's Xcode tools from the Mac OS X Install discs or http://developer.apple.com."),@"OK", @"", @"");
									break;
								default:
									NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_ResourceAttach_Error", @"An error occurred while adding Carbon resources to the selected image. Please review the log for more details."),@"OK", @"", @"");
									break;
							}
						}
					}
					else{
						[self FDLog:[@"An error occurred while unflattening image: " stringByAppendingString:sourceImage]];
						NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_Unflatten_Error", @"An error occurred while unflattening the disk image. The image may not be a compressed read-only UDIF image. Use the \"Convert\" operation to convert the image to the correct type."),@"OK", @"", @"");
					}
					if(status == 0){
						[self FDLog:[@"Flattening image: " stringByAppendingString:sourceImage]];
						[statusTextField setStringValue:NSLocalizedString(@"Flattening_Image", @"Flattening image...")];
						status = [[self openProgram:@"/usr/bin/hdiutil" withArguments:[NSArray arrayWithObjects:@"flatten", sourceImage,nil]] intValue];
						if(status != 0){
							[self FDLog:[@"Error flattening image: " stringByAppendingString:sourceImage]];
							status = 12;
							NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_Flatten_Error", @"An error occurred while flattening the disk image. Please try again."),@"OK", @"", @"");
						}
					}
					
				}
				else
					// an error occure during resource creation
					NSRunAlertPanel(@"FreeDMG",	NSLocalizedString(@"SLA_ResourceCreation_Error", @"An error occurred while creating resources from the enabled software license agreements. Please review the log or Console for more details."),@"OK", @"", @"");
			}
			else
			{
				[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
				status = 3;
			}
			[statusTextField setStringValue:@""];
			[imageProgress stopAnimation:self];
		}
		else{
			status = 1;
		}
	}
	else
	{
		[self beginSLAPanel:self];
		NSRunAlertPanel(NSLocalizedString(@"SLA_NoSLAs_Error", @"There are no Software License agreements enabled."), @"Please use the Software License Agreements Window to add and enable agreements.",@"", @"", @"");
		status = 2;
	}
	return;
}

- (IBAction) addSLA:(id)sender
{
	NSMutableDictionary * newSLAInfo = [NSMutableDictionary dictionaryWithCapacity:5];
	NSMutableArray * allSLAs = [NSMutableArray arrayWithCapacity:1];
	
	if([SLATableView selectedRow] > -1){
		[self saveSLAStringValue];
		[SLATableView deselectRow:[SLATableView selectedRow]];
		[SLATextView setString:@""];
	}
	
	[allSLAs addObjectsFromArray:[defaults objectForKey:@"SLAs"]];
	[newSLAInfo setValue:@"MySLA" forKey:@"name"];
	[newSLAInfo setValue:@"English" forKey:@"language"];
	if([allSLAs count] == 0)
		[newSLAInfo setValue:[NSNumber numberWithBool:TRUE] forKey:@"enabled"];
	[newSLAInfo setValue:[NSNumber numberWithInt:5002] forKey:@"id"];
	[newSLAInfo setValue:[SLATextView RTFFromRange:NSMakeRange(0, [[SLATextView textStorage] length])] forKey:@"string"];
	
	[allSLAs addObject:newSLAInfo];
	[defaults setObject:allSLAs forKey:@"SLAs"];
	[defaults synchronize];
	[SLATableView reloadData];
	if([[defaults objectForKey:@"SLAs"] count] != 0)
		[SLATableView selectRow:[[defaults objectForKey:@"SLAs"] count] byExtendingSelection:FALSE];
}

- (IBAction) removeSLA:(id)sender
{
	if([SLATableView selectedRow] != -1)
	{
		NSMutableArray *temp = [NSMutableArray arrayWithCapacity:1];
		[temp addObjectsFromArray:[defaults objectForKey:@"SLAs"]];
		[temp removeObjectAtIndex:[SLATableView selectedRow]];
		[defaults setObject:temp forKey:@"SLAs"];
		[defaults synchronize];
		[SLATableView reloadData];
		if([SLATableView selectedRow] > 0)
			[SLATextView setString:[[[defaults objectForKey:@"SLAs"] objectAtIndex:[SLATableView selectedRow]] objectForKey:@"string"]];
	}
}

- (IBAction) enableSLA:(id)sender
{
	
}

- (IBAction) languageButtonAction:(id)sender
{
}

- (IBAction) SLAOKButtonAction:(id)sender
{
	[self saveSLAStringValue];
	[self endSLAPanel:self];
}

- (IBAction) flattenImage:(id)sender
{
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setTitle:NSLocalizedString(@"Flatten", @"Flatten Image")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			[self flattenImageAtPath:[[panel filenames] objectAtIndex:0]];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

- (IBAction) unflattenImage:(id)sender
{
	if(![freeDMGTask isRunning]){
		// open the source disk image
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setCanChooseDirectories:FALSE];
		[panel setTitle:NSLocalizedString(@"Flatten", @"Unflatten Image")];
		
		if ([panel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			[self unflattenImageAtPath:[[panel filenames] objectAtIndex:0]];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
		}
	}
}

- (IBAction) makeHybrid:(id)sender
{
	
	if(![freeDMGTask isRunning])
	{
		NSFileManager *fileManager = [NSFileManager defaultManager];
		
		// open the source disk image or folder
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		[openPanel setCanChooseDirectories:TRUE];
		if ([openPanel runModalForDirectory:nil file:nil types:[NSArray arrayWithObjects:@"dmg", @"app", @"pkg", @"mpkg", @"nib", nil]] == NSOKButton) {
			NSString *filename = [openPanel filename];
			if([fileManager fileExistsAtPath:filename])
			{
				NSSavePanel *savePanel = [NSSavePanel savePanel];
				[savePanel setAccessoryView:HybridView];
				[savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"iso", nil]];
				
				if([savePanel runModalForDirectory:nil file:[[openPanel filename] lastPathComponent]] == NSOKButton)
				{
					NSMutableArray* hybridOptions = [[NSMutableArray alloc] init];
					
					[hybridOptions addObject:@"makehybrid"];
					[hybridOptions addObject:@"-o"];
					[hybridOptions addObject:[savePanel filename]];
					
					if(overwrite == TRUE)
						[hybridOptions addObject:@"-ov"];
					
					// add HFS hybrid options
					
					if(![[hybridHFSBlessedDirectoryTextField stringValue] isEqualToString:@""]){
						[hybridOptions addObject:@"-hfs-blessed-directory"];
						[hybridOptions addObject:[hybridHFSBlessedDirectoryTextField stringValue]];
					}
					
					if(![[hybridHFSOpenFolderTextField stringValue] isEqualToString:@""])
					{
						[hybridOptions addObject:@"-hfs-openfolder"];
						[hybridOptions addObject:[hybridHFSOpenFolderTextField stringValue]];
					}
					
					if(![[hybridHFSStartupFileSizeTextField stringValue] isEqualToString:@""])
					{
						[hybridOptions addObject:@"-hfs-startupfile-size"];
						[hybridOptions addObject:[hybridHFSStartupFileSizeTextField stringValue]];
					}
					
					if(![[hybridHFSVolumeNameTextField stringValue] isEqualToString:@""])
					{
						[hybridOptions addObject:@"-hfs-volume-name"];
						[hybridOptions addObject:[hybridHFSVolumeNameTextField stringValue]];
					}
					
					//	[hybridOptions addObject:@"hide-hfs"];
					//	[hybridOptions addObject:@"hide-hfs"];
					
					// add ISO/Joliet options
					//					[hybridOptions addObject:@"abstract-file"];
					if(![[hybridISOAbstractFileTextField stringValue] isEqualToString:@""]){
						[hybridOptions addObject:@"-abstract-file"];
						[hybridOptions addObject:[hybridISOAbstractFileTextField stringValue]];
					}
					//	[hybridOptions addObject:@"bibliography-file"];
					if(![[hybridISOBibliographyFileTextField stringValue] isEqualToString:@""]){
						[hybridOptions addObject:@"-bibliography-file"];
						[hybridOptions addObject:[hybridISOBibliographyFileTextField stringValue]];
					}
					//					[hybridOptions addObject:@"copyright-file"];
					if(![[hybridISOCopyrightFileTextField stringValue] isEqualToString:@""]){
						[hybridOptions addObject:@"-copyright-file"];
						[hybridOptions addObject:[hybridISOCopyrightFileTextField stringValue]];
					}
					//					[hybridOptions addObject:@"iso-volume-name"];
					if(![[hybridISOVolumeNameTextField stringValue] isEqualToString:@""]){
						[hybridOptions addObject:@"-iso-volume-name"];
						[hybridOptions addObject:[hybridISOVolumeNameTextField stringValue]];
					}
					//					[hybridOptions addObject:@"joliet-volume-name"];
					if(![[hybridISOVolumeNameTextField stringValue] isEqualToString:@""]){
						[hybridOptions addObject:@"-joliet-volume-name"];
						[hybridOptions addObject:[hybridISOVolumeNameTextField stringValue]];
					}
					//					[hybridOptions addObject:@"keep-mac-specific"];
					if(![[hybridISOAbstractFileTextField stringValue] isEqualToString:@""]){
						[hybridOptions addObject:@"-abstract-file"];
						[hybridOptions addObject:[hybridISOAbstractFileTextField stringValue]];
					}
					//					[hybridOptions addObject:@"hide-iso"];
					//					[hybridOptions addObject:@"hide-joliet"];
					//					[hybridOptions addObject:@"only-iso"];
					//					[hybridOptions addObject:@"only-joliet"];
					
					//					[hybridOptions addObject:@"application"];
					//					[hybridOptions addObject:@"preparer"];
					//					[hybridOptions addObject:@"publisher"];
					//					[hybridOptions addObject:@"system-id"];
					//					[hybridOptions addObject:@"eltorito-boot"];
					//					[hybridOptions addObject:@"hard-disk-boot "];
					//					[hybridOptions addObject:@"no-emul-boot"];
					//					[hybridOptions addObject:@"no-boot"];
					//					[hybridOptions addObject:@"boot-load-seg"];
					//					[hybridOptions addObject:@"boot-load-size"];
					//					[hybridOptions addObject:@"eltorito-platform"];
					//					[hybridOptions addObject:@"eltorito-specification"];
					
					// add UDF options
					//					[hybridOptions addObject:@"udf-version"];
					if([[hybridUDFVersionMatrix selectedCell] tag] == 0){
						[hybridOptions addObject:@"-udf-version"];
						[hybridOptions addObject:@"1.02"];
					}
					//					[hybridOptions addObject:@"udf-volume-name"];
					if(![[hybridUDFVolumeNameTextField stringValue] isEqualToString:@""]){
						[hybridOptions addObject:@"-udf-volume-name"];
						[hybridOptions addObject:[hybridUDFVolumeNameTextField stringValue]];
					}
					//					[hybridOptions addObject:@"hide-udf"];
					//					[hybridOptions addObject:@"only-udf "];
					
					// add "Other" options
					//					[hybridOptions addObject:@"default-volume-name"];
					if(![[hybridVolumeNameTextField stringValue] isEqualToString:@""]){
						[hybridOptions addObject:@"-default-volume-name"];
						[hybridOptions addObject:[hybridVolumeNameTextField stringValue]];
					}
					//					[hybridOptions addObject:@"hide-all"];
					
					
					[hybridOptions addObject:filename];
					
					[self openTask:@"/usr/bin/hdiutil" withArguments:hybridOptions];
					[hybridOptions release];
				}
			}
		}
	}
}

#pragma mark Other IBActions

- (IBAction) convertFormatButtonAction:(id)sender
{	
	if([[sender title] isEqual:NSLocalizedString(@"Convert_UDRW", @"Read/Write")])
		convertFormat = @"UDRW";
	else if([[sender title] isEqual:NSLocalizedString(@"Convert_UDRO", @"Read-only")])
		convertFormat = @"UDRO";
	else if([[sender title] isEqual:NSLocalizedString(@"Convert_UDZO", @"Compressed (zlib)")])
		convertFormat = @"UDZO";
	else if([[sender title] isEqual:NSLocalizedString(@"Convert_UDBZ", @"Compressed (bzip2)")])
		convertFormat = @"UDBZ";
	else if([[sender title] isEqual:NSLocalizedString(@"Convert_UDTO", @"DVD/CD-R master")])
		convertFormat = @"UDTO";
	else if([[sender title] isEqual:NSLocalizedString(@"Convert_UDSP", @"Sparse")])
		convertFormat = @"UDSP";
	else if([[sender title] isEqual:NSLocalizedString(@"Convert_UDSB", @"Sparse bundle")])
		convertFormat = @"UDSB";
	else if([[sender title] isEqual:NSLocalizedString(@"Convert_RdWr", @"Read/Write (Mac OS 9)")])
		convertFormat = @"RdWr";
	else if([[sender title] isEqual:NSLocalizedString(@"Convert_Rdxx", @"Read-only (Mac OS 9)")])
		convertFormat = @"Rdxx";
	else if([[sender title] isEqual:NSLocalizedString(@"Convert_Rdxx", @"Compressed (Mac OS 9)")])
		convertFormat = @"ROCo";
	
	[defaults setObject:convertFormat forKey:@"convertFormat"];
	[defaults synchronize];
	
	// set save panel default filename extension
	if(sPanel != nil)
	{
		[sPanel setRequiredFileType:[self convertPathExtension]];
		[sPanel validateVisibleColumns];
	}
	
}

- (IBAction) convertEncryptionButtonAction:(id)sender
{
	if([[sender title] isEqual:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")])
	{
		encryption = TRUE;
		[defaults setBool:encryption forKey:@"encryption"];
		encryptionType = [NSString stringWithString:@"AES-128"];
		[defaults setObject:encryptionType forKey:@"encryptionType"];
		[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		[accPasswordButton setState:encryption];
		
	}
	else if([[sender title] isEqual:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")])
	{
		encryption = TRUE;
		[defaults setBool:encryption forKey:@"encryption"];
		encryptionType = [NSString stringWithString:@"AES-256"];
		[defaults setObject:encryptionType forKey:@"encryptionType"];
		[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		[accPasswordButton setState:encryption];
		
	}
	else{
		encryption = FALSE;
		[defaults setBool:encryption forKey:@"encryption"];
		[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];
		[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];
		[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];		
		[accPasswordButton setState:encryption];
	}
	[defaults synchronize];
}

- (IBAction) resizeImage:(id)sender
{
	if(![freeDMGTask isRunning]){
		
		// variables
		NSString *sourceImage = nil;
		NSNumber *currentSize = nil, *maxSize = nil, *minSize = nil, *projectedSize = nil;
		int status = 0;
		NSArray * sizeArray;
		
		// open the source disk image
		NSOpenPanel *oPanel = [NSOpenPanel openPanel];
		[oPanel setCanChooseDirectories:FALSE];
		[oPanel setTitle:NSLocalizedString(@"Resize", @"Resize Image:")];
		
		if ([oPanel runModalForTypes:[NSArray arrayWithObjects:@"dmg",@"cdr", @"img",@"sparseimage", @"sparsebundle", nil]] == NSOKButton) {
			sourceImage = [[oPanel filenames] objectAtIndex:0];
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
		}
		else
		{
			[NSApp replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
			status = 1;
		}
		
		// resize the file
		if((status == 0) && !(sourceImage == nil))
		{
			sizeArray = [self resizeLimitsForImage:sourceImage];
			if([sizeArray count] == 3)
			{
				// correct return values.
				currentSize = [NSNumber numberWithDouble:[self MBFromSectors:[[sizeArray objectAtIndex:0] doubleValue]]];
				minSize = [NSNumber numberWithDouble:[self MBFromSectors:[[sizeArray objectAtIndex:1] doubleValue]]];
				maxSize = [NSNumber numberWithDouble:[self MBFromSectors:[[sizeArray objectAtIndex:2] doubleValue]]];
				projectedSize = [NSNumber numberWithDouble:[currentSize doubleValue]];
			}
			else if([sizeArray count] == 1)
			{
				// error return value
				status = [[sizeArray objectAtIndex:1] intValue];
			}
			else
				// internal error
				status = -1;
			
			if(status == 0)
			{
				// choose the size (and save destination?)
				if(status == 0){
					
					[resizeImageTextField setStringValue:sourceImage];
					[resizeMinTextField setStringValue:[minSize stringValue]];
					[resizeCurrentTextField setStringValue:[currentSize stringValue]];
					[resizeMaxTextField setStringValue:[maxSize stringValue]];
					[resizeProjectedTextField setStringValue:[projectedSize stringValue]];
					
					[resizeStepper setMinValue:[minSize doubleValue]];
					[resizeStepper setMaxValue:[maxSize doubleValue]];
					[resizeStepper setDoubleValue:[projectedSize doubleValue]];
					
					[resizeSlider setMinValue:[minSize doubleValue]];
					[resizeSlider setMaxValue:[maxSize doubleValue]];
					[resizeSlider setDoubleValue:[projectedSize doubleValue]];
					
					[NSApp beginSheet:resizePanel modalForWindow:[NSApp mainWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
					
				}
			}
		}
		else
			status = -1;
	}
	
}

- (IBAction) resizeProjectedTextFieldAction:(id)sender
{
	[resizeSlider setDoubleValue:[sender doubleValue]];
	if([sender doubleValue] == [resizeMinTextField doubleValue])
		[resizeMinButton setState:1];
	else
		[resizeMinButton setState:0];
}

- (IBAction) resizeStepperAction:(id)sender
{
	[resizeProjectedTextField setStringValue:[[NSNumber numberWithDouble:[sender doubleValue]] stringValue]];
	[resizeSlider setDoubleValue:[sender doubleValue]];
}

- (IBAction) resizeSliderAction:(id)sender
{
	[resizeProjectedTextField setStringValue:[[NSNumber numberWithDouble:[sender doubleValue]] stringValue]];
	if([resizeMinButton state] == 1)
	{
		if([resizeMinTextField doubleValue] != [resizeSlider doubleValue])
			[resizeMinButton setState:0];
		else
			[resizeMinButton setState:1];
	}
}

- (IBAction) resizeOKButtonAction:(id)sender
{
	[resizePanel orderOut:self];
    [NSApp endSheet:resizePanel];
	[resizeMinButton setState:0];
	[resizeProjectedTextField setEnabled:TRUE];
	[self resizeImageAtPath:[resizeImageTextField stringValue] size:[NSNumber numberWithDouble:[resizeProjectedTextField doubleValue]]];
}

- (IBAction) resizeCancelButtonAction:(id)sender
{
	[resizePanel orderOut:self];
	[NSApp endSheet:resizePanel];
}


- (IBAction) resizeMinButtonAction:(id)sender
{
	if([sender state] == 1)
	{
		[resizeProjectedTextField setStringValue:[resizeMinTextField stringValue]];
		[resizeStepper setDoubleValue:[resizeMinTextField doubleValue]];
		[resizeProjectedTextField setEnabled:FALSE];
		[resizeSlider setDoubleValue:[resizeProjectedTextField doubleValue]];
	}
	else
	{
		[resizeProjectedTextField setEnabled:TRUE];
	}
}

- (IBAction) newNameTextFieldAction:(id)sender
{}

- (IBAction) newSizeTextFieldAction:(id)sender
{}

- (IBAction) newFilesystemButtonAction:(id)sender
{}

- (IBAction) newEncryptionButtonAction:(id)sender
{
	if([[sender title] isEqual:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")])
	{
		encryption = TRUE;
		[defaults setBool:encryption forKey:@"encryption"];
		encryptionType = [NSString stringWithString:@"AES-128"];
		[defaults setObject:encryptionType forKey:@"encryptionType"];
		[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-128", @"AES cipher (128 bit)")];
		[accPasswordButton setState:encryption];
		
	}
	else if([[sender title] isEqual:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")])
	{
		encryption = TRUE;
		[defaults setBool:encryption forKey:@"encryption"];
		encryptionType = [NSString stringWithString:@"AES-256"];
		[defaults setObject:encryptionType forKey:@"encryptionType"];
		[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES-256", @"AES cipher (256 bit)")];
		[accPasswordButton setState:encryption];
		
	}
	else{
		encryption = FALSE;
		[defaults setBool:encryption forKey:@"encryption"];
		[encryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];
		[convertEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];
		[newEncryptionButton selectItemWithTitle:NSLocalizedString(@"AES_None", @"None")];		
		[accPasswordButton setState:encryption];
	}
	[defaults synchronize];
}

- (IBAction) newTypeButtonAction:(id)sender
{
	if([[sender title] isEqual:NSLocalizedString(@"New_Read_Write", @"read/write disk image")])
	{
		[defaults setObject:@"UDIF" forKey:@"type"];
	}
	else if([[sender title] isEqual:NSLocalizedString(@"New_Sparse", @"sparseimage")]){
		[defaults setObject:@"SPARSE" forKey:@"type"];
	}
	else if([[sender title] isEqual:NSLocalizedString(@"New_Sparsebundle", @"sparsebundle")]){
		[defaults setObject:@"SPARSEBUNDLE" forKey:@"type"];
	}
	[defaults synchronize];
}


- (IBAction)showHideLogAction:(id)sender
{
	// dertermine which edge to display log drawer on
	switch([logPositionButton selectedTag]){
			
		case 0:
			[AccessoryDrawer setPreferredEdge:NSMaxXEdge];
			break;
		case 1:
			[AccessoryDrawer setPreferredEdge:NSMinYEdge];
			break;
		case 2:
			[AccessoryDrawer setPreferredEdge:NSMinXEdge];
			break;
		case 3:
			[AccessoryDrawer setPreferredEdge:NSMaxYEdge];
			break;
		default:
			[AccessoryDrawer setPreferredEdge:NSMaxXEdge];
			break;
	};
			
	//if([logPositionButton selectedTag] == 1)
//		[AccessoryDrawer setPreferredEdge:NSMinYEdge];
//	
//	else if([[logPositionButton title] isEqualToString:NSLocalizedString(@"Left", @"NSMinXEdge")])
//		[AccessoryDrawer setPreferredEdge:NSMinXEdge];
//	
//	else if([[logPositionButton title] isEqualToString:NSLocalizedString(@"Top", @"NSMaxYEdge")])
//		[AccessoryDrawer setPreferredEdge:NSMaxYEdge];
//	
//	else
//		[AccessoryDrawer setPreferredEdge:NSMaxXEdge];
	
	// determine if the drawer is closed, or open
	if([AccessoryDrawer state] == NSDrawerOpenState)
		// if the drawer is open, close it.
		[AccessoryDrawer close];
	else
	{
		// if the drawer is closed, open it.
		if([logPositionButton selectedTag] == 1)
			[AccessoryDrawer openOnEdge:NSMinYEdge];
		
		else if([logPositionButton selectedTag] == 2)
			[AccessoryDrawer openOnEdge:NSMinXEdge];
		
		else if([logPositionButton selectedTag] == 3)
			[AccessoryDrawer openOnEdge:NSMaxYEdge];
		
		else
			[AccessoryDrawer openOnEdge:NSMaxXEdge];

	}
}

#pragma mark TableView controls

-(int)numberOfRowsInTableView:(NSTableView *)aTableView
{	
	if([defaults objectForKey:@"SLAs"] != nil)
	{
		return [[defaults objectForKey:@"SLAs"] count];
	}
	else
		return 0;
}

// Stop the table's rows from being editable when we double-click on them
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row
{  
	if([[tableColumn identifier] isEqual:@"name"] || [[tableColumn identifier] isEqual:@"enabled"] || [[tableColumn identifier] isEqual:@"language"])
	{
		return TRUE;
	}
	
    return FALSE;
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
    NSObject  *object = [[defaults objectForKey:@"SLAs"] objectAtIndex:rowIndex];
	return [object valueForKey:[aTableColumn identifier]];
}

- (void)tableView:(NSTableView *)aTableView	setObjectValue:anObject
   forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if([[aTableColumn identifier] isEqual:@"enabled"])
	{
		NSMutableArray *SLAs = [NSMutableArray arrayWithCapacity:1];
		[SLAs addObjectsFromArray:[defaults objectForKey:@"SLAs"]];
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:1];
		[info addEntriesFromDictionary:[SLAs objectAtIndex:rowIndex]];
		NSMutableDictionary *temp = [NSMutableDictionary dictionaryWithCapacity:1];
		int i = 0;
		while(i < [SLAs count])
		{
			if([[[SLAs objectAtIndex:i] objectForKey:@"enabled"] isEqual:[NSNumber numberWithBool:TRUE]] && [[[SLAs objectAtIndex:i] objectForKey:@"id"] isEqual:[NSNumber numberWithInt:[[info objectForKey:@"id"] intValue]]] && (i != rowIndex))
			{
				//NSLog(@"Found duplicate license agreement");
				// disable other license agreements with the same id (language)
				[temp removeAllObjects];
				[temp addEntriesFromDictionary:[SLAs objectAtIndex:i]];
				[temp setObject:[NSNumber numberWithBool:FALSE] forKey:@"enabled"];
				[SLAs replaceObjectAtIndex:i withObject:temp];
				[defaults setObject:SLAs forKey:@"SLAs"];
				[defaults synchronize];
			}	
			i++;
		}
		[info setObject:anObject forKey:@"enabled"];
		[SLAs replaceObjectAtIndex:rowIndex withObject:info];
		[defaults setObject:SLAs forKey:@"SLAs"];
		[defaults synchronize];
		[SLATableView reloadData];
		
	}
	if([[aTableColumn identifier] isEqual:@"name"])
	{
		NSMutableArray *SLAs = [NSMutableArray arrayWithCapacity:1];
		[SLAs addObjectsFromArray:[defaults objectForKey:@"SLAs"]];
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:1];
		[info addEntriesFromDictionary:[SLAs objectAtIndex:rowIndex]];
		[info setObject:anObject forKey:@"name"];
		[SLAs replaceObjectAtIndex:rowIndex withObject:info];
		[defaults setObject:SLAs forKey:@"SLAs"];
		[defaults synchronize];
		[SLATableView reloadData];
		
	}
	if([[aTableColumn identifier] isEqual:@"language"])
	{
		NSMutableArray *SLAs = [NSMutableArray arrayWithCapacity:1];
		[SLAs addObjectsFromArray:[defaults objectForKey:@"SLAs"]];
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:1];
		[info addEntriesFromDictionary:[SLAs objectAtIndex:rowIndex]];
		[info setObject:anObject forKey:@"language"];
		if([anObject isEqual:@"German"])
		{
			[info setObject:[NSNumber numberWithInt:5001] forKey:@"id"];
		}
		else if([anObject isEqual:@"English"])
		{
			[info setObject:[NSNumber numberWithInt:5002] forKey:@"id"];
		}
		else if([anObject isEqual:@"Spanish"])
		{
			[info setObject:[NSNumber numberWithInt:5003] forKey:@"id"];
		}
		else if([anObject isEqual:@"French"])
		{
			[info setObject:[NSNumber numberWithInt:5004] forKey:@"id"];
		}
		else if([anObject isEqual:@"Italian"])
		{
			[info setObject:[NSNumber numberWithInt:5005] forKey:@"id"];
		}
		else if([anObject isEqual:@"Japanese"])
		{
			[info setObject:[NSNumber numberWithInt:5006] forKey:@"id"];
		}
		else if([anObject isEqual:@"Dutch"])
		{
			[info setObject:[NSNumber numberWithInt:5007] forKey:@"id"];
		}
		else if([anObject isEqual:@"Swedish"])
		{
			[info setObject:[NSNumber numberWithInt:5008] forKey:@"id"];
		}
		else if([anObject isEqual:@"Brazilian Portugese"])
		{
			[info setObject:[NSNumber numberWithInt:5009] forKey:@"id"];
		}
		else if([anObject isEqual:@"Simplified Chinese"])
		{
			[info setObject:[NSNumber numberWithInt:5010] forKey:@"id"];
		}
		else if([anObject isEqual:@"Traditional Chinese"])
		{
			[info setObject:[NSNumber numberWithInt:5011] forKey:@"id"];
		}
		else if([anObject isEqual:@"Danish"])
		{
			[info setObject:[NSNumber numberWithInt:5012] forKey:@"id"];
		}
		else if([anObject isEqual:@"Finnish"])
		{
			[info setObject:[NSNumber numberWithInt:5013] forKey:@"id"];
		}
		else if([anObject isEqual:@"French Canadian"])
		{
			[info setObject:[NSNumber numberWithInt:5014] forKey:@"id"];
		}
		else if([anObject isEqual:@"Korean"])
		{
			[info setObject:[NSNumber numberWithInt:5015] forKey:@"id"];
		}
		else if([anObject isEqual:@"Norwegian"])
		{
			[info setObject:[NSNumber numberWithInt:5016] forKey:@"id"];
		}
		[SLAs replaceObjectAtIndex:rowIndex withObject:info];
		int i = 0;
		while(i < [SLAs count])
		{
			if([[[SLAs objectAtIndex:i] objectForKey:@"enabled"] isEqual:[NSNumber numberWithBool:TRUE]] && [[[SLAs objectAtIndex:i] objectForKey:@"id"] isEqual:[NSNumber numberWithInt:[[info objectForKey:@"id"] intValue]]] && (i != rowIndex) && [[info objectForKey:@"enabled"] isEqual:[NSNumber numberWithBool:TRUE]])
			{
				//NSLog(@"Found duplicate license agreement");
				// disable other license agreements with the same id (language)
				NSMutableDictionary *temp = [NSMutableDictionary dictionaryWithCapacity:1];
				[temp addEntriesFromDictionary:[SLAs objectAtIndex:i]];
				[temp setObject:[NSNumber numberWithBool:FALSE] forKey:@"enabled"];
				[SLAs replaceObjectAtIndex:i withObject:temp];
				[defaults setObject:SLAs forKey:@"SLAs"];
				[defaults synchronize];
			}	
			i++;
		}
		[defaults setObject:SLAs forKey:@"SLAs"];
		[defaults synchronize];
		[SLATableView reloadData];
		
	}
	
    return;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[SLATextView setString:@""];
 	if([SLATableView selectedRow] != -1)
	{		
		[SLATextView setEditable:TRUE];
		if([[[[defaults objectForKey:@"SLAs"] objectAtIndex:[SLATableView selectedRow]] objectForKey:@"string"] respondsToSelector:@selector(getCharacters:)])
			[[SLATextView textStorage] setAttributedString:[[[NSAttributedString alloc] initWithString:[[[defaults objectForKey:@"SLAs"] objectAtIndex:[SLATableView selectedRow]] objectForKey:@"string"]] autorelease]];
		else
			[[SLATextView textStorage] setAttributedString:[[[NSAttributedString alloc] initWithData:[[[defaults objectForKey:@"SLAs"] objectAtIndex:[SLATableView selectedRow]] objectForKey:@"string"] options:nil documentAttributes:nil error:nil] autorelease]];

	}
	else{
		[SLATextView setString:@""];
		// possibly set text view to disabled here to prevent loss of pasted data
		[SLATextView setEditable:FALSE];
	}
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
	
}

#pragma mark ComboBoxCell

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(int)index
{
	NSObject *object;
	
	object = [languages objectAtIndex:index];
	return object;
}

- (int)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell 
{
	return [languages count];
}

- (unsigned int)comboBoxCell:(NSComboBoxCell *)aComboBoxCell 
  indexOfItemWithStringValue:(NSString *)aString 
{
	return [languages indexOfObject:aString];
}

#pragma mark Task Control

// openTask command used with task wrapper
-(NSString*)openProgram:(NSString*)programPath withArguments:(NSArray*) arguments
{
	int terminationStatus = 1;
	
	// Allocate the task to execute and the pipe to send the output to
	NSTask  *theTask = [[NSTask alloc] init];
	NSPipe  *thePipe = [[NSPipe alloc] init];
	NSString *theString;
	// Get the file handle from the pipe (assumes thePipe was allocated!)
	//NSFileHandle 	*theFileHandle = [thePipe fileHandleForReading];
	
	if (theTask && thePipe){
		// Tell the task what command (program) to execute
		[theTask setLaunchPath:programPath];
		
		// Pass some arguments to the program
		[theTask setArguments:arguments];
		
		// Set thePipe as the standard output so we can see the results
		[theTask setStandardOutput:thePipe];
		
		//if(verbose)
		//	NSLog(@"Executing %@ with arguments: %@", programPath, [arguments description]);
		
		// Launch the task
		[theTask launch];
		
		// Wait until the task exits
		[theTask waitUntilExit];
		
		terminationStatus = [theTask terminationStatus];	
		
		// Verify that the program completed without error
		if (terminationStatus == 0) {
			
			theString = [[NSString alloc] initWithData:[[thePipe fileHandleForReading] readDataToEndOfFile] 
											  encoding:NSUTF8StringEncoding];
			if(theString == nil)
				theString = [[NSString alloc] initWithString:[[NSNumber numberWithInt:terminationStatus] stringValue]];
			
			[thePipe release];
			[theTask release];
			
		} 
		// if an error occured, return the error code.
		else{
			theString = [[NSString alloc] initWithString:[[NSNumber numberWithInt:terminationStatus] stringValue]];
			
			[thePipe release];
			[theTask release];
		}
		
	}
	else {
		// If there was an errthePipeor, tell the user
		terminationStatus = -1;
		theString = [[NSString alloc] initWithString:[[NSNumber numberWithInt:terminationStatus] stringValue]];
		if (thePipe) { [thePipe release]; thePipe = nil; }
		if (theTask) { [theTask release]; theTask = nil; }
		printf([NSLocalizedString(@"Task_Warning", @"An error occurred trying to allocate the task or pipe.") UTF8String]);
	}
	return [theString autorelease];
}

-(int) openTask:(NSString*)path withArguments:(NSArray*)arguments
{
	int processID = 0;
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:1];
	[args addObject:path];
	[args addObjectsFromArray:arguments];
	
	//NSLog(@"Opening %@ with arguments: %@", path, [arguments description]);
	
	if (freeDMGTask!=nil){
		[freeDMGTask release];
	}
	
	// Let's allocate memory for and initialize a new TaskWrapper object, passing
	// in ourselves as the controller for this TaskWrapper object, the path
	// to the command-line tool, and the contents of the text field that 
	// displays what the user wants to search on
	freeDMGTask=[[FDTaskWrapper alloc] initWithController:self arguments:args];
	// kick off the process asynchronously
	[freeDMGTask startProcess];
	processID = [freeDMGTask processID];
	return processID;
}

// This callback is implemented as part of conforming to the ProcessController protocol.
// It will be called whenever there is output from the TaskWrapper.
- (void)appendOutput:(NSString *)output
{
	if(output != nil){
		BOOL display = TRUE;
		NSString *displayString = [NSString stringWithString:output];
		
		NSArray * temp = [output componentsSeparatedByString:@"]"];
		NSScanner * outputScanner;
		int i = 0, stringCount = [progressStrings count];

		if([temp count] > 1) 
			outputScanner = [NSScanner scannerWithString:[temp objectAtIndex:1]];
		else
			outputScanner = [NSScanner scannerWithString:output];
		
		// try to read the input to determine which step of the process we are in.
		while (i < stringCount)
		{
			if([outputScanner scanString:[progressStrings objectAtIndex:i] intoString:nil])
			{
				[statusTextField setStringValue:[progressStrings objectAtIndex:i]];
				i = stringCount;
				displayString = [NSString stringWithString:output];
				display = TRUE;
			}
			else{
				i++;
			}
		}
		
		// scan for status info
		if([outputScanner scanString:@"PERCENT:" intoString:nil])
		{
			double percent = [[[output componentsSeparatedByString:@"PERCENT:"] objectAtIndex:1] doubleValue];
			if(percent > 0)
			{
				[imageProgress setIndeterminate:FALSE];
				[imageProgress setMinValue:0];
				[imageProgress setMaxValue:100];
				[imageProgress setDoubleValue:percent];
			}
			else
			{
				[imageProgress setIndeterminate:TRUE];
				if([freeDMGTask isRunning])
					[imageProgress startAnimation:self];
				else
					[imageProgress stopAnimation:self];
			}
			display = FALSE;
		}
		// display burn messages on statusfield
		else if([outputScanner scanString:@"MESSAGE:" intoString:nil])
		{
			[statusTextField setStringValue:[[output componentsSeparatedByString:@"MESSAGE:"] objectAtIndex:1]];
			displayString = [NSString stringWithString:[[output componentsSeparatedByString:@"MESSAGE:"] objectAtIndex:1]];
			display = TRUE;
		}
		
		if(display == TRUE){
			// add the string to the NSTextView's
			// backing store, in the form of an attributed string
			if(displayString != nil)
				[[logTextView textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:displayString] autorelease]];
		}
		  
		[logTextView scrollRangeToVisible:NSMakeRange([[logTextView string] length], 0)];
	}
}

// A callback that gets called when a TaskWrapper is launched, allowing us to do any setup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processStarted
{
    freeDMGRunning=YES;
	[imageProgress setUsesThreadedAnimation:TRUE];
	[imageProgress startAnimation:self];
	[statusTextField setStringValue:NSLocalizedString(@"Imaging", @"Imaging...")];
	
    // clear the logfile results
    [logTextView setString:@""];
}

// A callback that gets called when a TaskWrapper is completed, allowing us to do any cleanup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processFinished
{
	if(![freeDMGTask isRunning])
	{
		freeDMGRunning = NO;
		burnRunning = NO;
		gotMedia = NO;
		
		if(([freeDMGTask terminationStatus] != 0)  && ([freeDMGTask terminationStatus] != 15)){
			NSLog(@"Error: %i", [freeDMGTask terminationStatus]);
			NSRunAlertPanel(@"FreeDMG",NSLocalizedString(@"Error_Warning", @"An error occurred - see log for more details"),NSLocalizedString(@"OK", @"OK"),@"",@"");
			[statusTextField setStringValue:NSLocalizedString(@"Error", @"Error")];
		}
		else
			[statusTextField setStringValue:NSLocalizedString(@"Finished", @"Finished")];
		
		// set the progress indicator back to an indeterminate one
		[imageProgress setIndeterminate:TRUE];
		[imageProgress stopAnimation:self];
	}
	else
		NSRunAlertPanel(@"FreeDMG",NSLocalizedString(@"Internal_Warning", @"An internal error occurred - see log for more details"),NSLocalizedString(@"OK", @"OK"),@"",@"");
	
	if(quit && doQuit && hasQuit && ![freeDMGTask isRunning] && (([freeDMGTask terminationStatus] == 0) || ([freeDMGTask terminationStatus] == 15)))
		[NSApp terminate:self];
}


@end
