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

#import "IdUrlFieldMappingInfo.h"


//////////////////////////////////////////////////////////////////////////////////////
// IdUrlFieldMappingInfo
//////////////////////////////////////////////////////////////////////////////////////
@implementation IdUrlFieldMappingInfo

- (id) initWithInfo:(NSString*)sync sfdcName:(NSString *)sfdc describe:(ZKDescribeSObject *)desc {
	[super initWithInfo:sync sfdcName:sfdc type:syncFieldTypeCustom];
	NSMutableString *detail = [NSMutableString stringWithString:[desc urlDetail]];
	[detail replaceOccurrencesOfString:@"{ID}" withString:@"%@" options:NSLiteralSearch range:NSMakeRange(0, [detail length])];
	urlFormat = [detail retain];
	return self;
}

-(void)dealloc {
	[urlFormat release];
	[super dealloc];
}

// this is a no-op, we don't care what sync says the url is
- (void)mapFromApple:(NSDictionary *)syncData toSObject:(ZKSObject *)s {
}

- (id)typedValue:(ZKSObject *)so {
	NSString *sfId = [so id];
	if (sfId == nil) return nil;
	return [NSURL URLWithString:[NSString stringWithFormat:urlFormat, sfId]];
}

@end