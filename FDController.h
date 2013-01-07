/*
	File: FDController.h
 
	Written by: eK
 
	The FDController contains the functions used by the FreeDMG program
 
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
 
 8/20/2009 v.0.5.9b		dev change
 ¥ Checks for empty volume/device array before updating menus in "-menuNeedsUpdate" method (was crashing on launch when run on 10.4/10.6 machines)
 ¥ Removed "Create from Device" option under Images menu (was causing crashing in 10.6)
 
 10/12/2008	v.0.5.8b	dev change
 ¥ Uses new version of mkdmg, which uses getopts and checks for missing source files
 ¥ Added Russian localization
 ¥ Added German localization
 
	6/4/2008	v.0.5.7b	dev change
 ¥ Uses new version of rtf2r (1.3), which corrects endianess issues with styl resources
 ¥ Uses new toolbar and application icons
 
	1/26/2008	v.0.5.6d3	dev change
 ¥ Uses new "rtf2r" tool to create resource fork source code for SLAs
 
	1/13/2008	v.0.5.6d2	dev change
 ¥ Added slider to resize window for more visual resize approach
 ¥ Created separate preferences for convert format (vs. create)
 
	12/7/2007	v.0.5.6d1	dev change
 ¥ Added support for sparsebundle type images (10.5 only)
 ¥ Uses mkdmg v.0.1.6.6b (which also supports sparsebundles)
 ¥ Added support for 256-bit encryption
 
	1/18/2007	v. 0.5.5d4	dev change
 ¥ Added the ability to attach sofware license agreements to disk images
 ¥ Renamed all custom FreeDMG classes to have synonymous "FD" prefix
 
	10/22/2006	v. 0.5.5d3	dev change
 ¥ Localized programatically and created Localizable.strings file
 
	10/8/2006	v. 0.5.5d2	dev change
 ¥ added new checksum types: 
 
	 DC42 - Disk Copy 4.2
	 CRC28 - CRC-32 (NDIF)
	 CRC32 - CRC-32
	 MD5 - MD5
	 SHA - SHA
	 SHA1 - SHA-1
	 SHA256 - SHA-256
	 SHA384 - SHA-384
	 SHA512 - SHA-512
 
	10/1/2006	v. 0.5.5d1	dev change
 ¥ Added "Log Position" menu item to "View" menu
 ¥ Added glossary to help files
 ¥ Added "Make Hybrid" option to images menu - iso image creation is now possible
 ¥ Changed "isTiger" function to "isPanther" for forward compatibility
 ¥ Now accepts dropped "iso" type images as disk images
 
	4/8/2006	v.0.5.4b	beta version change
 ¥ Universal binary
 ¥ New icon
 ¥ Bug fixes
 
	1/29/2006	v.0.5.4d4	dev change
 ¥ Added Toolbar with customizable items:
 - Create image (new)
 - Convert image
 - Verify image
 - Inspect image (Get Info)
 - Mount image
 - Internet enable image
 - Show/Hide Log
 ...and more
 
	1/10/2006	v.0.5.4d3	dev change
 ¥ Added "Type" option to new image view (SPARSE vs UDIF)
 ¥ Enabled AppleScript support for "open" verb
 ¥ Added options for disk image drop actions in preferences
 
	11/25/2005	v.0.5.4d2	dev change
 ¥ Added "Limit segments to size:" preference
 
	9/11/2005	v.0.5.4d1	dev change
 ¥ Added bzip2 support for Mac OS X 10.4+
 ¥ Added volume format preference
 ¥ Added drawer
 ¥ Log view moved to drawer
 ¥ Options view added to drawer
 
	7/21/2005	v.0.5.3b (0.5.3d3)	beta version change
 ¥ Now checks operating system version to determine whether to pass -puppetstrings options (problematic in 10.2 and 10.3)
 ¥ Scan for Restore option now recignizes depricated "-blockonly" option for asr in 10.4 (older functionality intact)
 
	7/20/2005	v0.5.3d2	development version change
 ¥ New option under File menu creates new (blank) images
	
	7/18/2005	v0.5.3d1	development version change
 ¥ No longer uses bindings in preferences
 
	7/05/2005   v.0.5.2b	(0.5.2d5) beta version release
 ¥ Removed "Folder or volume as root of image" option (this is the default behavior now)
 ¥ Modified createImageFromFiles: method to use hdiutil internally (vs. mkdmg)
 - This fixes a potential file limit when creating images with PowerMac G4 computers
 - Eliminates problems encountered when using "ditto" in Mac O.S. 10.4
 ¥ Save panel now sets filename based on format (pathname extensions)
 
	6/26/2005	v0.5.2d4 Minor development version change
 ¥ Added shared user defaults bindings in nib
 
	5/25/2005	v0.5.2d3 Minor development version change
 ¥ Added "Resize..." option to images menu
 
	5/7/2005	v0.5.2d2 Minor development version change
 ¥ Shows determinate progress when imaging (certain functions only)
 ¥ Uses mkdmg 1.6.3
 
	4/17/2005	v0.5.2d1 Minor development version change
 ¥ Convert option under Images menu now respects overwrite flag in preferences
 ¥ Ignores ".Trashes" folder when creating CD or DVD images.
 ¥ Window resize is autosaved in user defaults
 ¥ Fills name of disk image from filename in create/convert image panels
 ¥ Uses mkdmg 1.6.2
 
	4/7/2005	v0.5.1b Minor minor version change
 ¥ Added overwrite option in preferences
 ¥ Added slider to adjust the zlib compression used with UDZO format
 ¥ Added option to quit after imaging when imaging on launch
 ¥ Added options to Images menu:
 - Segment
 - Burn
 - Change Password
 ¥ Uses mkdmg 1.6.1
 
	3/23/2005	v0.5b Minor version change (unreleased)
 ¥ Added "Images" menu that includes:
	 - Create from File/Folder (normal mkdmg functions)
	 - Convert
	 - Get Info
	 - Verify
	 - Checksum
	 -- CRC-32
	 -- MD5
	 - Compact
	 - Make Internet Enabled
	 - Scan Image for Restore
	 - Scan Image for Block Restore
 
 ¥ More image format options in preferences window consisting of:
	 UDRW - UDIF read/write image
	 UDRO - UDIF read-only image
	 UDCO - UDIF ADC-compressed image
	 UDZO - UDIF zlib-compressed image
	 UFBI - UDIF entire image with MD5 checksum
	 UDRo - UDIF read-only (obsolete format)
	 UDCo - UDIF compressed (obsolete format)
	 UDTO - DVD/CD-R master for export
	 UDxx - UDIF stub image
	 UDSP - SPARSE (growable with content)
	 RdWr - NDIF read/write image (deprecated)
	 Rdxx - NDIF read-only image (Disk Copy 6.3.3 format)
	 ROCo - NDIF compressed image (deprecated)
	 Rken - NDIF compressed (obsolete format)
	 DC42 - Disk Copy 4.2 image
 
 ¥ Encryption option in preferences window
 ¥ Uses mkdmg v.1.5
 
	3/17/2005	v0.4.7b Minor beta version change
 ¥ Uses mkdmg tool version 1.4.3
 
	2/5/2005	v0.4.6b	Minor beta version change
 ¥ Bug fixes - removed faults "Cancel" button from preferences window
 ¥ Uses mkdmg tool version 1.4.2 
 
	1/15/2005 v0.4.5b	Minor beta version change
 ¥ Reports errors
 ¥ New preferences
 - Imaging on the fly option
 - Folder or volume as root of image option
 ¥ Uses new mkdmg tool (version 0.1.4.1)
 - Checks for locked volume or read-only dir with chosen imaging location.
 
	12/04/2004 v0.4.4b	Minor beta version change
 ¥ Uses new mkdmg tool (version 0.1.3)
 - Fixes file 'limit' when dragging multiple sources
 ¥ Uses new Icon
 ¥ Performance enhancements
 
	9/13/2004 v0.4.3b	Minor beta version change
 ¥ Preference window is now sheet
 ¥ Preferences are better managed (fixes v. 0.4.2b prefs overwrite)
 ¥ Verbose preference (for verbose logging)
 ¥ Internet Enabled preference (make disk image internet enabled)
 ¥ New version of mkdmg tool used (0.1.2)
 
	8/30/2004 v0.4.2b	Minor beta version chage
 ¥ Preference window now available with compression format options.
 ¥ New version of mkdmg tool used (0.1.1)
 
	8/22/2004 v0.4.1b	Minor version change updated online
 Major overhauls - the likes of which include:
 ¥ New TaskWrapper class used to alleviate stress on the finder, and application,
 this stops certain observed "sticking"
 ¥ New Log view integrated into window using tab view - less sytem log dump
 
	8/20/2004 v0.4b	Minor beta version change updated online
 ¥using new mkdmg engine (command line program vs. shell script)
 
	8/2004	v0.3.3b updated version online
 ¥removed certain error messages
 ¥bug fixes
 
	8/2004	v0.3d Minor beta version change to 0.3.
 ¥First online release version
 ¥Name changed to protect the innocent.  
 ¥Dock icon drop.  
 ¥Dock icon menu.  
	
	05/05/2004 v0.1.1d modified application to remove path extensions before imaging
 
	04/2004	v0.1d		initial version
 
 */


#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import <DiscRecordingUI/DiscRecordingUI.h>
#import "FDImageView.h"
#import "FDTaskWrapper.h"

@interface FDController : NSObject <FDTaskWrapperController>
{
	IBOutlet id internetEnabledButton, verboseButton, 
	statusTextField, promptButton, convertFormatButton, convertEncryptionButton, encryptionButton, compressionButton,
	ConvertView, NewView, SegmentView, segmentSizeButton, quitButton, compressionLevelSlider, overwriteButton, devicesMenu, devicesMenuItem, volumesMenu, volumesMenuItem, 
	resizeStepper, resizeSlider, resizeMinTextField, resizeCurrentTextField, resizeMaxTextField, resizeProjectedTextField, resizeImageTextField, resizePanel, resizeMinButton,
	newNameTextField, newSizeTextField, newFilesystemButton, newEncryptionButton, AccessoryDrawer, newTypeButton,
	volumeFormatButton, volumeNameTextField, logPositionButton, logPositionMenu, imageDropMatrix, limitSegmentButton, limitSegmentSizeButton, limitSegmentSizeTextField,
	accPasswordButton, accInternetButton, accOverwriteButton, accPromptButton, accVerboseButton, imagesMenu; 
	
	// Hybrid view outlets
	IBOutlet id HybridView, imageProgress, hybridHFSBlessedDirectoryTextField, hybridHFSOpenFolderTextField, hybridHFSStartupFileSizeTextField, hybridHFSVolumeNameTextField,
	hybridISOAbstractFileTextField, hybridISOBibliographyFileTextField, hybridISOCopyrightFileTextField, hybridISOVolumeNameTextField, hybridISOMacSpecificButton, hybridUDFVersionMatrix, hybridUDFVolumeNameTextField, hybridVolumeNameTextField;
	
	// SLA view outlets
	IBOutlet id SLAOKButton, SLATextView, SLATableView, SLA, scrubButton;
	
	FDTaskWrapper *freeDMGTask;
	BOOL freeDMGRunning, burnRunning, gotMedia;
	id  logTextView, Preferences, FreeDMGWindow;
	NSUserDefaults *defaults;
	BOOL verbose, internetEnabled, prompt, encryption, quit, doQuit, hasQuit, overwrite, limitSegmentSize;
	NSString *compression; //image format/compression of: UDZO, UFBI, UDRW, UDRO, UDCO, UDBZ, etc.
	NSString *convertFormat; // convert format is different from the main compression format
	NSString *encryptionType; // encryption of: AES-128, AES-256
	NSString *volumeName; 
	NSString * volumeFormat;	// volumeFormat of: HFS+, HFS+J, HFSX, HFS, UFS, MS-DOS 
	NSNumber * imageDropAction;	// imageDropAction of: mount, burn, convert, segment, info, verify, checksum, scan
	NSNumber *logPosition; // log position of: 0  = Right, 1 = Bottom, 2 = Left, 3 = Top
	NSNumber *compressionLevel; // compressionLevel int 1..9 
	NSSavePanel *sPanel;
	NSString *limitSegmentSizeByte; // segment size of: KB, MB, GB, TB
	NSNumber *segmentSize;
	NSToolbar *mainToolbar;
	NSArray * progressStrings, *languages, *volumes, *devices;
	
	// Custom toolbar item identifiers
	NSString 
		*FDToolbarNewItemIdentifier, 
		*FDToolbarConvertItemIdentifier, 
		*FDToolbarVerifyItemIdentifier,
		*FDToolbarMountItemIdentifier, 
		*FDToolbarInspectItemIdentifier,
		*FDToolbarEjectItemIdentifier,
		*FDToolbarLogItemIdentifier,
		*FDToolbarBurnItemIdentifier,
		*FDToolbarInternetItemIdentifier,
		*FDToolbarResizeItemIdentifier,
		*FDToolbarSLAItemIdentifier;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (BOOL)application:(NSApplication *)sender openFiles:(NSArray *)files;
//- (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag;

	// accessors
- (NSArray *) volumes;
- (NSArray *) devices;
-(NSDictionary *) deviceDict;

	//delegate methods
- (void) toggleToolbarShown:(id)sender;
- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar;
- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar;

	// methods
- (void)FDLog:(NSString*)logOutput;

- (NSMutableArray *) hybridTypes;
- (void) setHybridTypes:(NSMutableArray *)hybridTypes;

- (int) createImageWithFiles:(NSArray*)files;
- (int) mountImage:(NSString*)path;
- (void) updatePreferencesPanel;
- (IBAction) beginPreferencesPanel:(id)sender;
- (void) endPreferencesPanel;
- (void)appendOutput:(NSString *)output;
- (IBAction) createImage:(id)sender;
- (IBAction) dropAction:(id)sender;
- (IBAction) okButtonAction:(id)sender;
- (int) burnImageAtPath:(NSString*)path;
- (int) convertImage:(NSString*)image format:(NSString*)format outfile:(NSString*)file;
- (int) convertImage:(NSString*)image format:(NSString*)format outfile:(NSString*)file;
- (int) imageInfoAtPath:(NSString*) imagePath;
- (int) verifyImageAtPath:(NSString*) imagePath;
- (int) checksumImageAtPath:(NSString*) imagePath type:(NSString*) type;
- (int) scanImageForRestore:(NSString*)imagePath blockOnly:(BOOL)blockonly;
- (int) segmentImageAtPath:(NSString*)path segmentName:(NSString*)name segmentSize:(NSString*)size;

- (int) createImage:(NSString*)imagePath fromFolder:(NSString*)sourcePath;
- (int) createImage:(NSString*)imagePath ofSize:(NSNumber*)imageSizeInMB withFilesystem:(NSString*)imageFilesystem volumeName:(NSString*)imageVolumeName type:(NSString*)imageType;

	// Software License Agreement related methods
- (void) saveSLAStringValue;
- (int) addResourcesFromSource:(NSString *) resourcesPath toImage:(NSString *) imagePath;
- (int) createResourcesAtPath:(NSString *) resourcePath withAttributedString:(NSAttributedString *) resourceString withID:(int)resourceID withLocale:(NSString *)locale;

	// Images menu actions

- (void)menuNeedsUpdate:(NSMenu *)menu;
- (IBAction) convertImage:(id)sender;
- (IBAction) makeInternetEnabled:(id)sender;
- (IBAction) scanForRestore:(id)sender;
- (IBAction) scanForBlockRestore:(id)sender;
- (IBAction) getInfo:(id)sender;
- (IBAction) compactImage:(id)sender;
- (IBAction) verifyImage:(id)sender;
- (IBAction) checksumImage:(id)sender;
- (IBAction) convertEncryptionButtonAction:(id)sender;
- (IBAction) convertFormatButtonAction:(id)sender;
- (IBAction) changePassword:(id)sender;
- (IBAction) segmentSizeButtonAction:(id)sender;
- (IBAction) compressionLevelSliderAction:(id)sender;
- (IBAction) createFromFolder:(id)sender;
- (IBAction) createFromVolume:(id)sender;
- (IBAction) createFromDevice:(id)sender;
- (IBAction) resizeImage:(id)sender;
- (IBAction) resizeStepperAction:(id)sender;
- (IBAction) resizeSliderAction:(id)sender;
- (IBAction) resizeOKButtonAction:(id)sender;
- (IBAction) resizeCancelButtonAction:(id)sender;
- (IBAction) resizeMinButtonAction:(id)sender;
- (IBAction) newNameTextFieldAction:(id)sender;
- (IBAction) newSizeTextFieldAction:(id)sender;
- (IBAction) newFilesystemButtonAction:(id)sender;
- (IBAction) newEncryptionButtonAction:(id)sender;
- (IBAction) newTypeButtonAction:(id)sender;
- (IBAction) addSLAToImage:(id)sender;
- (IBAction) enableSLA:(id)sender;
- (IBAction) languageButtonAction:(id)sender;
- (IBAction) flattenImage:(id)sender;
- (IBAction) unflattenImage:(id)sender;
- (IBAction) showHideLogAction:(id)sender;
- (IBAction) makeHybrid:(id)sender;
- (IBAction) segmentImage:(id)sender;
- (IBAction) burnImage:(id)sender;
- (IBAction) compressionButtonAction:(id)sender;
- (IBAction) scrubButtonAction:(id)sender;
- (IBAction) volumeFormatButtonAction:(id)sender;
- (IBAction) logPositionButtonAction:(id)sender;
- (IBAction) logPositionMenuAction:(id)sender;
- (IBAction) imageDropMatrixAction:(id)sender;
- (IBAction) resizeProjectedTextFieldAction:(id)sender;

- (IBAction) limitSegmentButtonAction:(id)sender;
- (IBAction) limitSegmentSizeButtonAction:(id)sender;
- (IBAction) limitSegmentSizeTextFieldAction:(id)sender;
- (IBAction) compressionButtonAction:(id)sender;

- (IBAction) promptButtonAction:(id)sender;
- (IBAction) quitButtonAction:(id)sender;
- (IBAction) overwriteButtonAction:(id)sender;
- (IBAction) internetEnabledButtonAction:(id)sender;
- (IBAction) encryptionButtonAction:(id)sender;

- (IBAction) addSLA:(id)sender;
- (IBAction) removeSLA:(id)sender;
- (IBAction) addSLAToImage:(id)sender;
- (IBAction) SLAOKButtonAction:(id)sender;
- (IBAction) beginSLAPanel:(id)sender;
- (IBAction) endSLAPanel:(id)sender;

- (IBAction) verboseButtonAction:(id)sender;

	// task control
- (int) openTask:(NSString*)path withArguments:(NSArray*)arguments;
- (NSString*)openProgram:(NSString*)programPath withArguments:(NSArray*) arguments;

@end