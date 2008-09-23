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

#import "ActivityMapper.h"
#import "CalendarTracker.h"
#import "Constants.h"

@implementation ActivityMapper

-(void)dealloc {
	[calendarTracker release];
	[super dealloc];
}

- (NSString *)primaryMacEntityName {
	return Entity_Calendar;
}

-(void)setCalendarTracker:(CalendarTracker *)cal {
	calendarTracker = [cal retain];
}

- (void)pulledChange:(ISyncChange *)change entityName:(NSString *)entity {
	if ([entity isEqualToString:Entity_Calendar]) {
		NSLog(@"title:%@ calId:%@ recordId:%@", [[change record] objectForKey:@"title"], [calendarTracker calendarId], [change recordIdentifier]);
		BOOL hasMatchingId = [[change recordIdentifier] isEqualToString:[calendarTracker calendarId]]; 
		if (hasMatchingId || ([[[change record] objectForKey:@"title"] isEqualToString:@"Salesforce.com"])) {
			NSLog(@"Task Mapper accepting calendar : %@ : %@", [change recordIdentifier], [[change record] objectForKey:@"title"]);
			[session clientAcceptedChangesForRecordWithIdentifier:[change recordIdentifier] formattedRecord:nil newRecordIdentifier:[calendarTracker calendarId]];
		} else {
			NSLog(@"Task Mapper rejecting calendar : %@", [[change record] objectForKey:@"title"]);
			[session clientRefusedChangesForRecordWithIdentifier:[change recordIdentifier]];
		}
	}
}

- (void)updateSObject:(ZKSObject *)o withChanges:(NSDictionary *)syncData {
	// basiclly the reverse of makeSyncTaskRecord
	[self mapFromApple:syncData toSObject:o];
}

- (void)relationshipUpdate:(ISyncChange *)change {
	// no child entities
}

@end
