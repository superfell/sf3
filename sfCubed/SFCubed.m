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

#import "SFCubed.h"
#import "zkSforceClient.h"
#import "zkSObject.h"
#import "zkSaveResult.h"
#import "zkUserInfo.h"
#import "zkQueryResult.h"
#import "Constants.h"
#import "TaskMapper.h"
#import "ContactMapper.h"
#import "Mappers.h"
#import "BaseMapper.h"
#import "EventMapper.h"
#import "deleteAccumulator.h"
#import <ExceptionHandling/NSExceptionHandler.h>


static const int SFC_QUIT = -1;
static const int SFC_GO = 42;

@implementation SFCubed

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkShowWelcome:) name:NSApplicationDidFinishLaunchingNotification object:nil];
	[progress setUsesThreadedAnimation:YES];
	[syncNowMenuItem setEnabled:FALSE];
	[launchSfdc setEnabled:FALSE];
	registeredWithOtherClients = NO;
	[statusText1 setBordered:FALSE];
	[statusText2 setBordered:FALSE];
	[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
	[self showLastSyncStatus];
	[self setStatus:@"Click the logo button on the left to start"]; 
}

- (void)dealloc 
{
	[sforce release];
	[baseUiUrl release];
	[login release];
	[super dealloc];
}

- (void)printStackTrace:(NSException *)e 
{
    NSString *stack = [[e userInfo] objectForKey:NSStackTraceKey];
    if (stack) {
        NSTask *ls = [[NSTask alloc] init];
        NSString *pid = [[NSNumber numberWithInt:[[NSProcessInfo processInfo] processIdentifier]] stringValue];
        NSMutableArray *args = [NSMutableArray arrayWithCapacity:20];
 
        [args addObject:@"-p"];
        [args addObject:pid];
        [args addObjectsFromArray:[stack componentsSeparatedByString:@"  "]];
        // Note: function addresses are separated by double spaces, not a single space.
       	[ls setLaunchPath:@"/usr/bin/atos"];
        [ls setArguments:args];
        [ls launch];
        [ls release];
 
    } else {
        NSLog(@"No stack trace available.");
    }
}

- (IBAction)toggleLogDrawer:(id)sender
{
	[logDrawer toggle:sender];
}

- (void)checkShowWelcome:(NSNotification *)n
{
	[mainBox setGradientStartColor:[NSColor colorWithCalibratedRed:0.55 green:0.20 blue:0.10 alpha:0.20]];
	[mainBox setGradientEndColor:[NSColor colorWithCalibratedRed:0.40 green:0.20 blue:0.10 alpha:0.35]];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:PREF_SHOW_WELCOME]) {
		[syncNowMenuItem setEnabled:NO];
		[NSApp beginSheet:welcomeWindow modalForWindow:myWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	}
}

- (IBAction)closeWelcome:(id)sender
{
	[NSApp endSheet:welcomeWindow];
	[welcomeWindow orderOut:self];
	[syncNowMenuItem setEnabled:YES];
}

- (IBAction)showPrefsWindow:(id)sender
{
	[NSApp beginSheet:prefsWindow modalForWindow:myWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

- (IBAction)closePrefsWindow:(id)sender
{
	[NSApp endSheet:prefsWindow];
	[prefsWindow orderOut:self];
}

- (IBAction)showLogin:(id)sender
{
	if (login == nil) {
		login = [[ZKLoginController alloc] init];
	}
	if (![sforce loggedIn])
		[login showLoginSheet:myWindow target:self selector:@selector(login:)];
	else 
		[self triggerSyncNow:self];
}

- (IBAction)login:(ZKSforceClient *)authenticatedClientStub
{
	[sforce release];
	sforce = [authenticatedClientStub retain];
	ZKDescribeSObject *d = [sforce describeSObject:@"Task"];
	NSString *sUrl = [d urlNew];
	NSURL *url = [NSURL URLWithString:sUrl];
	baseUiUrl = [[NSURL URLWithString:@"/" relativeToURL:url] retain];
	[syncNowMenuItem setEnabled:YES];
	[self triggerSyncNow:self];
}

- (IBAction)launchSfdcInBrowser:(id)sender
{
	NSURL * fd = [NSURL URLWithString:[NSString stringWithFormat:@"/secur/frontdoor.jsp?sid=%@", [sforce sessionId]] relativeToURL:baseUiUrl];
	[[NSWorkspace sharedWorkspace] openURL:fd];
}

- (IBAction)triggerSyncNow:(id)sender
{
	[trickleTimer invalidate];
	[trickleTimer release];
	trickleTimer = nil;
	[NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(syncNow:) userInfo:nil repeats:NO];
}

- (IBAction)syncNow:(id)sender
{
	NSString *oldTitle = [mainBox title];
	[mainBox setTitle:@"Synchronizing ..."];
	[mainBox display];
	[syncNowMenuItem setEnabled:FALSE];
	[self setStatus:@"Starting synchronization...."];
	[progress setDoubleValue:1];
	[progress startAnimation:self];
	[progress display];
	
	@try {
		[self performSync];
	}
	@catch (NSException *ex) {
		[self printStackTrace:ex];
		NSAlert * alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"Ok"];
		[alert setMessageText:@"Error occurred during sync process"];
		[alert setInformativeText:[ex reason]];
		[alert runModal];
		[alert release];
		[self setStatus:[ex reason]];
	}

	if (session != nil)
		[session cancelSyncing];
		
	[progress stopAnimation:self];
	[progress setDoubleValue:0];
	[progress display];
	
	int interval = [[NSUserDefaults standardUserDefaults] integerForKey:PREF_AUTO_SYNC_INTERVAL];
	if (interval > 0) {
		trickleTimer = [NSTimer scheduledTimerWithTimeInterval:60*interval target:self selector:@selector(triggerSyncNow:) userInfo:nil repeats:NO];
		[trickleTimer retain];
	}
	[syncNowMenuItem setEnabled:TRUE];
	[mainBox setTitle:oldTitle];
	[mainBox display];
}

- (void)performSync
{
	// check if we can sync
    if ([[ISyncManager sharedManager] isEnabled] == NO) {
		// todo, register for notification of sync getting enabled
		[self setStatus:@"Syncronization Manager is disable (enable from iSync)"];
		return;
	}
	
	// get a sync client
	ISyncClient * syncClient = [self registerClient];
	if (!syncClient) {
		[self setStatus:@"Unable to register the SfCubed sync client"];
		return;
	}

	// mappers
	[sforce setUpdateMru:YES];
	mappers = [[Mappers alloc] initForUserId:[[sforce currentUserInfo] userId]];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:PREF_SYNC_CONTACTS])
		[mappers addMapper:[[[ContactMapper alloc] initMapper:sforce] autorelease]];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:PREF_SYNC_TASKS])
		[mappers addMapper:[[[TaskMapper alloc]    initMapper:sforce] autorelease]];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:PREF_SYNC_EVENTS])
		[mappers addMapper:[[[EventMapper alloc]	initMapper:sforce] autorelease]];
		
	// todo, add additional mappers here
	// todo, should we be adding the mappers, or should Mappers know the list of mappers ?
	if ([mappers count] == 0) {
		[self setStatus:@"Nothing configured to sync!"];
		[mappers release];
		return;
	}
	
	// things we want to sync
	NSArray *entityNames = [mappers entityNames];
	NSArray *syncFilters = [mappers filters];
	
	// register the filters
	[syncClient setFilters:syncFilters];
		
	// start a sync session
	session = [ISyncSession beginSessionWithClient:syncClient
                entityNames:entityNames
                beforeDate:[NSDate dateWithTimeIntervalSinceNow:25]];

	if (!session) {
		[self setStatus:@"unable to start a sync session"];
		[mappers release];
		return;
	}
	[mappers setSession:session];
	
	// slow sync always right now
	[session clientWantsToPushAllRecordsForEntityNames:entityNames];	
	// push 
	[progress setDoubleValue:5];
	int mapperIdx = 1;
	BaseMapper * mapper;
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
	
	if ([session prepareToPullChangesForEntityNames:entityNames beforeDate:[NSDate dateWithTimeIntervalSinceNow:30]]) {
		[self pullChanges];
	}
	// all done
	[session clientCommittedAcceptedChanges];
	[session finishSyncing];
	[mappers release];
	mappers = nil;
	session = nil;
	[self registerForOtherClients];
	if ([[NSUserDefaults standardUserDefaults] integerForKey:PREF_AUTO_SYNC_INTERVAL] > 0)
		[self setStatus:@"Syncronization complete, auto sync enabled"];
	else
		[self setStatus:@"Syncronization complete"];
		
	[self setStatus2:@""];	
	[[NSUserDefaults standardUserDefaults] setObject:[NSCalendarDate date] forKey:PREF_LAST_SYNC_DATE];
	[self showLastSyncStatus];
}

- (void)showLastSyncStatus
{
	NSCalendarDate * lastSync = [[NSUserDefaults standardUserDefaults] objectForKey:PREF_LAST_SYNC_DATE];
	if (lastSync != nil) {
		NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
		[statusText2 setStringValue:[NSString stringWithFormat:@"Last Sync : %@", [dateFormatter stringFromDate:lastSync]]];
	} else {
		[statusText2 setStringValue:@"Last Sync : None"];
	}
}

- (void)slowSyncWithMapper:(BaseMapper *)mapper mapperIndex:(int)mapperIdx;
{
	[self setStatus:[NSString stringWithFormat:@"Synchronizing %@ from Salesforce", [mapper primarySalesforceObjectDisplayName]]];
	ZKQueryResult * sobjects = [sforce query:[mapper soqlQuery]];	
	NSLog(@"query returned %d rows", [sobjects size]);
	[self setStatus2:[NSString stringWithFormat:@"fetched %d %@ from Salesforce.com", [sobjects size], [mapper primarySalesforceObjectDisplayName]]];
	UInt32 pos = 0;
	do 
	{
		[mapper pushChangesForSObjects:[sobjects records]];
		pos += [[sobjects records] count];
		if ([sobjects size] > 0)
			[progress setDoubleValue:5 + (pos * 45 * mapperIdx / [mappers count] / [sobjects size])];
		if ([sobjects done] == YES) break;
		sobjects = [sforce queryMore:[sobjects queryLocator]];
	} while(true);
}

- (void)pullChanges {
	// pull
	[self setStatus:@"Sending local changes to Salesforce.com"];
	[self setStatus2:@""];
	DeleteAccumulator * acc = [[DeleteAccumulator alloc] initWithSession:session sforce:sforce];
	[mappers setAccumulator:acc];
		
	BaseMapper * mapper;
	ISyncChange * c;
	int mapperIdx = 1;
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
			[progress setDoubleValue:50 + (pos++ *49 * mapperIdx / [mappers count]/totalChanges)];
			NSLog(@"pulled change : %@", c);
			[self sendChangeToSalesforce:c accumulator:acc mapper:mapper];
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
			[progress setDoubleValue:50 + (pos++ *49 * mapperIdx / [mappers count]/totalChanges)];
			NSLog(@"pulled change : %@", c);
			[self sendChangeToSalesforce:c accumulator:acc mapper:mapper];
		}
		[mapper finish];
		++mapperIdx;
	}
	[acc flush];
	[acc release];
}

- (void)sendChangeToSalesforce:(ISyncChange *)change accumulator:(DeleteAccumulator *)acc mapper:(BaseMapper *)mapper
{
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
			[acc enqueueDelete:[change recordIdentifier]];
		}
	} else {
		NSString * entity = [[change record] objectForKey:key_RecordEntityName];
		NSLog(@"%d : %@ %@", [change type], [change recordIdentifier], [change record]);

		[mapper pulledChange:change entityName:entity];		
	}
}

- (void)setStatus:(NSString *)newStatus
{
	[statusText1 setStringValue:newStatus];
	NSString * sl = [NSString stringWithFormat:@"%@\r\n", newStatus];
	[[logTextView textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:sl] autorelease]];
	[logTextView scrollPageDown:self];
	[logTextView display];
	[statusText1 display];
}

- (void)setStatus2:(NSString *)newStatus
{
	[statusText2 setStringValue:newStatus];
	[statusText2 display];
}

- (ISyncClient *)registerClient {
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

- (void)registerForOtherClients
{	
	if (!registeredWithOtherClients)
	{
		ISyncClient * syncClient = [self registerClient];
		[syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeApplication];
		[syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeServer];
		[syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeDevice];
		[syncClient setSyncAlertHandler:self selector:@selector(client:willSyncEntityNames:)];
		registeredWithOtherClients = YES;
	}
}

- (void)client:(ISyncClient *)client willSyncEntityNames:(NSArray  *)entityNames
{
	NSLog(@"client:%@ will Sync Entity Names: %@", [client displayName], entityNames);
	[self syncNow:self];
}
 
- (IBAction)unregisterClient:(id)sender
{
	NSAlert * alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"Cancel"];
	[alert addButtonWithTitle:@"Reset Sync"];
	[alert setMessageText:@"Reset Sync History ?"];
	[alert setInformativeText:@"This will clear all sync history (but not any data), next time you sync it will be just like the first sync."];
	NSLog(@"runModal %d", [alert runModal]);
	[alert release];
	[[ISyncManager sharedManager] unregisterClient:[self registerClient]];
}


@end
