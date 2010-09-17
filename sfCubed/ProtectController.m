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

static const float NO_DETAILS_HEIGHT = 335;
static const float SHOW_DETAILS_HEIGHT = 636;

@interface SummaryList : NSObject <NSTableViewDataSource> {
	NSArray *sobjects;
}
@property (retain) NSArray *sobjects;
@end

@interface DetailsList : NSObject<NSTableViewDataSource> {
	ZKSObject *sobject;
	NSArray *keys;
}
-(id)initWithSObject:(ZKSObject *)o;
@end

@implementation SummaryList 

@synthesize sobjects;

-(void)dealloc {
	[sobjects release];
	[super dealloc];
}

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

@implementation DetailsList 

-(void)dealloc {
	[sobject release];
	[keys release];
	[super dealloc];
}

-(id)initWithSObject:(ZKSObject *)o {
	self = [super init];
	sobject = [o retain];
	keys = [[[[sobject fields] allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] retain];
	return self;
}

-(ZKSObject *)sobject {
	return sobject;
}

-(int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [keys count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	NSString *k = [keys objectAtIndex:rowIndex];
	if ([[aTableColumn identifier] isEqualToString:@"label"])
		return k;
	return [sobject fieldValue:k];
}

@end

@implementation ProtectController

-(id)initWithChanges:(SalesforceChangeSummary *)s {
	self = [super init];
	summary = [s retain];
	showingDetails = NO;
	return self;
}

-(void)dealloc {
	[summary release];
	[super dealloc];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
	DetailsList *dl = [[DetailsList alloc] initWithSObject:[[(SummaryList*)[changesListTable dataSource] sobjects] objectAtIndex:row]];
	DetailsList *oldDl = [detailTable dataSource];
	[detailTable setDataSource:dl];
	[oldDl release];
	return YES;
}

-(IBAction)showHideDetails:(id)sender {
	NSRect f = [window frame];
	if (showingDetails) {
		f.origin.y += f.size.height - NO_DETAILS_HEIGHT;
		f.size.height = NO_DETAILS_HEIGHT;
	} else {
		f.origin.y -= SHOW_DETAILS_HEIGHT - f.size.height;
		f.size.height = SHOW_DETAILS_HEIGHT;
	}
	[window setFrame:f display:YES animate:YES];
	[detailTable setEnabled:!showingDetails];
	[changesListTable setEnabled:!showingDetails];
	[self willChangeValueForKey:@"showHideButtonText"];
	showingDetails = !showingDetails;
	[self didChangeValueForKey:@"showHideButtonText"];
}

-(NSString *)showHideButtonText {
	return showingDetails ? @"Hide Details" : @"Show Details";
}

// returns true if the user selected to continue with the sync
-(BOOL)shouldContinueSync {
	[NSBundle loadNibNamed:@"protect.nib" owner:self];
	NSRect f = [window frame];
	f.size.height = NO_DETAILS_HEIGHT;
	[window setFrame:f display:NO];
	
	[summary removeEntitiesWithNoChanges];
	[changesListTable setDelegate:self];
	[summaryTable setDataSource:summary];
	[summaryTable reloadData];
	
	SummaryList *sl = [[SummaryList alloc] init];
	[sl setSobjects:[[[summary changes] objectAtIndex:0] updateDetails]];
	[changesListTable setDataSource:sl];
	//[sl release];
	
	BOOL cont = [NSApp runModalForWindow:window] == NSRunStoppedResponse;
	[window orderOut:self];
	[summaryTable setDelegate:nil];
	[summaryTable setDataSource:nil];
	return cont;
}

-(IBAction)cancelSync:(id)sender {
	[NSApp abortModal];
}

-(IBAction)continueSync:(id)sender {
	[NSApp stopModal];
}

@end
