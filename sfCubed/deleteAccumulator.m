// Copyright (c) 2006-2010 Simon Fell
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
#import "deleteAccumulator.h"
#import "zkSaveResult.h"
#import "AccItem.h"

static const int MAX_IN_ONE_BATCH = 50;

@implementation DeleteAccumulator

- (id)initWithSession:(ISyncSession *)ss sforce:(ZKSforceClient *)sf
{
	self = [super init];
	session = [ss retain];
	sforce = [sf retain];
	deletes = [[NSMutableArray alloc] init];
	return self;
}

-(void)dealloc {
	[deletes release];
	[session release];
	[sforce release];
	[super dealloc];
}

- (void)enqueueDelete:(NSString *)sfId {
	[deletes addObject:sfId];
}

- (NSArray *)toDelete {
	return deletes;
}

- (int)count {
	return [deletes count];
}

- (void)doDeletes:(NSArray *)idsToDelete {
	NSArray * results = [sforce delete:idsToDelete];
	UInt32 i;
	for (i = 0; i < [results count]; i++) {
		ZKSaveResult * sr = [results objectAtIndex:i];
		if ([sr success] || [[sr statusCode] isEqualToString:@"ENTITY_IS_DELETED"]) {
			// either the delete was succesful, or we've already deleted the item in salesforce, eitherway we can accept this one.
			[session clientAcceptedChangesForRecordWithIdentifier:[idsToDelete objectAtIndex:i] formattedRecord:nil newRecordIdentifier:nil];
		} else {
			NSLog(@"Error deleting :%@ -> %@", [deletes objectAtIndex:i], sr);
		}
	}
	[session clientCommittedAcceptedChanges];
}

- (void)performDeletes {
	if ([deletes count] == 0) return;
	NSLog(@"DeleteAccumulator about to remove %d items", [deletes count]);
	while ([deletes count] > 0) {
		if ([deletes count] <= MAX_IN_ONE_BATCH) {
			[self doDeletes:deletes];
			[deletes removeAllObjects];
		} else {
			NSRange rng = NSMakeRange(0, MAX_IN_ONE_BATCH);
			[self doDeletes:[deletes subarrayWithRange:rng]];
			[deletes removeObjectsInRange:rng];
		}
	}
}

@end

