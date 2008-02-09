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

#import "TaskFieldMappingInfo.h"
#import "zkDescribeSObject.h"
#import "zkQueryResult.h"

// implements the custom mapping between salesforces completed yes/no and iCals completed date stamp
@implementation CompletionDateFieldMapingInfo

- (id) initWithInfo:(NSString *)sync sfdcReadName:(NSString *)sfdcRead sfdcWriteName:(NSString *)sfdcWrite sforce:(ZKSforceClient *)sf {
	[super initWithInfo:sync sfdcName:sfdcRead type:syncFieldTypeCustom];
	dates = [NSMutableDictionary dictionaryWithContentsOfFile:[self datesFilename]];
	if (dates == nil) dates = [NSMutableDictionary dictionary];
	[dates retain];
	sfdcWriteName = [sfdcWrite retain];
	
	ZKQueryResult * qr = [sf query:@"select MasterLabel, SortOrder, IsDefault, IsClosed from TaskStatus"];
	taskStatus = [[qr records] retain];
	return self;
}

- (void)dealloc {
	[dates release];
	[sfdcWriteName release];
	[taskStatus release];
	[super dealloc];
}

- (id)typedValue:(ZKSObject *)src {
	if ([src boolValue:sfdcName]) {
		// look for a save date
		NSDate * d = [dates objectForKey:[src id]];
		// might be a NSDate, and not a NSCalendarDate because that's what the plist stuff saves/loads
		if (![d isKindOfClass:[NSCalendarDate class]]) {
			d = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:[d timeIntervalSinceReferenceDate]];
			[dates setObject:d forKey:[src id]];
		}
		// don't have one, use last Modified, and stash away the date
		if (d == nil) {
			d = [src dateTimeValue:@"LastModifiedDate"];
			[dates setObject:d forKey:[src id]];
		}
		return d;
	}
	return nil;
}

- (NSString *)completedStatus {
	ZKSObject * s;
	NSEnumerator * e = [taskStatus objectEnumerator];
	while (s = [e nextObject]) {
		if ([s boolValue:@"IsClosed"])
			return [s fieldValue:@"MasterLabel"];
	}
	return nil;
}

- (NSString *)notStartedStatus {
	ZKSObject * s;
	NSEnumerator *e = [taskStatus objectEnumerator];
	while (s = [e nextObject]) {
		if (![s boolValue:@"IsClosed"] && [s boolValue:@"IsDefault"]) 
			return [s fieldValue:@"MasterLabel"];
	}
	return nil;
}

- (void)mapFromApple:(NSDictionary *)syncData toSObject:(ZKSObject *)s {
	id v = [syncData objectForKey:syncName];
	if (v == nil) {
		if ([s id] != nil)
			[dates removeObjectForKey:[s id]];
		[s setFieldValue:[self notStartedStatus] field:sfdcWriteName];
	} else {
		if ([s id] != nil)
			[dates setObject:v forKey:[s id]];
		[s setFieldValue:[self completedStatus] field:sfdcWriteName];
	}
}

- (void)save {
	[dates writeToFile:[self datesFilename] atomically:YES];
}

- (NSString *)datesFilename {
	NSArray * dirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	return [NSString stringWithFormat:@"%@/sfCubed/taskDates.plist", [dirs objectAtIndex:0]];
}
@end

//////////////////////////////////////////////////////////////////////////////////////
// PriorityFieldMappingInfo
//////////////////////////////////////////////////////////////////////////////////////

// implements the custom mapping between salesforce named priorities and iCals 1-9 priority
@implementation PriorityFieldMappingInfo

- (id) initWithInfo:(NSString *)sync sfdcName:(NSString *)sfdc sforce:(ZKSforceClient *)sforce {
	[super initWithInfo:sync sfdcName:sfdc type:syncFieldTypeCustom];
	ZKQueryResult * qr = [sforce query:@"select MasterLabel, SortOrder, IsDefault, IsHighPriority from TaskPriority"];
	priority = [[qr records] retain];
	return self;
}

- (void) dealloc {
	[priority release];
	[super dealloc];
}

// pass in a boolean field from the TaskPriority sobject, returns the matching master label
- (NSString *)priorityFromFlag:(NSString *)flagField {
	ZKSObject * s;
	NSEnumerator *e = [priority objectEnumerator];
	while (s = [e nextObject]) {
		if ([s boolValue:flagField])
			return [s fieldValue:@"MasterLabel"];
	}
	return nil;
}

- (NSString *)defaultPriority {
	NSString * p = [self priorityFromFlag:@"IsDefault"];
	if (p != nil) return p;
	NSLog(@"Unable to default default priority from TaskPriority!");
	return @"Normal";
}

- (id)typedValue:(ZKSObject *)src {
	NSString * p = [src fieldValue:sfdcName];
	return [NSNumber numberWithInt:[self appleValueFromSfdcValue:p]];
}

- (int)appleValueFromSfdcValue:(NSString *)sfdcValue {
	ZKSObject * s;
	NSEnumerator *e = [priority objectEnumerator];
	while (s = [e nextObject]) {
		if ([[s fieldValue:@"MasterLabel"] isEqualToString:sfdcValue])
			return [s boolValue:@"IsHighPriority"] ? 1 : 5;
	}
	return 0;
}

// this is a bit kookey, but we map multple sfdc values to the same apple value
// so we don't want to change the sfdc value unless the mapped appled value is different.
// i.e. we shouldn't change the sfdc priority between values that are mapped to the same apple priority
- (void)mapFromApple:(NSDictionary *)syncData toSObject:(ZKSObject *)s {
	int applePriority = [[syncData objectForKey:syncName] intValue];
	// 1 == high priority, everything else is default, but dont' change unless they don't match at all
	NSString *sfdcPriority = [self priorityFromFlag:applePriority == 1 ? @"IsHighPriority" : @"IsDefault"];
	
	// current sfdc priority mapped back to apple priority
	int currentP = [self appleValueFromSfdcValue:[s fieldValue:sfdcName]];
	int newP     = applePriority == 1 ? 1 : 5;
	if (newP != currentP)
		[s setFieldValue:sfdcPriority field:sfdcName];
}

@end

