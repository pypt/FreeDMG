/*
 File: rtf2r.m
 
 Created by: Osamu Shigematsu
 
 rtf2r attempts to output Rez source (".r") from rtf, html or txt files
 
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
 
 Version changes:
 
 Date			Version				Author
 --------------------------------------------------
 12/25/2007		v.1.0				Osamu Shigematsu
 • Initial version
 
 12/25/2007		v.1.1				Osamu Shigematsu
 • Added ability to read html files
 • Added UTI
 
 12/25/2007		v.1.2				Eddie Kelley <eddie@kelleycomputing.net>
 • Added ability to read text files (was only attempting to open rtf and html)
 • Added dump_rsrc_file function to write resource directly to file
 • dump_rsrc_file adds support for additional locales
 
 4/30/2008		v.1.3				Oliver Braun <nospam4obr@gmx.de>
 • Contributed patch to flip endianess of 'styl' resources to big endian
 
 */

#include <Carbon/Carbon.h>
#include <Cocoa/Cocoa.h>
#include <stdio.h>
#include <unistd.h>

@interface NSString (rtf2r)
- (NSString *)UTI;
@end

@implementation NSString (rtf2r)
- (NSString *)UTI
{ 
	FSRef fileRef;
	Boolean isDirectory;
	NSString *type = nil;
	if (FSPathMakeRef((const UInt8 *)[self fileSystemRepresentation], &fileRef, &isDirectory) == noErr) {
		CFDictionaryRef values = NULL;
		CFStringRef attrs[1] = { kLSItemContentType };
		CFArrayRef attrNames = CFArrayCreate(NULL, (const void **)attrs, 1, NULL);
		if (LSCopyItemAttributes(&fileRef, kLSRolesViewer, attrNames, &values) == noErr) {
			if (values != NULL) {
				CFTypeRef uti = CFDictionaryGetValue(values, kLSItemContentType);
				if (uti != NULL) {
					type = [NSString stringWithString:(NSString *)uti];
				}
				CFRelease(values);
			}
		}
		CFRelease(attrNames);
	}
	return type;
}
@end

int locale;

void dump_rsrc(const char *type, NSData *data)
{
    short num, cnt;
    Size size, i, j;
    char *sep;
	const unsigned char *buf = [data bytes];
	
    size = [data length];
	
	switch (locale) {
		case 5002:
			printf("data '%s' (5002, \"English\") {\n", type);
			break;
		default:
		case 5006:
			printf("data '%s' (5006, \"Japanese\") {\n", type);
			break;
	}
	
	
    for (i = 0; i < size; i += 16) {
		num = (i + 16 <= size) ? 16 : size - i;
		printf("\t$\"");
		cnt = 0;
		for (j = 0; j < num; ++j) {
			if (j > 0 && (j & 1) == 0) {
				printf(" ");
				++cnt;
			}
			printf("%02X", buf[i + j]);
			cnt += 2;
		}
		
		printf("\"");
		for ( ; cnt < 39 + 4; ++cnt) {
			printf(" ");
		}
		printf("/* ");
		for (j = 0; j < num; ++j) {
			printf("%c", isprint(buf[i + j]) ? buf[i + j] : '.');
		}
		printf(" */\n");
    }
	
    printf("};\n");
    printf("\n");
}

void dump_rsrc_file(const char *type, NSData *data, NSString *rPath)
{
    short num, cnt;
    Size size, i, j;
    char *sep;
	const unsigned char *buf = [data bytes];
	FILE * fd;
	char * fmode;
	
	if(strcmp(type, "TEXT") == 0){
	   if((fd = fopen([rPath UTF8String], "w+")) < 0)
		{
			// error opening file for writing
			fprintf(stderr, "Error opening file: %s", [rPath UTF8String]);
			return;
		}
	}
	else if(strcmp(type, "styl") == 0){
	   if((fd = fopen([rPath UTF8String], "a")) < 0){
			// error opening file for appending
			fprintf(stderr, "Error opening file: %s", [rPath UTF8String]);
			return;
		}
	}
	else{
	// unrecognized type? 
	}
	
	size = [data length];
	
	switch (locale) {
		case 5001:
			fprintf(fd, "data '%s' (5001, \"German\") {\n", type);
			break;
		case 5002:
			fprintf(fd, "data '%s' (5002, \"English\") {\n", type);
			break;
		case 5003:
			fprintf(fd, "data '%s' (5003, \"Spanish\") {\n", type);
			break;
		case 5004:
			fprintf(fd, "data '%s' (5004, \"French\") {\n", type);
			break;
		case 5005:
			fprintf(fd, "data '%s' (5005, \"Italian\") {\n", type);
			break;
		case 5006:
			fprintf(fd, "data '%s' (5006, \"Japanese\") {\n", type);
			break;
		case 5007:
			fprintf(fd, "data '%s' (5007, \"Dutch\") {\n", type);
			break;
		case 5008:
			fprintf(fd, "data '%s' (5008, \"Swedish\") {\n", type);
			break;
		case 5009:
			fprintf(fd, "data '%s' (5009, \"Brazilian Portuguese\") {\n", type);
			break;
		case 5010:
			fprintf(fd, "data '%s' (5010, \"Simplified Chinese\") {\n", type);
			break;
		case 5011:
			fprintf(fd, "data '%s' (5011, \"Traditional Chinese\") {\n", type);
			break;
		case 5012:
			fprintf(fd, "data '%s' (5012, \"Danish\") {\n", type);
			break;
		case 5013:
			fprintf(fd, "data '%s' (5013, \"Finnish\") {\n", type);
			break;
		case 5014:
			fprintf(fd, "data '%s' (5014, \"French Canadian\") {\n", type);
			break;
		case 5015:
			fprintf(fd, "data '%s' (5015, \"Korean\") {\n", type);
			break;
		case 5016:
			fprintf(fd, "data '%s' (5016, \"Norwegian\") {\n", type);
			break;
		default:
			fprintf(fd, "data '%s' (5002, \"English\") {\n", type);
			break;

	}
	
	
    for (i = 0; i < size; i += 16) {
		num = (i + 16 <= size) ? 16 : size - i;
		fprintf(fd, "\t$\"");
		cnt = 0;
		for (j = 0; j < num; ++j) {
			if (j > 0 && (j & 1) == 0) {
				fprintf(fd, " ");
				++cnt;
			}
			fprintf(fd, "%02X", buf[i + j]);
			cnt += 2;
		}
		
		fprintf(fd, "\"");
		for ( ; cnt < 39 + 4; ++cnt) {
			fprintf(fd, " ");
		}
		fprintf(fd, "/* ");
		for (j = 0; j < num; ++j) {
			fprintf(fd, "%c", isprint(buf[i + j]) ? buf[i + j] : '.');
		}
		fprintf(fd, " */\n");
    }
	
    fprintf(fd, "};\n");
    fprintf(fd, "\n");
	
	if(fclose(fd) < 0)
	{
		// error closing file
		fprintf(stderr, "Error closing file: %s", [rPath UTF8String]);
		return;
	}
}


void rtf2r(const char *filename)
{
	NSString *path = [NSString stringWithUTF8String:filename];
	NSString *rPath = [[[NSString stringWithUTF8String:filename] stringByDeletingPathExtension] stringByAppendingPathExtension:@"r"];
	NSString *uti = [path UTI];
	NSURL *url = [NSURL fileURLWithPath:path];
	NSAttributedString *str;
	if (UTTypeConformsTo((CFStringRef)uti, kUTTypeRTF)) {
		str = [[NSAttributedString alloc] initWithURL:url documentAttributes:nil];
	}
	else if (UTTypeConformsTo((CFStringRef)uti, kUTTypeText)) {
		str = [[NSAttributedString alloc] initWithURL:url documentAttributes:nil];
	}
	else if (UTTypeConformsTo((CFStringRef)uti, kUTTypeHTML)) {
		NSData *html = [NSData dataWithContentsOfURL:url];
		str = [[NSAttributedString alloc] initWithHTML:html documentAttributes:nil];
	}
	else
		return;
	
	// 1. convert Attributed string into RTF data
	NSData *data = [str RTFFromRange:NSMakeRange(0, [str length])
				  documentAttributes:nil];
	
	// 2. put it into paste board server
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	
	if(!pb)
		NSLog(@"Error: nil pasteboard (no instances of pboard running?)");
	
	[pb declareTypes:[NSArray arrayWithObject:NSRTFPboardType]
			   owner:nil];
	[pb setData:data forType:NSRTFPboardType];
	
	//NSArray *types = [pb types];
//	NSEnumerator *enumerator = [types objectEnumerator];
//	id type;
//	while (type = [enumerator nextObject]) {
//		fprintf(stderr, "%s\n", [type UTF8String]);
//	}
	
	// 3. Get 'TEXT' and 'styl' data
	NSData *TEXT = [pb dataForType:@"CorePasteboardFlavorType 0x54455854"];
	NSData *styl = [pb dataForType:@"CorePasteboardFlavorType 0x7374796C"];
	
	// 4. Convert 'styl' data to big endian
	// 
	// Thanks to Oliver Braun for this patch
	//
		NSMutableData *styl_be = [NSMutableData dataWithLength: 0];
		
		unsigned short count = 0;
		if( [styl length] >= 2 ) {
				[styl getBytes: &count length: sizeof(count)];
				unsigned short count_be =  NSSwapHostShortToBig(count);
				[styl_be appendBytes: &count_be length: sizeof(count_be)];
		}
		
		unsigned short index = 0;
		
		for( ; index < count; ++index ) {
				struct {
						unsigned long  StartIndex;
						unsigned short Height;
						unsigned short Ascent;
						unsigned short FontFamily;
						unsigned char  FontStyle; // bitfield, 0x1=bold 0x2=italic 0x4=underline 0x8=outline 0x10=shadow 0x20=condensed 0x40=extended
						unsigned char  Unused;    // ?, maybe the above field has 16 bits, so bits might need to be swapped ..  
						unsigned short FonstSize;
						unsigned short Color[3];
				} rtfs;
				
				NSRange entry = { 2 + index * sizeof(rtfs), sizeof(rtfs) };
				[styl getBytes:&rtfs range: entry];
		
				rtfs.StartIndex = NSSwapHostLongToBig(rtfs.StartIndex);
				rtfs.Height = NSSwapHostShortToBig(rtfs.Height);
				rtfs.Ascent = NSSwapHostShortToBig(rtfs.Ascent);
				rtfs.FontFamily = NSSwapHostShortToBig(rtfs.FontFamily);
				rtfs.FonstSize = NSSwapHostShortToBig(rtfs.FonstSize);		
				rtfs.Color[0] = NSSwapHostShortToBig(rtfs.Color[0]);
				rtfs.Color[1] = NSSwapHostShortToBig(rtfs.Color[1]);
				rtfs.Color[2] = NSSwapHostShortToBig(rtfs.Color[2]);
		
				// Leopard/PPC choses a slightly different font family
				if ( 0x1400 == rtfs.FontFamily )
						rtfs.FontFamily |= 0x0078; // FIXME: remove
				
				[styl_be appendBytes: &rtfs length: sizeof(rtfs)];
		}
	
	// 5. Display data
	dump_rsrc_file("TEXT", TEXT, rPath);
	dump_rsrc_file("styl", styl_be, rPath);
	
}

int main (int argc, char * argv[]) {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	int opt;
	while ((opt = getopt(argc, argv, "l:")) != -1) {
        switch (opt) {
			case 'l':
				locale = atoi(optarg);
				break;
			default: /* '?' */
				fprintf(stderr, "Usage: %s [-l locale] input file\n",
						argv[0]);
				exit(EXIT_FAILURE);
        }
    }
	
	if (optind >= argc) {
        fprintf(stderr, "Expected input file after options\n");
        exit(EXIT_FAILURE);
    }

	rtf2r(argv[optind]);
	
	[pool drain];
	return 0;
}
