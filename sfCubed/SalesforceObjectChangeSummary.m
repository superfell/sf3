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
	creates = [[NSMutableArray alloc] init];
	deletes = [[NSMutableArray alloc] init];
	updates = [[NSMutableArray alloc] init];
	entityName = [entity retain];
	return self;
}

-(void)dealloc {
	[entityName release];
	[creates release];
	[deletes release];
	[updates release];
	[super dealloc];
}

-(void)willCreate:(ZKSObject *)o {
	[creates addObject:o];
}

-(void)willUpdate:(ZKSObject *)o {
	[updates addObject:o];
}

-(void)willDelete:(NSString *)sfId {
	[deletes addObject:sfId];
}

-(NSArray *)createDetails {
	return creates;
}

-(NSArray *)updateDetails {
	return updates;
}

-(NSArray *)deleteDetails {
	return deletes;
}

-(NSNumber *)adds {
	return [NSNumber numberWithInt:[creates count]];
}

-(NSNumber *)deletes {
	return [NSNumber numberWithInt:[deletes count]];
}

-(NSNumber *)updates {
	return [NSNumber numberWithInt:[updates count]];
}

-(int)totalChanges {
	return [creates count] + [updates count] + [deletes count];
}

-(NSString *)entityName {
	return entityName;
}

-(void)dump {
	NSLog(@"%@\r\n", entityName);
	NSLog(@"creates\r\n%@\r\nupdates\r\n%@\r\ndeletes\r\n%@", creates, updates, deletes);
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

-(void)dump {
	NSLog(@"Change Summary\r\n=============");
	for (SalesforceObjectChangeSummary *s in [changes allValues])
		[s dump];
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
	for (NSString *k in [changes allKeys]) {
		if ([[changes objectForKey:k] totalChanges] == 0) 
			[changes removeObjectForKey:k];
	}
}

-(int)totalChanges {
	int t = 0;
	for (SalesforceObjectChangeSummary *s in [changes allValues]) 
		t += [s totalChanges];
	return t;
}

-(int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [changes count];
}

-(NSArray *)changes {
	return [changes allValues];
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

