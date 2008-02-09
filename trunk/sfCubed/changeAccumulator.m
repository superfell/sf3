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
#import "changeAccumulator.h"
#import "zkSaveResult.h"
#import "AccItem.h"


// this can be cleaned up, we're only using it for deletes now.

@implementation ChangeAccumulator

- (ChangeAccumulator *)initWithSession:(ISyncSession *)ss sforce:(ZKSforceClient *)sf
{
	self = [super init];
	session = [ss retain];
	sforce = [sf retain];
	changes = [[NSMutableArray alloc] init];
	mode = 'f';
	return self;
}

-(void)dealloc {
	NSLog(@"Dealloc ChangeAccumulator");
	[changes release];
	[session release];
	[sforce release];
	[super dealloc];
}

- (void)delete:(NSString *)sfId
{
	[self add:sfId mode:'d'];
}

- (void)create:(ZKSObject *)o originalId:(NSString *)oid;
{
	AccItem * c = [AccItem withSObject:o originalId:oid newId:nil];
	[self add:c mode:'c'];
}

- (void)update:(ZKSObject *)o
{
	[self updateWithIds:o originalId:nil newRecordId:nil];
}

- (void)updateWithIds:(ZKSObject *)o originalId:(NSString *)oid newRecordId:(NSString *)nid
{
	AccItem * c = [AccItem withSObject:o originalId:oid newId:nid];
	[self add:c mode:'u'];
}

- (void)add:(NSObject *)item mode:(char)m
{
	if (mode != m) [self flush];
	mode = m;
	[changes addObject:item];
	if ([changes count] > 25) [self flush];
}

- (void)flush
{
	if ([changes count] == 0) return;
	NSLog(@"Change Accumulator about to flush %d items, mode=%c", [changes count], mode);
	if (mode == 'c') [self doCreates];
	else if (mode == 'u') [self doUpdates];
	else if (mode == 'd') [self doDeletes];
	[changes removeAllObjects];
}

- (void)doDeletes
{
	NSArray * results = [sforce delete:changes];
	UInt32 i;
	for (i = 0; i < [results count]; i++) {
		ZKSaveResult * sr = [results objectAtIndex:i];
		if ([sr success]) {
			[session clientAcceptedChangesForRecordWithIdentifier:[changes objectAtIndex:i] formattedRecord:nil newRecordIdentifier:nil];
		} else {
			NSLog(@"Error deleting :%@ -> %@", [changes objectAtIndex:i], [sr message]);
		}
	}
	[session clientCommittedAcceptedChanges];
}

- (NSArray *)makeSObjectArray
{	
	NSMutableArray * sobjects = [NSMutableArray arrayWithCapacity:[changes count]];
	UInt32 i;
	for (i = 0; i < [changes count]; i++)
		[sobjects addObject:[[changes objectAtIndex:i] sobject]];
	return sobjects;
}

- (void)doCreates
{
	NSArray *sobjects = [self makeSObjectArray];
	NSArray *results  = [sforce create:sobjects];
	UInt32 i;
	for (i = 0; i < [results count]; i++) {
		ZKSaveResult * sr = [results objectAtIndex:i];
		if ([sr success]) {
			NSLog(@"new Id : %@", [sr id]);
			[session clientAcceptedChangesForRecordWithIdentifier:[[changes objectAtIndex:i] originalId] formattedRecord:nil newRecordIdentifier:[sr id]];
		} else {
			NSLog(@"Error : %@ %@", [sr statusCode], [sr message]);
		}
	}
	[session clientCommittedAcceptedChanges];
}

- (void)doUpdates
{
	NSArray *sobjects = [self makeSObjectArray];
	NSArray * results = [sforce update:sobjects];
	UInt32 i;
	for (i = 0; i < [results count]; i++) {
		ZKSaveResult * sr = [results objectAtIndex:i];
		if ([sr success]) {
			NSString * recId = [[changes objectAtIndex:i] originalId];
			if (recId == nil) recId = [sr id];
			NSString * newRecId = [[changes objectAtIndex:i] newId];
			[session clientAcceptedChangesForRecordWithIdentifier:recId formattedRecord:nil newRecordIdentifier:newRecId];
		} else {
			NSLog(@"Error : %@ %@", [sr statusCode], [sr message]);
		}
	}
	[session clientCommittedAcceptedChanges];
}

@end

