// Copyright (c) 2008 Simon Fell
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

#import "SalesforceObjectChangeSummary.h"


@implementation SalesforceObjectChangeSummary

-(id)initForEntity:(NSString *)entity {
	self = [super init];
	adds = 0;
	deletes = 0;
	updates = 0;
	entityName = [entity retain];
	return self;
}

-(void)dealloc {
	[entityName release];
	[super dealloc];
}

-(void)incrementAdds:(int)num {
	adds += num;
}

-(void)incrementUpdates:(int)num {
	updates += num;
}

-(void)incrementDeletes:(int)num {
	deletes += num;
}

-(NSNumber *)adds {
	return [NSNumber numberWithInt:adds];
}

-(NSNumber *)deletes {
	return [NSNumber numberWithInt:deletes];
}

-(NSNumber *)updates {
	return [NSNumber numberWithInt:updates];
}

-(int)totalChanges {
	return adds + updates + deletes;
}

-(NSString *)entityName {
	return entityName;
}

@end

@implementation SalesforceChangeSummary

-(id)init {
	self = [super init];
	changes = [[NSMutableDictionary alloc] init];
	return self;
}

-(void)dealloc {
	[changes release];
	[keyIndex release];
	[super dealloc];
}

-(SalesforceObjectChangeSummary *)changesForEntity:(NSString *)entityName {
	NSString *key = [entityName lowercaseString];
	SalesforceObjectChangeSummary *s = [changes objectForKey:key];
	if (s == nil) {
		s = [[[SalesforceObjectChangeSummary alloc] initForEntity:entityName] autorelease];
		[changes setObject:s forKey:key];
	}
	return s;
}

-(void)removeEntitiesWithNoChanges {
	NSString *k;
	NSEnumerator *e = [[changes allKeys] objectEnumerator];
	while (k = [e nextObject]) {
		if ([[changes objectForKey:k] totalChanges] == 0) 
			[changes removeObjectForKey:k];
	}
}

-(int)totalChanges {
	NSEnumerator *e = [changes objectEnumerator];
	int t = 0;
	SalesforceObjectChangeSummary *s;
	while (s = [e nextObject])
		t += [s totalChanges];
	return t;
}

-(int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [changes count];
}

-(NSArray *)keyIndex {
	if (keyIndex == nil) 
		keyIndex = [[[changes allKeys] sortedArrayUsingSelector:@selector(compare:)] retain];
	return keyIndex;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	NSString *k = [[self keyIndex] objectAtIndex:rowIndex];
	SalesforceObjectChangeSummary *s = [changes objectForKey:k];
	return [s performSelector:NSSelectorFromString([aTableColumn identifier])];
}

@end

