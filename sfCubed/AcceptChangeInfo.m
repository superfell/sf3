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

#import "AcceptChangeInfo.h"

@implementation AcceptChangeInfo

+ (AcceptChangeInfo *) acceptInfo:(id)recordId formatted:(id)f newId:(id)nid
{
	AcceptChangeInfo * c = [[AcceptChangeInfo alloc] initAccept:recordId formatted:f newId:nid newIdFormat:nil];
	return [c autorelease];
}

+ (AcceptChangeInfo *) acceptInfoWithIdFormat:(id)recordId formatted:(id)f newIdFormat:(id)nidf
{
	AcceptChangeInfo * c = [[AcceptChangeInfo alloc] initAccept:recordId formatted:f newId:nil newIdFormat:nidf];
	return [c autorelease];
}

- (id) initAccept:(id)rid formatted:(id)f newId:(id)nid newIdFormat:(id)nidf {
	[super init];
	recordId = [rid retain];
	formatted = [f retain];
	newId = [nid retain];
	newIdFormat = [nidf retain];
	isForDelete = NO;
	return self;
}

- (void)dealloc {
	[recordId release];
	[formatted release];
	[newId release];
	[newIdFormat release];
	[super dealloc];
}

- (BOOL)isForDelete {
	return isForDelete;
}

- (void)setIsForDelete:(BOOL)newIsForDelete {
	isForDelete = newIsForDelete;
}

// first phase, if we need to, start the id shuffle, register a new GUID as our recordId, instead
// of the recordId we currently have. We do this if we know we're going to end up with a new
// id we want to register, or for deletes (so that the recordId of the deleted record becomes
// available for another record to use.)
- (void)preAccept:(ISyncSession *)session sfId:(NSString *)sfId {
	if ((newId == nil) && (newIdFormat != nil)) {
		newId = [[NSString stringWithFormat:newIdFormat, sfId] retain];
	}
	if (newId != nil || isForDelete) {
		CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	  	NSString *tempId = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
	  	CFRelease(uuid);
		[session clientChangedRecordIdentifiers:[NSDictionary dictionaryWithObject:tempId forKey:recordId]];
		[recordId release];
		recordId = tempId;
	}
}

- (void)preAccept2:(ISyncSession *)session sfId:(NSString *)sfId {
	if (newId != nil) {
		[session clientChangedRecordIdentifiers:[NSDictionary dictionaryWithObject:newId forKey:recordId]];
		[recordId release];
		recordId = [newId copy];
	}
}

- (void)accept:(ISyncSession*)session {
	[session clientAcceptedChangesForRecordWithIdentifier:recordId formattedRecord:formatted newRecordIdentifier:newId];
}

- (void)reject:(ISyncSession*)session {
	[session clientRefusedChangesForRecordWithIdentifier:recordId];
}

@end