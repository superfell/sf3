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

#import <Cocoa/Cocoa.h>
#import <SyncServices/SyncServices.h>
#import "zkSforceClient.h"
#import "zkDescribeSObject.h"
#import "deleteAccumulator.h"

@class SyncOptions;

// where we at ?
typedef enum SyncMapperPhase {
	syncPhaseSetup,
	syncPhasePush,
	syncPhasePull
} SyncMapperPhase;

// this is the common base class for handling the mapping between a salesforce.com entity and the mapped sync services entity(s)
// The SFCubed class drives the main process, these guys do all of the entity specific work, they try and defer field specific
// oddities to a fieldMapper (not everything is switched over to field mappers yet)
@interface BaseMapper : NSObject {
	NSDictionary		*fieldMapping;
	ISyncSession		*session;
	ZKSforceClient		*sforce;
	DeleteAccumulator	*accumulator;
	
	NSMutableDictionary *pulledEntities;
	NSMutableDictionary *pushedSObjects;
	ZKDescribeSObject	*describe;
	SyncMapperPhase		phase;
	SyncOptions			*options;
}

-(id)initWithClient:(ZKSforceClient *)client andOptions:(SyncOptions *)options;

// init
- (void)setSession:(ISyncSession *)ss;
- (void)setAccumulator:(DeleteAccumulator *)acc;

// what you implement in a subclass

// basic info about your mapping we care about
- (NSArray *)entityNames;							// apple entity names that we want to sync
- (NSArray *)filters;								// sync services filters we want to apply
- (NSString *)primarySalesforceObjectDisplayName;	// the user facing name of the sfdc object being sync'd
- (NSString *)primarySObject;						// the sObject name of the sfdc object being sync'd
- (NSString *)primaryMacEntityName;					// the primary entity name on the sync services side

// push
- (NSString *)soqlQuery;							// return the soql query that represents the data you want to sync from salesforce
- (void)pushChangesForSObject:(ZKSObject *)src;		// push the change(s) for this sobject, should use makeSyncRecord to build the sync record
- (NSDictionary *)makeSyncRecord:(ZKSObject *)src;	// build a top level sync record from this sObject

// pull
- (void)preprocessChildChanges:(NSMutableArray *)childChanges;				// because of the mismatch in data models, particularly with contacts, we have
																			// to do some up front work on child changes before doing the main entity
- (void)pulledChange:(ISyncChange *)change entityName:(NSString *)entity;	// we pulled this change from sync Services
- (void)relationshipUpdate:(ISyncChange *)change;							// called when a child entity that's mapped is pull'd
- (void)updateSObject:(ZKSObject *)o withChanges:(NSDictionary *)syncData;	// update this sObject with the data from sync services
- (BOOL)shouldFormatWhenAccepting;											// defaults to yes, you can override this if you need to
																			// if you don't format when accepting, then be aware that this can lead
																			// to data loss if the sync service record has more children than we
																			// can support on the sfdc side.
// base class pre-canned implementation
// push impl
- (void)pushChangesForSObjects:(NSArray *)src;

// pull impl
- (BOOL)isChildEntity:(NSString *)appleId;
- (void)topLevelEntityUpdate:(ISyncChange *)change;
- (void)finish;
- (void)finishChangeType:(ISyncChangeType)changeType;
- (ZKSObject *)cleanSObjectForWriting:(ZKSObject *)src forUpdate:(BOOL)forUpdate;
- (NSDictionary *)makeSyncFormattedRecord:(ZKSObject *)src sfId:(NSString *)sfId type:(ISyncChangeType)type;

// conversion helpers
- (NSMutableDictionary *)mapFromSObject:(ZKSObject *)src toAppleEntityName:(NSString *)entityName;
- (void)mapFromApple:(NSDictionary *)syncData toSObject:(ZKSObject *)o;

// compound key helpers
- (NSString *)makeCompoundKey:(NSString *)sfId type:(NSString *)type;
- (BOOL)isCompoundKey:(NSString *)cId;
- (NSString *)compoundKeySfId:(NSString *)k;
- (NSString *)compoundKeyType:(NSString *)k;

// general
- (BOOL)stringStartsWith:(NSString *)with src:(NSString *)src;
- (void)appendValues:(NSEnumerator *)e dest:(NSMutableString *)dest format:(NSString *)f;

@end



