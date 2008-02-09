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

#import "MyISyncChange.h"

@interface MyISyncChange(Private) 
- (id)initWithChange:(ISyncChange *)c type:(ISyncChangeType)type;
- (void)setRecord:(NSDictionary *)r;
@end

@implementation MyISyncChange

+ (id)wrap:(ISyncChange *)src withType:(ISyncChangeType)type {
	return [[[MyISyncChange alloc] initWithChange:src type:type] autorelease];
}

- (id)initWithChange:(ISyncChange *)c type:(ISyncChangeType)t {
	self = [super init];
	src = [c retain];
	type = t;
	return self;
}

- (void)dealloc {
	[src release];
	[super dealloc];
}

- (ISyncChangeType)type {
	return type;
}

- (NSString *)recordIdentifier {
	return [src recordIdentifier];
}

- (NSDictionary *)record {
	return [src record];
}

- (NSArray /* NSDictionary */ *)changes {
	return [src changes];
}

@end
