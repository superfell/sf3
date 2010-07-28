// Copyright (c) 2008-2010 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a 
// copy of this software and associated documentation files (the "Software"), 
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the 
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
// THE SOFTWARE.
//

#import <Cocoa/Cocoa.h>

// This is used to create a snap-shot of the current users preferences
// at the start of the sync, so that during the sync run we consistently
// see what's configured, even if the user trys and changes it while there's
// a sync in progress.

@interface SyncOptions : NSObject {
	BOOL	syncContacts;
	BOOL	limitContactSyncToOwner;
	BOOL	syncEvents;
	BOOL	limitEventSyncToOwner;
	BOOL	syncTasks;
	BOOL	limitTaskSyncToOwner;
	int		protectSfdcLimit;
	BOOL	autoJoinSync;
	BOOL	oneWaySync;
}

-(id)initFromUserDefaults;

@property (readonly) BOOL syncContacts;
@property (readonly) BOOL limitContactSyncToOwner;

@property (readonly) BOOL syncEvents;
@property (readonly) BOOL limitEventSyncToOwner;

@property (readonly) BOOL syncTasks;
@property (readonly) BOOL limitTaskSyncToOwner;

@property (readonly) BOOL autoJoinSync;
@property (readonly) BOOL oneWaySync;

-(BOOL)shouldShowUserWarningOnSfdcChanges:(int)totalChanges;

@end
