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


#import <Cocoa/Cocoa.h>
#import "zkSObject.h"

// what type of field mapping is this ?
typedef enum SyncFieldType {
	syncFieldTypeString,
	syncFieldTypeNumber,
	syncFieldTypeDate,
	syncFieldTypeDateTime,
	syncFieldTypeBoolean,
	syncFieldTypeCustom
} SyncFieldType;

// metadata for an individual field mapping
@interface FieldMappingInfo : NSObject {
	NSString * syncName;
	NSString * sfdcName;
	SyncFieldType fieldType;
}
- (id) initWithInfo:(NSString *)sync sfdcName:(NSString *)sfdc type:(SyncFieldType)st;
- (NSString *)syncName;
- (NSString *)sfdcName;
- (SyncFieldType)syncFieldType;
// returns the value from the sfdcName field converted to the syncFieldType type
// subclasses can override this and do more interesting stuff
- (id)typedValue:(ZKSObject *)so;

// updates the value in the SObject with the relevant value(s) from the syncData dictionary
- (void)mapFromApple:(NSDictionary *)syncData toSObject:(ZKSObject *)s;

@end
