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

#import "EventMapper.h"
#import "CalendarTracker.h"
#import "FieldMappingInfo.h"
#import "IdUrlFieldMappingInfo.h"
#import "EventFieldMappingInfo.h"
#import "Constants.h"
#import "zkUserInfo.h"
#import "zkDescribeSobject.h"
#import "zkSObject.h"
#import "SyncOptions.h"
#import "SyncFilters.h"

@implementation EventMapper

- (id)initMapper:(ZKSforceClient *)sf  options:(SyncOptions *)syncOptions
{
	self = [super initWithClient:sf andOptions:syncOptions];
	describe = [[sforce describeSObject:@"Event"] retain];

	NSMutableDictionary * mapping = [[NSMutableDictionary alloc] init];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"summary"						sfdcName:@"Subject"		 type:syncFieldTypeString] autorelease] forKey:@"Subject"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"description"					sfdcName:@"Description"  type:syncFieldTypeString] autorelease] forKey:@"Description"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"all day"					    sfdcName:@"IsAllDayEvent" type:syncFieldTypeBoolean] autorelease] forKey:@"IsAllDayEvent"];
	[mapping setObject:[[[IdUrlFieldMappingInfo alloc] initWithInfo:@"url"						sfdcName:@"Id"			 describe:describe] autorelease]		forKey:@"Id"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"location"						sfdcName:@"Location"	 type:syncFieldTypeString] autorelease] forKey:@"Location"];
	[mapping setObject:[[[ActivityDateTimeMappingInfo alloc] initWithInfo:@"start date"] autorelease] 															forKey:@"ActivityDateTime"];
	[mapping setObject:[[[DurationFieldMappingInfo alloc] initWithInfo:@"end date"				sfdcName:@"DurationInMinutes"] autorelease]						forKey:@"DurationInMinutes"];
	fieldMapping = mapping;	
	return self;
}

// what we care about
- (NSArray *)entityNames {
	return [NSArray arrayWithObjects:Entity_Calendar, Entity_Event, nil];
}

- (NSArray *)filters {
	return [NSArray arrayWithObjects:[[[CalendarSyncFilter alloc] init] autorelease], 
									 [[[CalendarChildSyncFilter alloc] initWithEntity:Entity_Event calendar:[calendarTracker calendarId]] autorelease],
									 nil];
}

- (NSString *)primarySalesforceObjectDisplayName {
	return @"Events";
}

- (NSString *)primarySObject {
	return @"Event";
}

// push
- (NSString *)soqlQuery
{
	NSMutableString * soql = [NSMutableString stringWithString:@"select LastModifiedDate, ActivityDate"];
	[self appendValues:[fieldMapping  keyEnumerator] dest:soql format:@", %@"];
	[soql appendString:@" from event"];
	if ([options limitEventSyncToOwner]) 
		[soql appendFormat:@" where ownerId='%@'", [[sforce currentUserInfo] userId]];
	NSLog(@"soql : %@", soql);
	return soql;
}

- (void)pushChangesForSObject:(ZKSObject *)src
{
	NSDictionary * event = [self makeSyncRecord:src];
	[session pushChangesFromRecord:event withIdentifier:[src id]];
	[calendarTracker addEvent:[src id]];
}

// takes the field data from an SObject, and maps it into a sync record dictionary
- (NSDictionary *)makeSyncRecord:(ZKSObject *)src
{
	NSMutableDictionary *event = [self mapFromSObject:src toAppleEntityName:Entity_Event];
	[event setObject:[NSArray arrayWithObject:[calendarTracker calendarId]] forKey:@"calendar"];
	return event;
}

// pull
- (void)pulledChange:(ISyncChange *)change entityName:(NSString *)entity {
	[super pulledChange:change entityName:entity];
	if ([entity isEqualToString:Entity_Event]) {
		// remember to only look at things on our calendar
		if ([[[change record] objectForKey:@"calendar"] containsObject:[calendarTracker calendarId]])
			[self topLevelEntityUpdate:change];
		else
			[session clientRefusedChangesForRecordWithIdentifier:[change recordIdentifier]];		
	}
}

@end
