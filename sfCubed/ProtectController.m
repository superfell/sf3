// Copyright (c) 2008 Simon Fell
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

#import "ProtectController.h"
#import "SalesforceObjectChangeSummary.h"
#import "zkSObject.h"

@interface SummaryList : NSObject <NSTableViewDataSource> {
	NSArray *sobjects;
}
@property (retain) NSArray *sobjects;
@end

@implementation SummaryList 

@synthesize sobjects;

-(int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [sobjects count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	ZKSObject *o = [sobjects objectAtIndex:rowIndex];
	if ([[o type] isEqualToString:@"Contact"])
		return [NSString stringWithFormat:@"%@ %@", [o fieldValue:@"FirstName"], [o fieldValue:@"LastName"]];
	return [o fieldValue:@"Subject"];
}
@end

@implementation ProtectController

-(id)initWithChanges:(SalesforceChangeSummary *)s {
	self = [super init];
	summary = [s retain];
	return self;
}

-(void)dealloc {
	[summary release];
	[super dealloc];
}

// returns true if the user selected to continue with the sync
-(BOOL)shouldContinueSync {
	[NSBundle loadNibNamed:@"protect.nib" owner:self];
//	[table setDelegate:self];
	[summary removeEntitiesWithNoChanges];
	[table setDataSource:summary];
	[table reloadData];
	
	SummaryList *sl = [[SummaryList alloc] init];
	[sl setSobjects:[[[summary changes] objectAtIndex:0] updateDetails]];
	[summaryListTable setDataSource:sl];
	//[sl release];
	
	BOOL cont = [NSApp runModalForWindow:window] == NSRunStoppedResponse;
	[window orderOut:self];
	[table setDelegate:nil];
	[table setDataSource:nil];
	return cont;
}

-(IBAction)cancelSync:(id)sender {
	[NSApp abortModal];
}

-(IBAction)continueSync:(id)sender {
	[NSApp stopModal];
}

@end
