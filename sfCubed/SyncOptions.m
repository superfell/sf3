// Copyright (c) 2008 Simon Fell
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


#import "SyncOptions.h"
#import "Constants.h"

@implementation SyncOptions

-(id)initFromUserDefaults {
	self = [super init];
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	syncContacts			= [ud boolForKey:PREF_SYNC_CONTACTS];
	limitContactSyncToOwner = [ud boolForKey:PREF_MY_CONTACTS];
	syncEvents				= [ud boolForKey:PREF_SYNC_EVENTS];
	limitEventSyncToOwner	= [ud boolForKey:PREF_MY_EVENTS];
	syncTasks				= [ud boolForKey:PREF_SYNC_TASKS];
	limitTaskSyncToOwner	= [ud boolForKey:PREF_MY_TASKS];
	protectSfdcLimit		= [ud boolForKey:PREF_ENABLE_PROTECT_SFDC] ? [ud integerForKey:PREF_PROTECT_SFDC_LIMIT] : -1;
	return self;
}

-(BOOL)syncContacts {
	return syncContacts;
}

-(BOOL)limitContactSyncToOwner {
	return limitContactSyncToOwner;
}

-(BOOL)syncEvents {
	return syncEvents;
}

-(BOOL)limitEventSyncToOwner {
	return limitEventSyncToOwner;
}

-(BOOL)syncTasks {
	return syncTasks;
}

-(BOOL)limitTaskSyncToOwner {
	return limitTaskSyncToOwner;
}

-(BOOL)shouldShowUserWarningOnSfdcChanges:(int)totalChanges {
	return (protectSfdcLimit >= 0) && (totalChanges > protectSfdcLimit);
}

@end
