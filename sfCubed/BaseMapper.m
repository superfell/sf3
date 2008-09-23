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

#import "BaseMapper.h"
#import "Constants.h"
#import "FieldMappingInfo.h"
#import "zkDescribeField.h"
#import "zkSaveResult.h"
#import "AcceptChangeInfo.h"
#import "PulledItem.h"
#import "SalesforceObjectChangeSummary.h"

@implementation BaseMapper

-(id)initWithClient:(ZKSforceClient *)client andOptions:(SyncOptions *)syncOptions {
	self = [super init];
	pulledEntities = [[NSMutableDictionary alloc] init];
	pushedSObjects = [[NSMutableDictionary alloc] init];
	phase = syncPhaseSetup;
	sforce = [client retain];
	options = [syncOptions retain];
	return self;
}

-(void)dealloc {
	[fieldMapping release];
	[session release];
	[sforce release];
	[accumulator release];
	[pulledEntities release];
	[pushedSObjects release];
	[describe release];
	[options release];
	[super dealloc];
}

// this is what your concrete mapper should be implementing
- (NSArray *)entityNames {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override entityNames" userInfo:nil];
}
- (NSArray *)filters {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override filters" userInfo:nil];
}
- (NSString *)primarySalesforceObjectDisplayName {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override primarySalesforceObjectDisplayName" userInfo:nil];
}
- (NSString *)primarySObject {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override primarySObject" userInfo:nil];
}
- (NSString *)primaryMacEntityName {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override primaryMacEntityName" userInfo:nil];
}
- (NSString *)soqlQuery {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override soqlQuery" userInfo:nil];
}
- (void)pushChangesForSObject:(ZKSObject *)src {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override pushChangesForSObject" userInfo:nil];
}
- (NSDictionary *)makeSyncRecord:(ZKSObject *)src {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override makeSyncRecord" userInfo:nil];
}
- (void)pulledChange:(ISyncChange *)change entityName:(NSString *)entity {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override pulledChange" userInfo:nil];
}
- (void)relationshipUpdate:(ISyncChange *)change {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override relationshipUpdate" userInfo:nil];
}
- (void)updateSObject:(ZKSObject *)o withChanges:(NSDictionary *)syncData {
	@throw [NSException exceptionWithName:@"must impl this" reason:@"Your BaseMapper subclass should override updateSObject" userInfo:nil];
}
- (BOOL)shouldFormatWhenAccepting {
	return YES;
}

//////////////////////////////////////////////////////////////////////////////////////
// setup
//////////////////////////////////////////////////////////////////////////////////////
- (void)setSession:(ISyncSession *)ss {
	session = [ss retain];
}

//////////////////////////////////////////////////////////////////////////////////////
// push
//////////////////////////////////////////////////////////////////////////////////////
- (void)pushChangesForSObjects:(NSArray *)src
{
	phase = syncPhasePush;
	NSEnumerator * e = [src objectEnumerator];
	ZKSObject * o;
	while (o = [e nextObject]) {
		// keep track of what we've pushed, later on we can use this as a "reference"
		// copy of what's going on when we pull changes.
		[pushedSObjects setObject:o forKey:[o id]];
		[self pushChangesForSObject:o];
	}
}

//////////////////////////////////////////////////////////////////////////////////////
// pull
//////////////////////////////////////////////////////////////////////////////////////
- (void)topLevelEntityUpdate:(ISyncChange *)change {
	phase = syncPhasePull;
	ZKSObject * o;
	if ([change type] == ISyncChangeTypeModify) {
		// start with the SObject we pushed in
		o = [pushedSObjects objectForKey:[change recordIdentifier]];
	} else {
		o = [ZKSObject withType:[self primarySObject]];
	}
	[self updateSObject:o withChanges:[change record]];
	PulledItem * item = [PulledItem itemForChange:change SObject:o];
	[item setShouldFormatForAccept:[self shouldFormatWhenAccepting]];
	[pulledEntities setObject:item forKey:[change recordIdentifier]];
}

- (BOOL)isChildEntity:(NSString *)appleId
{
	return [self isCompoundKey:appleId];
}

- (void)preprocessChildChanges:(NSMutableArray *)childChanges {
	// no-op, let the actual mappers do something useful if needed.
}

// we've got all the changes we're going to get we need to
//		a) send the changes to salesforce
//		b) accept the changes, passing in a formatted record for the top level entity
//		c) accept the children, passing in the new record ids.
- (void)finish
{
	[self finishChangeType:ISyncChangeTypeModify];
	[self finishChangeType:ISyncChangeTypeAdd];
	[accumulator performDeletes];
}

- (DeleteAccumulator *)deleteAccumulator {
	if (accumulator == nil)
		accumulator = [[DeleteAccumulator alloc] initWithSession:session sforce:sforce];
	return accumulator;
}

- (void)pulledDelete:(NSString *)recordId {
	[[self deleteAccumulator] enqueueDelete:recordId];
}

// returns a new SObject that's a clone of the src SObject with all the read-only fields removed.
- (ZKSObject *)cleanSObjectForWriting:(ZKSObject *)src forUpdate:(BOOL)forUpdate {
	ZKSObject *r;
	if (forUpdate)
		r = [ZKSObject withTypeAndId:[src type] sfId:[src id]];
	else
		r = [ZKSObject withType:[src type]];
	
	ZKDescribeField *f;
	NSEnumerator *e = [[describe fields] objectEnumerator];
	while (f = [e nextObject]) {
		BOOL ok = forUpdate ? [f updateable] : [f createable];
		if (ok) {
			id fieldValue = [src fieldValue:[f name]];
			if (fieldValue != nil) {
				[r setFieldValue:fieldValue field:[f name]];
			} else {
				if ([src isFieldToNull:[f name]]) 
					[r setFieldToNull:[f name]];
			}
		}
	}
	return r;
}

- (NSDictionary *)makeSyncFormattedRecord:(ZKSObject *)src sfId:(NSString *)sfId type:(ISyncChangeType)type {
	return [self makeSyncRecord:src];
}

- (void)updateChangeSummary:(SalesforceChangeSummary *)summary {
	SalesforceObjectChangeSummary *s = [summary changesForEntity:[self primarySalesforceObjectDisplayName]];
	[s incrementDeletes:[accumulator count]];
	int add=0, update=0;
	NSEnumerator *e = [pulledEntities objectEnumerator];
	PulledItem *p;
	while (p = [e nextObject]) {
		if ([p changeType] == ISyncChangeTypeAdd)
			add++;
		else if ([p changeType] == ISyncChangeTypeModify)
			update++;
	}
	[s incrementAdds:add];
	[s incrementUpdates:update];
}

-(void)finishChangeType:(ISyncChangeType)changeType
{
	// save all changes to sfdc
	NSMutableArray * sobjects = [NSMutableArray array];
	NSMutableArray * pitems   = [NSMutableArray array];
	PulledItem * pi;
	NSEnumerator * e = [pulledEntities objectEnumerator];
	while (pi = [e nextObject]) {
		if ([pi changeType] == changeType) {
			[sobjects addObject:[self cleanSObjectForWriting:[pi sobject] forUpdate:changeType == ISyncChangeTypeModify]];
			[pitems addObject:pi];
		} 
	}
	NSArray * results;
	if (changeType == ISyncChangeTypeModify)
		results = [sforce update:sobjects];
	else
		results = [sforce create:sobjects];
		
	UInt32 idx;
	ZKSObject *sobject;
	ZKSaveResult *sr;
	for (idx = 0; idx < [results count]; idx++) {
		pi = [pitems objectAtIndex:idx];
		sobject = [sobjects objectAtIndex:idx];
		sr = [results objectAtIndex:idx];
		if ([sr success]) {
			// build a formatted record from the current sobject
			// we do this before putting the id in the sobject, so that the subclass can make a distinction between formatting existing rows
			// and formatting new rows (iCal for example will ignore the URL in the formatted record if we add it straight away)
			NSDictionary * formated = [pi shouldFormatForAccept] ? [self makeSyncFormattedRecord:sobject sfId:[sr id] type:changeType] : nil;
			// store the id in the sobject for convienience
			[sobject setId:[sr id]];
			// accept the contact change
			if (formated != nil) 
				NSLog(@"formatted record is : %@", formated);
			
			[pi accept:session formattedRecord:formated sfdcId:[sr id]];
		} else {
			// TODO: Salesforce.com didn't accept the create/update for this row, should we explicity reject the change
			// or just leave it dangling, if they edit it again, we want to get another shot at updating the salesforce.com side
			NSLog(@"%@", sr);
		}
	}
}

//////////////////////////////////////////////////////////////////////////////////////
// field mappings
//////////////////////////////////////////////////////////////////////////////////////

// fieldMappings is a dictionary from SfdcFieldName to a FieldMappingInfo (or subclass of)
- (NSMutableDictionary *)mapFromSObject:(ZKSObject *)src toAppleEntityName:(NSString *)entityName {
	// start with an empty dictionary, and set the entityName
	NSMutableDictionary *sync = [NSMutableDictionary dictionary];
	[sync setObject:entityName forKey:key_RecordEntityName];
	// handle all the standard field mappings
	FieldMappingInfo *fm;
	NSEnumerator * e = [fieldMapping objectEnumerator];
	while (fm = [e nextObject]) {
		id typedValue = [fm typedValue:src];
		if ((typedValue != nil) && (typedValue != [NSNull null]))
			[sync setObject:typedValue forKey:[fm syncName]];
	}
	return sync;
}

// revsere mapping of above, update the sobject with the data from sync services
// walks through each fieldMappingInfo and asks it to do the mapping
- (void)mapFromApple:(NSDictionary *)syncData toSObject:(ZKSObject *)s {
	FieldMappingInfo *fm;
	NSEnumerator * e = [fieldMapping objectEnumerator];
	while (fm = [e nextObject]) {
		[fm mapFromApple:syncData toSObject:s];
	}
}


//////////////////////////////////////////////////////////////////////////////////////
// compound keys
//////////////////////////////////////////////////////////////////////////////////////
	
// a compound key that we use for identifying things that are separate records on 
// the iSync side, but are regular properties on the sfdc size
- (NSString *)makeCompoundKey:(NSString *)sfId type:(NSString *)type {
	return [NSString stringWithFormat:@"%@-%@", sfId, type];
}

// is this Id one of our compound Ids ?
- (BOOL)isCompoundKey:(NSString *)cId {
	return ([cId length] > 19) && ([cId characterAtIndex:18] == '-');
}

- (NSString *)compoundKeySfId:(NSString *)k {
	return [k substringToIndex:18];
}

- (NSString *)compoundKeyType:(NSString *)k {
	return [k substringFromIndex:19];
}

//////////////////////////////////////////////////////////////////////////////////////
// general helpers
//////////////////////////////////////////////////////////////////////////////////////

- (void)appendValues:(NSEnumerator *)e dest:(NSMutableString *)dest format:(NSString *)f {
	NSString * k;
	while (k = [e nextObject]) 
		[dest appendFormat:f, k];
}

// TODO, why doesn't this just use [NSString hasPrefix] ?
- (BOOL)stringStartsWith:(NSString *)with src:(NSString *)src {
	if([src length] < [with length]) return NO;
	return [[src substringToIndex:[with length]] isEqualToString:with];
}

@end



