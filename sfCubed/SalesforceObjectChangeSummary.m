//
//  SalesforceObjectChangeSummary.m
//  sfCubed
//
//  Created by Simon Fell on 6/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "SalesforceObjectChangeSummary.h"


@implementation SalesforceObjectChangeSummary

-(id)initForEntity:(NSString *)entity {
	self = [super init];
	adds = 0;
	deletes = 0;
	updates = 0;
	entityName = [entity retain];
	entitylabel = [entity retain];
	return self;
}

-(void)dealloc {
	[entityName release];
	[entitylabel release];
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

-(NSString *)entityName {
	return entityName;
}

-(NSString *)entityLabel {
	return entitylabel;
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

-(int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [changes count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	SalesforceObjectChangeSummary *s = [[changes allValues] objectAtIndex:rowIndex];
	return [s performSelector:NSSelectorFromString([aTableColumn identifier])];
}

@end

