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

#import "SyncFilters.h"
#import "Constants.h"
#import "ContactMapper.h"


@implementation BaseSyncFilter

- (BOOL)isEqual:(id)anotherFilter {
	return self == anotherFilter;
}

- (id)initWithCoder:(NSCoder *)coder {
    return self;
}
 
- (void)encodeWithCoder:(NSCoder *)coder {
}

@end
 
// for emails, we only care about work type emails.
@implementation EmailSyncFilter

- (NSArray *)supportedEntityNames {
    return [NSArray arrayWithObject:Entity_Email];
}

- (BOOL)shouldApplyRecord:(NSDictionary *)record withRecordIdentifier:(NSString *)recordIdentifier {
	return [[record valueForKey:@"type"] isEqualToString:@"work"];
}

@end

// Filter out any phone types that aren't ones we support
@implementation PhoneSyncFilter

- (void) dealloc {
	[phoneTypes release];
	[super dealloc];
}

- (NSArray *)supportedEntityNames {
    return [NSArray arrayWithObject:Entity_Phone];
}

- (BOOL)shouldApplyRecord:(NSDictionary *)record withRecordIdentifier:(NSString *)recordIdentifier {
	if (phoneTypes == nil) {
		NSLog(@"PhoneSyncFilter - Loading phone types");
		phoneTypes = [[[ContactMapper supportedPhoneTypes] allValues] retain];
	}
	NSString *type = [record valueForKey:@"type"];
	return ([phoneTypes containsObject:type]);
}

@end

// only want to see Home and Work addresses
@implementation AddressSyncFilter

- (NSArray *)supportedEntityNames {
    return [NSArray arrayWithObject:Entity_Address];
}

- (BOOL)shouldApplyRecord:(NSDictionary *)record withRecordIdentifier:(NSString *)recordIdentifier {
	NSString * type = [record valueForKey:@"type"];
	return [type isEqualToString:@"home"] || [type isEqualToString:@"work"];
}

@end

// contacts can have the "display as company" flag set, and they look more like accounts than contacts
// for now we just filter those out alltogether
@implementation CompanySyncFilter

- (NSArray *)supportedEntityNames {
    return [NSArray arrayWithObject:Entity_Contact];
}

- (BOOL)shouldApplyRecord:(NSDictionary *)record withRecordIdentifier:(NSString *)recordIdentifier {
	NSString *type = [record valueForKey:@"display as company"];
	BOOL isPerson = [type isEqualToString:@"person"] || type == nil;
	if (!isPerson) 
		NSLog(@"CompanySyncFilter - filtering %@ : %@", recordIdentifier, record);
	return isPerson;
}

@end

// filter out all the calendars except for the salesforce.com one
@implementation CalendarSyncFilter

- (NSArray *)supportedEntityNames {
    return [NSArray arrayWithObject:Entity_Calendar];
}

- (BOOL)shouldApplyRecord:(NSDictionary *)record withRecordIdentifier:(NSString *)recordIdentifier {
	return [[record valueForKey:@"title"] isEqualToString:@"Salesforce.com"];
}

@end