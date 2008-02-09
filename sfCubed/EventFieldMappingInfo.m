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

#import "EventFieldMappingInfo.h"
#import "zkSObject.h"

// maps between activityDateTime + DurationInMinutes on sfdc side, to end date on the apple side
@implementation DurationFieldMappingInfo

- (id) initWithInfo:(NSString *)sName sfdcName:(NSString *)sfdc {
	return [super initWithInfo:sName sfdcName:sfdcName type:syncFieldTypeCustom];
}

// returns the value from the sfdcName field converted to the syncFieldType type
// subclasses can override this and do more interesting stuff
- (id)typedValue:(ZKSObject *)so {
	NSCalendarDate * startDate = [so dateTimeValue:@"ActivityDateTime"];
	int duration = [so intValue:@"DurationInMinutes"];
	return [startDate dateByAddingYears:0 months:0 days:0 hours:0 minutes:duration seconds:0];
}

// updates the value in the SObject with the relevant value(s) from the syncData
- (void)mapFromApple:(NSDictionary *)syncData toSObject:(ZKSObject *)s {
	NSCalendarDate *start = [syncData objectForKey:@"start date"];
	NSCalendarDate *end =   [syncData objectForKey:@"end date"];
	long seconds = (long)[end timeIntervalSinceDate:start];
	NSString *dur = [NSString stringWithFormat:@"%d", seconds / 60];
	NSLog(@"start=%@ end=%@ seconds=%d duration=%@", start, end, seconds, dur);
	[s setFieldValue:dur field:@"DurationInMinutes"];
}

@end

@implementation ActivityDateTimeMappingInfo

- (id) initWithInfo:(NSString *)sName {
	return [super initWithInfo:sName sfdcName:@"ActivityDateTime" type:syncFieldTypeCustom];
}

- (id)typedValue:(ZKSObject *)so {
	BOOL isAllDay = [so boolValue:@"IsAllDayEvent"];
	return isAllDay ? [so dateValue:@"ActivityDate"] : [so dateTimeValue:@"ActivityDateTime"];
}

- (void)mapFromApple:(NSDictionary *)syncData toSObject:(ZKSObject *)s {
	NSCalendarDate *start = [syncData objectForKey:syncName];
	if (start == nil) return;
 	if ([[syncData objectForKey:@"all day"] boolValue])
		[s setFieldDateValue:start field:@"ActivityDate"];
	else
		[s setFieldDateTimeValue:start field:sfdcName];
}

@end