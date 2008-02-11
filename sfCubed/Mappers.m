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


#import "Mappers.h"
#import "Constants.h"

@interface Mappers (Private)
- (NSArray *)accumulate:(SEL)sel;
@end

@implementation Mappers

- (id)initForUserId:(NSString *)uid {
	[super init];
	mappers = [[NSMutableArray alloc] init];
	calendar = [[CalendarTracker alloc] initForUserId:uid];
	return self;
}

- (void)dealloc {
	[mappers release];
	[calendar release];
	[session release];
	[super dealloc];
}

- (void)addMapper:(BaseMapper *)m {
	[mappers addObject:m];
	// todo, make "BaseMapper may not respond to -setCalendarTracker warning go away
	if ([m respondsToSelector:@selector(setCalendarTracker:)])
		[m setCalendarTracker:calendar];
}

// when we're done pushing, we need to push the calendar entity if needed
- (void)pushFinished:(NSString *)userId {
	NSDictionary *cal = [calendar asSyncObjectForSession:session];
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	if ([d boolForKey:PREF_SYNC_TASKS] || [d boolForKey:PREF_SYNC_EVENTS])
		[session pushChangesFromRecord:cal withIdentifier:[calendar calendarId]];
}

- (NSArray *)accumulate:(SEL)sel {
	NSMutableSet * entities = [NSMutableSet set];
	BaseMapper * m;
	NSEnumerator * e = [mappers objectEnumerator];
	while(m = [e nextObject]) {
		[entities addObjectsFromArray:[m performSelector:sel]];
	}
	return [entities allObjects];
}

- (NSArray *)entityNames
{
	return [self accumulate:@selector(entityNames)];
}

- (NSArray *)filters
{
	return [self accumulate:@selector(filters)];
}

- (void)setSession:(ISyncSession *)syncSession
{
	session = [syncSession retain];
	[mappers makeObjectsPerformSelector:@selector(setSession:) withObject:syncSession];
}

- (void)setAccumulator:(DeleteAccumulator *)acc;
{
	[mappers makeObjectsPerformSelector:@selector(setAccumulator:) withObject:acc];
}

- (NSEnumerator *)objectEnumerator
{
	return [mappers objectEnumerator];
}

- (UInt32)count
{
	return [mappers count];
}
@end
