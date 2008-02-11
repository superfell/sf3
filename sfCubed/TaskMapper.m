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

#import "TaskMapper.h"
#import "CalendarTracker.h"
#import "Constants.h"
#import "TaskFieldMappingInfo.h"
#import "IdUrlFieldMappingInfo.h"
#import "zkUserInfo.h"
#import "zkDescribeSobject.h"
#import "SyncOptions.h"

@implementation TaskMapper
	
- (id)initMapper:(ZKSforceClient *)sf  options:(SyncOptions *)syncOptions
{
	self = [super initWithClient:sf andOptions:syncOptions];
	describe = [[sforce describeSObject:@"Task"] retain];

	NSMutableDictionary * mapping = [[NSMutableDictionary alloc] init];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"summary"						sfdcName:@"Subject"		 type:syncFieldTypeString] autorelease] forKey:@"Subject"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"description"					sfdcName:@"Description"  type:syncFieldTypeString] autorelease] forKey:@"Description"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"due date"						sfdcName:@"ActivityDate" type:syncFieldTypeDate] autorelease]   forKey:@"ActivityDate"];
	[mapping setObject:[[[PriorityFieldMappingInfo alloc] initWithInfo:@"priority"				sfdcName:@"Priority"	 sforce:sforce] autorelease]			forKey:@"Priority"];	
	[mapping setObject:[[[CompletionDateFieldMapingInfo alloc] initWithInfo:@"completion date"	sfdcReadName:@"IsClosed" sfdcWriteName:@"Status" sforce:sforce] autorelease] forKey:@"IsClosed"];	
	[mapping setObject:[[[IdUrlFieldMappingInfo alloc] initWithInfo:@"url"						sfdcName:@"Id"			 describe:describe] autorelease]		forKey:@"Id"];
	fieldMapping = mapping;	
	
	return self;
}

// what we care about
- (NSArray *)entityNames {
	return [NSArray arrayWithObjects:Entity_Calendar, Entity_Task, nil];
}

- (NSString *)primarySalesforceObjectDisplayName {
	return @"Tasks";
}

- (NSString *)primarySObject {
	return @"Task";
}

// push
- (NSString *)soqlQuery {
	NSMutableString * soql = [NSMutableString stringWithString:@"select LastModifiedDate"];
	[self appendValues:[fieldMapping  keyEnumerator] dest:soql format:@", %@"];
	[soql appendString:@" from task"];
	if ([options limitTaskSyncToOwner]) 
		[soql appendFormat:@" where ownerId='%@'", [[sforce currentUserInfo] userId]];
	NSLog(@"soql : %@", soql);
	return soql;
}

- (void)pushChangesForSObject:(ZKSObject *)src {
	NSDictionary * task = [self makeSyncRecord:src];
	[session pushChangesFromRecord:task withIdentifier:[src id]];
	[calendarTracker addTask:[src id]];
}

// takes the field data from an SObject, and maps it into a sync record dictionary
- (NSDictionary *)makeSyncRecord:(ZKSObject *)src {
	NSMutableDictionary * task = [self mapFromSObject:src toAppleEntityName:Entity_Task];
	[task setObject:[NSArray arrayWithObject:[calendarTracker calendarId]] forKey:@"calendar"];
	[task setObject:[NSNumber numberWithBool:YES] forKey:@"due date is date only"];
	return task;
}

// pull
- (void)pulledChange:(ISyncChange *)change entityName:(NSString *)entity {
	[super pulledChange:change entityName:entity];
	if ([entity isEqualToString:Entity_Task]) {
		// make sure we're only looking at things that are on our calendar
		// perhaps this should be a filter ?
		if ([[[change record] objectForKey:@"calendar"] containsObject:[calendarTracker calendarId]])
			[self topLevelEntityUpdate:change];
		else
			[session clientRefusedChangesForRecordWithIdentifier:[change recordIdentifier]];		
	}
}

- (void)finish {
	[super finish];
	[[fieldMapping objectForKey:@"IsClosed"] save];
}

@end
