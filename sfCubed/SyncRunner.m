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

#import <SyncServices/SyncServices.h>
#import "SyncRunner.h"
#import "Constants.h"
#import "SyncOptions.h"

#import "zkSforceClient.h"
#import "zkSObject.h"
#import "zkSaveResult.h"
#import "zkUserInfo.h"
#import "zkQueryResult.h"

#import "Mappers.h"
#import "TaskMapper.h"
#import "ContactMapper.h"
#import "BaseMapper.h"
#import "EventMapper.h"

#import "SalesforceObjectChangeSummary.h"
#import "ProtectController.h"

@interface SyncRunner (private)

-(BOOL)runOneSync;
-(void)slowSyncWithMapper:(BaseMapper *)mapper mapperIndex:(int)idx;
-(BOOL)pullChanges;
-(void)sendChangeToSalesforce:(ISyncChange *)change mapper:(BaseMapper *)mapper;

-(void)setStatus:(NSString *)newStatus;
-(void)setStatus2:(NSString *)newStatus;
-(void)setProgress:(double)newProgress;
@end

@implementation SyncRunner

+(ISyncClient *)syncClient {
	ISyncManager *manager = [ISyncManager sharedManager];
	ISyncClient *syncClient;

	NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
	NSString * currentVersionString = [plist objectForKey:@"CFBundleVersion"];
	float currentVersion = currentVersionString == nil ? 0.0f : [currentVersionString floatValue];	
	float lastRegistered = [[NSUserDefaults standardUserDefaults] floatForKey:PREF_VERSION_OF_LAST_REGISTRATION];
	
	// See if our client has already registered
	if ( (currentVersion > lastRegistered) || 
	     (!(syncClient = [manager clientWithIdentifier:@"com.pocketsoap.isync.sfcubed.contacts"])) ) {
		// and if it hasn't, register the client.
		NSLog(@"registering sync client (for sfCubed v%f)", currentVersion);
		NSString *plist = [[NSBundle mainBundle] pathForResource:@"ClientDescription" ofType:@"plist"];
		syncClient = [manager registerClientWithIdentifier:@"com.pocketsoap.isync.sfcubed.contacts" 
							descriptionFilePath:plist];
							
		[[NSUserDefaults standardUserDefaults] setFloat:currentVersion forKey:PREF_VERSION_OF_LAST_REGISTRATION];
	}	
	return syncClient;
}

-(id)initWithSforceSession:(ZKSforceClient *)sfclient {
	self = [super init];
	sforce = [sfclient retain];
	[self setProgress:0];
	[self setStatus:@""];
	[self setStatus2:@""];
	return self;
}

-(void)dealloc {
	[sforce release];
	[session release];
	[mappers release];
	[status release];
	[status2 release];
	[options release];
	[super dealloc];
}

-(void)setOptions:(SyncOptions *)op {
	[options autorelease];
	options = [op retain];
}

-(BOOL)performSync:(SyncOptions *)syncOptions; {
	[self setOptions:syncOptions];
	@try {
		return [self runOneSync];
	}
	@catch (NSException *ex) {
		if (session != nil)
			[session cancelSyncing];
		@throw ex;
	}
	return NO;
}

-(void)enabledDisableEntitiesForSync:(ISyncClient *)client enabled:(NSArray *)shouldBeEnabled {
	NSSet *e = [NSSet setWithArray:shouldBeEnabled];
	NSSet *s = [NSSet setWithArray:[client enabledEntityNames]];
	if ([e isEqualToSet:s])
		return;
	NSSet *all = [NSSet setWithObjects:Entity_Contact, Entity_Email, Entity_Phone, Entity_Address, Entity_Calendar, Entity_Event, Entity_Task, nil];
	NSMutableSet *toDisable = [NSMutableSet setWithSet:all];
	NSEnumerator *em = [e objectEnumerator];
	NSString *entity;
	while (entity = [em nextObject])
		[toDisable removeObject:entity];
	
	NSLog(@"enabledDisableEntitiesForSync: enabling:%@ disabling:%@", toDisable, shouldBeEnabled);
	[client setEnabled:NO forEntityNames:[toDisable allObjects]];
	[client setEnabled:YES forEntityNames:shouldBeEnabled];
}

- (BOOL)runOneSync {
	// check if we can sync
    if ([[ISyncManager sharedManager] isEnabled] == NO) {
		// todo, register for notification of sync getting enabled
		[self setStatus:@"Syncronization Manager is disable (enable from iSync)"];
		return NO;
	}
	
	// get a sync client
	ISyncClient * syncClient = [SyncRunner syncClient];
	if (!syncClient) {
		[self setStatus:@"Unable to register the SfCubed sync client"];
		return NO;
	}

	// mappers
	[sforce setUpdateMru:YES];
	mappers = [[Mappers alloc] initForUserId:[[sforce currentUserInfo] userId]];
	if ([options syncContacts])
		[mappers addMapper:[[[ContactMapper alloc] initMapper:sforce options:options] autorelease]];

	if ([options syncTasks])
		[mappers addMapper:[[[TaskMapper alloc] initMapper:sforce options:options] autorelease]];
	
	if ([options syncEvents])
		[mappers addMapper:[[[EventMapper alloc] initMapper:sforce options:options] autorelease]];
		
	// todo, add additional mappers here
	// todo, should we be adding the mappers, or should Mappers know the list of mappers ?
	if ([mappers count] == 0) {
		[self setStatus:@"Nothing configured to sync!"];
		[mappers release];
		return NO;
	}
	
	// things we want to sync
	NSArray *entityNames = [mappers entityNames];
	NSArray *syncFilters = [mappers filters];
	
	// fix up the enabled entities as needed
	// [self enabledDisableEntitiesForSync:syncClient enabled:entityNames];
	
	// register the filters
	[syncClient setFilters:syncFilters];
		
	// start a sync session
	session = [ISyncSession beginSessionWithClient:syncClient
                entityNames:entityNames
                beforeDate:[NSDate distantFuture]];

	if (!session) {
		[self setStatus:@"unable to start a sync session"];
		[mappers release];
		return NO;
	}
	[mappers setSession:session];
	
	// slow sync always right now
	[session clientWantsToPushAllRecordsForEntityNames:entityNames];	
	// push 
	[self setProgress:5];

	int mapperIdx = 1;
	BaseMapper *mapper;
	NSEnumerator *e = [mappers objectEnumerator];
	while (mapper = [e nextObject]) {
		if ([session shouldPushChangesForEntityName:[mapper primaryMacEntityName]]) {
			// Push records for entityName
			if ([session shouldPushAllRecordsForEntityName:[mapper primaryMacEntityName]]) {
				// Slow sync entityName
				[self slowSyncWithMapper:mapper mapperIndex:mapperIdx];
			} else {
				// Fast sync entityName
			}
		}
		mapperIdx++;
    }
	// push finished
	[mappers pushFinished:[[sforce currentUserInfo] userId]];
	
	BOOL finish = YES;
	if ([session prepareToPullChangesForEntityNames:entityNames beforeDate:[NSDate distantFuture]]) {
		finish = [self pullChanges];
		if (finish)
			[session clientCommittedAcceptedChanges];
		else {
			[self setStatus:@"Synchronization cancelled"];
			[self setStatus2:@""];
		}
	}
	// all done
	if (finish)
		[session finishSyncing];
	[mappers release];
	mappers = nil;
	session = nil;
	return finish;
}

// PUSH changes from Salesforce to SyncServices
- (void)slowSyncWithMapper:(BaseMapper *)mapper mapperIndex:(int)mapperIdx; {
	[self setStatus:[NSString stringWithFormat:@"Synchronizing %@ from Salesforce", [mapper primarySalesforceObjectDisplayName]]];
	ZKQueryResult *sobjects = [sforce query:[mapper soqlQuery]];	
	NSLog(@"query returned %d rows", [sobjects size]);
	[self setStatus2:[NSString stringWithFormat:@"fetched %d %@ from Salesforce.com", [sobjects size], [mapper primarySalesforceObjectDisplayName]]];
	UInt32 pos = 0;
	do {
		[mapper pushChangesForSObjects:[sobjects records]];
		pos += [[sobjects records] count];
		if ([sobjects size] > 0)
			[self setProgress:5 + (pos * 45 * mapperIdx / [mappers count] / [sobjects size])];
		if ([sobjects done] == YES) break;
		sobjects = [sforce queryMore:[sobjects queryLocator]];
	} while(true);
}

// PULL changes from SyncServices to Salesforce
// returns NO if the sync was canceled
- (BOOL)pullChanges {
	[self setStatus:@"Sending local changes to Salesforce.com"];
	[self setStatus2:@""];
		
	BaseMapper * mapper;
	ISyncChange * c;
	int mapperIdx = 1;
	SalesforceChangeSummary *changeSummary = [[[SalesforceChangeSummary alloc] init] autorelease];
	NSEnumerator *mapperenum = [mappers objectEnumerator];
	while (mapper = [mapperenum nextObject]) {
		// we have to get all the changes first to get a good progress indication
		NSEnumerator *e = [session changeEnumeratorForEntityNames:[NSArray arrayWithObject:[mapper primaryMacEntityName]]];
		NSArray *primaryChanges = [e allObjects];
		e = [session changeEnumeratorForEntityNames:[mapper entityNames]];
		NSMutableArray *childChanges = [NSMutableArray arrayWithArray:[e allObjects]];
		UInt totalChanges = [primaryChanges count] + [childChanges count];
		[self setStatus2:[NSString stringWithFormat:@"%d %@ changes recieved", totalChanges, [mapper primarySalesforceObjectDisplayName]]];
		
		UInt pos = 0;
		e = [primaryChanges objectEnumerator];
		while (c = [e nextObject]) {
			[self setProgress:50 + (pos++ *49 * mapperIdx / [mappers count]/totalChanges)];
			NSLog(@"pulled change : %@", c);
			[self sendChangeToSalesforce:c mapper:mapper];
		}

		// Allow the mapper to pre-process the set of child changes (for example by changing an update to a delete/create pair instead)
		[mapper preprocessChildChanges:childChanges];
		
		// sort the child changes by type, so that we can process all the deletes first
		// this is so that changes to child entities, that are flattened into the top
		// level entity in the salesforce side won't loose data (by apply the delete after an add)
		// entourage in particular seems to do the delete/add trick for child entities a lot
		NSSortDescriptor *sortdesc = [[[NSSortDescriptor alloc] initWithKey:@"type" ascending:NO] autorelease];
		NSArray *sortedChildChanges = [childChanges sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortdesc]];
		e = [sortedChildChanges objectEnumerator];
		while (c = [e nextObject]) {
			[self setProgress:50 + (pos++ *49 * mapperIdx / [mappers count]/totalChanges)];
			NSLog(@"pulled change : %@", c);
			[self sendChangeToSalesforce:c mapper:mapper];
		}
		++mapperIdx;
		[mapper updateChangeSummary:changeSummary];
	}

	if ([options shouldShowUserWarningOnSfdcChanges:[changeSummary totalChanges]]) {
		ProtectController *pc = [[[ProtectController alloc] initWithChanges:changeSummary] autorelease];
		if (![pc shouldContinueSync]) {
			[session cancelSyncing];
			return NO;
		}
	}

	mapperenum = [mappers objectEnumerator];
	while (mapper = [mapperenum nextObject]) 
		[mapper finish];
	return YES;
}

- (void)sendChangeToSalesforce:(ISyncChange *)change mapper:(BaseMapper *)mapper {
	if ([change type] == ISyncChangeTypeDelete)
	{
		NSLog(@"delete %@", [change recordIdentifier]);	
		// don't get sent an entityName for delete, so need to work it all out from the Id
		// id, will either be a regular sfdc 18 char Id for main entities, or one of our
		// fandangled compound keys
		NSString * i = [change recordIdentifier];
		if ([mapper isChildEntity:i]) {
			[mapper relationshipUpdate:change];			
		} else {
			// regular delete
			[mapper pulledDelete:i];
		}
	} else {
		NSString * entity = [[change record] objectForKey:key_RecordEntityName];
		NSLog(@"%d : %@ %@", [change type], [change recordIdentifier], [change record]);

		[mapper pulledChange:change entityName:entity];		
	}
}

- (NSString *)status {
	return [[status retain] autorelease];
}

- (NSString *)status2 {
	return [[status2 retain] autorelease];
}

-(double)progress {
	return progress;
}

-(void)setProgress:(double)newProgress {
	progress = newProgress;
}

-(void)setStatus:(NSString *)newStatus {
	if (newStatus == status) return;
	[status release];
	status = [newStatus copy];
}

-(void)setStatus2:(NSString *)newStatus {
	if (newStatus == status2) return;
	[status2 release];
	status2 = [newStatus copy];
}

@end
