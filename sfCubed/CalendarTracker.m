// Copyright (c) 2006-2008 Simon Fell
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

#import "CalendarTracker.h"
#import "Constants.h"

@implementation CalendarTracker

-(id)initForUserId:(NSString *)uid {
	self = [super init];
	events = [[NSMutableArray alloc] init];
	tasks  = [[NSMutableArray alloc] init];
	userId = [uid copy];
	calendarId = [[NSString stringWithFormat:@"%@-Calendar", userId] retain];

	// we don't care about calendar suffix anymore, remove it from the user prefs
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:PREF_CALENDAR_SUFFIX];
	return self;
}

-(void)dealloc {
	[tasks release];
	[events release];
	[calendarId release];
	[userId release];
	[super dealloc];
}

-(void)addEvent:(NSString *)eventId {
	[events addObject:eventId];
}

-(void)addTask:(NSString *)taskId {
	[tasks addObject:taskId];
}

- (NSString *)calendarId {
	return calendarId;
}

-(NSDictionary *)asSyncObjectForSession:(ISyncSession *)s {
	NSMutableDictionary *cal = [NSMutableDictionary dictionary];
	[cal setObject:Entity_Calendar forKey:key_RecordEntityName];
	[cal setObject:@"This calendar automatically created by SfCubed" forKey:@"notes"];
	[cal setObject:[NSNumber numberWithBool:NO] forKey:@"read only"];
	[cal setObject:@"Salesforce.com" forKey:@"title"];
	NSDictionary *truth = nil;
	NSArray *theTasks = tasks;
	NSArray *theEvents = events;
	if ([tasks count] == 0 || [events count] == 0) {
		ISyncRecordSnapshot *ss = [s snapshotOfRecordsInTruth];
		NSString *recordId = [self calendarId];
		truth = [[ss recordsWithIdentifiers:[NSArray arrayWithObject:recordId]] objectForKey:recordId];		
		if ([tasks count] == 0)
			theTasks = [truth objectForKey:@"tasks"];
		if ([events count] == 0)
			theEvents = [truth objectForKey:@"events"];
	}
	if ([theTasks count] > 0)
		[cal setObject:theTasks forKey:@"tasks"];
	if ([theEvents count] > 0)
		[cal setObject:theEvents forKey:@"events"];
	return cal;
}

@end
