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

#import "PulledItem.h"
#import "AcceptChangeInfo.h"
#import "ZKSObject.h"

@implementation PulledItem

+ (PulledItem *)itemForChange:(ISyncChange *)c SObject:(ZKSObject *)so
{
	PulledItem * i = [[PulledItem alloc] initForChange:c SObject:so];
	return [i autorelease];
}

- (id)initForChange:(ISyncChange *)c SObject:(ZKSObject *)so
{
	[super init];
	change = [c retain];
	sobject = [so retain];
	childAccepts = [[NSMutableArray alloc] init];
	shouldFormatForAccept = YES;
	return self;
}

- (void)dealloc
{
	[change release];
	[sobject release];
	[childAccepts release];
	[super dealloc];
}


- (ISyncChangeType)changeType {
	// if change is nil, then there's no primary change, but a bunch of changes for related records
	// which by definition makes this an update
	return change == nil ? ISyncChangeTypeModify : [change type];
}

- (ZKSObject * )sobject
{
	return sobject;
}

- (void)addChildAccept:(AcceptChangeInfo *)childAccept
{
	if (childAccept != nil)
		[childAccepts addObject:childAccept];
}

- (void)acceptChildren:(ISyncSession *)session sfId:(NSString *)sfId isForDelete:(BOOL)forDel {
	AcceptChangeInfo * c;
	NSEnumerator *e = [childAccepts objectEnumerator];
	while (c = [e nextObject]) {
		if ([c isForDelete] == forDel)
			[c accept:session];
	}
}

- (void)preAcceptChildren:(ISyncSession *)session sfdcId:(NSString *)sfdcId {
	AcceptChangeInfo *c;
	NSEnumerator *e = [childAccepts objectEnumerator];
	while (c = [e nextObject]) 
		[c preAccept:session sfId:sfdcId];
	
	e = [childAccepts objectEnumerator];
	while (c = [e nextObject]) 
		[c preAccept2:session sfId:sfdcId];
}

- (void)accept:(ISyncSession *)session formattedRecord:(NSDictionary *)formattedRecord sfdcId:(NSString *)sfdcId {
	[self preAcceptChildren:session sfdcId:sfdcId];
	// because we re-use synthetic ids where we have a flattenen data model vs Apple, we need to accept
	// all the delete first so we can re-use the ids.
	[self acceptChildren:session sfId:sfdcId isForDelete:YES];
	if (change != nil) {
		[session clientAcceptedChangesForRecordWithIdentifier:[change recordIdentifier] formattedRecord:formattedRecord newRecordIdentifier:sfdcId];		
	}
	[self acceptChildren:session sfId:sfdcId isForDelete:NO];
}

- (BOOL)shouldFormatForAccept {
	return shouldFormatForAccept;
}

- (void)setShouldFormatForAccept:(BOOL)f {
	shouldFormatForAccept = f;
}

@end
