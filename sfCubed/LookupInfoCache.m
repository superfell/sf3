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

#import "LookupInfoCache.h"

@implementation LookupInfoCache

+(LookupInfoCache *)cacheForSObject:(NSString *)soType fields:(NSString *)fields sforce:(ZKSforceClient *)sf {
	return [[[LookupInfoCache alloc] initForSObject:soType fields:fields sforce:sf] autorelease];
}

-(id)initForSObject:(NSString *)soType fields:(NSString *)fields sforce:(ZKSforceClient *)sf {
	self = [super init];
	sobjectType = [soType retain];
	fieldList = [fields retain];
	fetchedObjects = [[NSMutableDictionary alloc] init];
	sforce = [sf retain];
	return self;
}

- (void)dealloc {
	[sobjectType release];
	[fieldList release];
	[fetchedObjects release];
	[sforce release];
	[super dealloc];
}

- (void)fetchNow:(NSString *)sfid {
	[fetchedObjects addEntriesFromDictionary:[sforce retrieve:fieldList sobject:sobjectType ids:[NSArray arrayWithObject:sfid]]];
}

- (id)findEntry:(NSString *)sfId {
	return [fetchedObjects objectForKey:sfId];
}

- (id)findOrFetchEntry:(NSString *)sfId {
	if (sfId == nil) return nil;
	id entry= [self findEntry:sfId];
	if (entry != nil) return entry;
	[self fetchNow:sfId];
	return [self findEntry:sfId];
}

- (NSArray *) allFetchedObjects {
	return [fetchedObjects allValues];
}

- (void)addEntry:(id)entry forId:(NSString *)sfId {
	[fetchedObjects setObject:entry forKey:sfId];
}

@end
