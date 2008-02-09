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

#import "FieldMappingInfo.h"

@implementation FieldMappingInfo

- (id) initWithInfo:(NSString *)sync sfdcName:(NSString *)sfdc type:(SyncFieldType)st {
	self = [super init];
	syncName = [sync retain];
	sfdcName = [sfdc retain];
	fieldType = st;
	return self;
}

- (void)dealloc {
	[syncName release];
	[sfdcName release];
	[super dealloc];
}

- (NSString *)syncName {
	return syncName;
}

- (NSString *)sfdcName {
	return sfdcName;
}

- (SyncFieldType)syncFieldType {
	return fieldType;
}

- (id)typedValue:(ZKSObject *)src {
	NSString *v = [src fieldValue:sfdcName];
	if (v == nil) return nil;
	switch (fieldType) {
		case syncFieldTypeString:   return v;
		case syncFieldTypeNumber:   return [NSNumber numberWithInt:[src intValue:sfdcName]];
		case syncFieldTypeDate:     return [src dateValue:sfdcName];
		case syncFieldTypeDateTime: return [src dateTimeValue:sfdcName];
		case syncFieldTypeBoolean:  return [NSNumber numberWithBool:[src boolValue:sfdcName]];
	}
	@throw [NSException exceptionWithName:@"Unsupported SyncFieldType" reason:[NSString stringWithFormat:@"No type mapping available for syncFieldType of %d", fieldType] userInfo:nil];
}

- (void)mapFromApple:(NSDictionary *)syncData toSObject:(ZKSObject *)s {
	id v = [syncData objectForKey:syncName];
	if (v == nil) {
		if (syncFieldTypeBoolean == fieldType)
			[s setFieldValue:@"false" field:sfdcName];
		else
			[s setFieldToNull:sfdcName];
	} else {
		switch (fieldType) {
			case syncFieldTypeString:  [s setFieldValue:v field:sfdcName]; break;
			case syncFieldTypeNumber:  [s setFieldValue:[v stringValue] field:sfdcName]; break;
			case syncFieldTypeDate:    [s setFieldDateValue:v field:sfdcName]; break;
			case syncFieldTypeDateTime:[s setFieldDateTimeValue:v field:sfdcName]; break;
			case syncFieldTypeBoolean: [s setFieldValue:[v boolValue] ? @"true" : @"false" field:sfdcName]; break;
		}
	}
}

@end