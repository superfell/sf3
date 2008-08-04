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

#import "Constants.h"
#import <ExceptionHandling/NSExceptionHandler.h>
#import "SyncRunner.h"
#import "SyncOptions.h"

static const int SFC_QUIT = -1;
static const int SFC_GO = 42;

@interface SFCubed (private)
-(void)setProgress:(double)p;
-(void)setStatus:(NSString *)newStatus;
-(void)setStatus2:(NSString *)newStatus;
-(double)progress;
-(NSString *)status;
-(NSString *)status2;
@end 

@implementation SFCubed

+(void)initialize {
	[SFCubed exposeBinding:@"status"];
	[SFCubed exposeBinding:@"status2"];
	[SFCubed exposeBinding:@"progress"];
}

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkShowWelcome:) name:NSApplicationDidFinishLaunchingNotification object:nil];
	[progressIndicator setUsesThreadedAnimation:YES];
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

-(void)checkShowPrefs {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:PREF_SEEN_PREFS]) {
		[self showPrefsWindow:self];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PREF_SEEN_PREFS];
	}
}

- (void)checkShowWelcome:(NSNotification *)n
{
	[mainBox setGradientStartColor:[NSColor colorWithCalibratedRed:0.55 green:0.20 blue:0.10 alpha:0.20]];
	[mainBox setGradientEndColor:[NSColor colorWithCalibratedRed:0.40 green:0.20 blue:0.10 alpha:0.35]];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:PREF_SHOW_WELCOME]) {
		[syncNowMenuItem setEnabled:NO];
		[NSApp beginSheet:welcomeWindow modalForWindow:myWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	} else {
		[self checkShowPrefs];
	}
}

- (IBAction)closeWelcome:(id)sender
{
	[NSApp endSheet:welcomeWindow];
	[welcomeWindow orderOut:self];
	[syncNowMenuItem setEnabled:YES];
	[self checkShowPrefs];
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
	if (login == nil) 
		login = [[ZKLoginController alloc] init];
	
	if (![sforce loggedIn])
		[login showLoginSheet:myWindow target:self selector:@selector(login:)];
	else 
		[self triggerSyncNow:self];
}

- (IBAction)login:(ZKSforceClient *)authenticatedClientStub {
	ZKSforceClient *t = sforce;
	sforce = [authenticatedClientStub retain];
	[t release];
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

- (IBAction)triggerSyncNow:(id)sender {
	[trickleTimer invalidate];
	[trickleTimer release];
	trickleTimer = nil;
	[NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(syncNow:) userInfo:nil repeats:NO];
}

- (BOOL)performSync {
	SyncRunner *runner = [[SyncRunner alloc] initWithSforceSession:sforce];
	[self bind:@"status" toObject:runner withKeyPath:@"status" options:nil];
	[self bind:@"status2" toObject:runner withKeyPath:@"status2" options:nil];
	[self bind:@"progress" toObject:runner withKeyPath:@"progress" options:nil];
	BOOL ok = NO;
	SyncOptions *options = [[[SyncOptions alloc] initFromUserDefaults] autorelease];
	@try {
		ok = [runner performSync:options];
	} @finally {
		[self unbind:@"status"];
		[self unbind:@"status2"];
		[self unbind:@"progress"];
		[runner release];
	}
	if (ok) {
		[self registerForOtherClients:options];
		if ([[NSUserDefaults standardUserDefaults] integerForKey:PREF_AUTO_SYNC_INTERVAL] > 0)
			[self setStatus:@"Synchronization complete, auto sync enabled"];
		else
			[self setStatus:@"Synchronization complete"];
	
		[self setStatus2:@""];	
		[[NSUserDefaults standardUserDefaults] setObject:[NSCalendarDate date] forKey:PREF_LAST_SYNC_DATE];
		[self showLastSyncStatus];
	} 
	return ok;
}

- (IBAction)syncNow:(id)sender
{
	NSString *oldTitle = [mainBox title];
	[syncNowMenuItem setEnabled:FALSE];
	[mainBox setTitle:@"Synchronizing ..."];
	[mainBox display];
	[self setStatus:@"Starting synchronization...."];
	[progressIndicator setDoubleValue:1];
	[progressIndicator startAnimation:self];
	[progressIndicator display];
	BOOL syncCompleted = NO;
	@try {
		syncCompleted = [self performSync];
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
		
	[progressIndicator stopAnimation:self];
	[progressIndicator setDoubleValue:0];
	[progressIndicator display];
	
	int interval = [[NSUserDefaults standardUserDefaults] integerForKey:PREF_AUTO_SYNC_INTERVAL];
	if (syncCompleted && (interval > 0)) {
		trickleTimer = [NSTimer scheduledTimerWithTimeInterval:60*interval target:self selector:@selector(triggerSyncNow:) userInfo:nil repeats:NO];
		[trickleTimer retain];
	}
	[syncNowMenuItem setEnabled:TRUE];
	[mainBox setTitle:oldTitle];
	[mainBox display];
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

-(void)setProgress:(double)p {
	[progressIndicator setDoubleValue:p];
	[progressIndicator display];
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

-(double)progress {
	return [progressIndicator doubleValue];
}

-(NSString *)status {
	return [statusText1 stringValue];
}

-(NSString *)status2 {
	return [statusText2 stringValue];
}

-(void)registerForOtherClients:(SyncOptions *)options {	
	if ((!registeredWithOtherClients) && [options autoJoinSync]) {
		ISyncClient * syncClient = [SyncRunner syncClient];
		[syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeApplication];
		[syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeServer];
		[syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeDevice];
		[syncClient setSyncAlertHandler:self selector:@selector(client:willSyncEntityNames:)];
		registeredWithOtherClients = YES;
	}
}

-(void)client:(ISyncClient *)client willSyncEntityNames:(NSArray *)entityNames {
	NSLog(@"SyncServices is strting sync for Entity Names: %@", entityNames);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:PREF_AUTO_JOIN_SYNC])
		[self syncNow:self];
}
 
-(IBAction)unregisterClient:(id)sender {
	NSAlert * alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Cancel"];
	[alert addButtonWithTitle:@"Reset Sync"];
	[alert setMessageText:@"Reset Sync History ?"];
	[alert setInformativeText:@"This will clear all sync history (but not any data), next time you sync it will be just like the first sync."];
	if (NSAlertFirstButtonReturn != [alert runModal])
		[[ISyncManager sharedManager] unregisterClient:[SyncRunner syncClient]];
}

@end
