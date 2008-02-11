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

// This is the main UI Controller class, in addition to managing the various
// UI bit's'peices it also contains the main driver for the sync session
// the later part should be removed from here to a different object.

// Most of the interactions between this class and the UI have us hooked upto
// the various widgets via IB, and we change them directly, this really needs
// reworking to using Cocoa bindings instead.

#import <Cocoa/Cocoa.h>
#import <SyncServices/SyncServices.h>
#import "zkSforceClient.h"
#import "zkSObject.h"
#import "Mappers.h"
#import "SFPrefs.h"
#import "RoundedBox.h"
#import "ZKLoginController.h"

@class DeleteAccumulator;

@interface SFCubed : NSObject {
	IBOutlet RoundedBox 	*mainBox;
	IBOutlet NSWindow 		*welcomeWindow;
	IBOutlet NSButton 		*showWelcomeCheckbox;
	
	IBOutlet NSMenuItem 	*syncNowMenuItem;
	IBOutlet NSMenuItem 	*launchSfdc;

    IBOutlet NSWindow    	*myWindow;
	IBOutlet NSTextField 	*statusText1;
	IBOutlet NSTextField 	*statusText2;
    IBOutlet NSProgressIndicator *progressIndicator;

	IBOutlet NSDrawer	 	*logDrawer;
	IBOutlet NSTextView  	*logTextView;

	IBOutlet NSWindow		*prefsWindow;

	ZKLoginController		*login;
	ZKSforceClient			*sforce;

	NSTimer					*trickleTimer;
	NSURL					*baseUiUrl;
	BOOL 					registeredWithOtherClients;
}

- (void)checkShowWelcome:(NSNotification *)n;
- (IBAction)closeWelcome:(id)sender;

- (IBAction)showPrefsWindow:(id)sender;
- (IBAction)closePrefsWindow:(id)sender;

- (void)showLastSyncStatus;
- (IBAction)toggleLogDrawer:(id)sender;

- (IBAction)showLogin:(id)sender;
- (IBAction)login:(ZKSforceClient *)authenticatedClientStub;

- (IBAction)launchSfdcInBrowser:(id)sender;
- (IBAction)triggerSyncNow:(id)sender;

- (IBAction)syncNow:(id)sender;

- (IBAction)unregisterClient:(id)sender;
- (void)client:(ISyncClient *)client willSyncEntityNames:(NSArray  *)entityNames;
- (void)registerForOtherClients;

@end
