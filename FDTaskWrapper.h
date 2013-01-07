/*
 File:		FDTaskWrapper.h
 
 Description: 	This class is a generalized process handling class that makes asynchronous interaction with an NSTask easier.  
 There is also a protocol designed to work in conjunction with the TaskWrapper class; 
 your process controller should conform to this protocol.  
 
 TaskWrapper objects are one-shot (since NSTask is one-shot); 
 if you need to run a task more than once, destroy/create new TaskWrapper objects.
 
 Descended from Apple sample source.
 
 Modified for use with FreeDMG <http://www.kelleycomputing.net/freedmg>
 
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


#import <Foundation/Foundation.h>

@protocol FDTaskWrapperController

// Your controller's implementation of this method will be called when output arrives from the NSTask.
// Output will come from both stdout and stderr, per the TaskWrapper implementation.
- (void)appendOutput:(NSString *)output;

	// This method is a callback which your controller can use to do other initialization when a process
	// is launched.
- (void)processStarted;

	// This method is a callback which your controller can use to do other cleanup when a process
	// is halted.
- (void)processFinished;

@end

@interface FDTaskWrapper : NSObject {
    NSTask 			*task;
    id				<FDTaskWrapperController>controller;
    NSArray			*arguments;
}

// This is the designated initializer - pass in your controller and any task arguments.
// The first argument should be the path to the executable to launch with the NSTask.
- (id)initWithController:(id <FDTaskWrapperController>)controller arguments:(NSArray *)args;

	// This method launches the process, setting up asynchronous feedback notifications.
- (void) startProcess;

	// This method stops the process, stoping asynchronous feedback notifications.
- (void) stopProcess;

	// returns task termination status
-(int)terminationStatus;

	// returns a task's process identifier
-(int)processID;

	// returns true if a process is currently running
-(BOOL)isRunning;

-(void) waitUntilExit;

@end

