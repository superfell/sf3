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

#import "SFPrefs.h"
#import "Constants.h"

// UserDefaults initialization

@implementation SFPrefs

+ (void)initialize {
	// user defaults
	NSMutableDictionary * defaults = [NSMutableDictionary dictionary];
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:PREF_SYNC_CONTACTS];
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:PREF_MY_CONTACTS];
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:PREF_SYNC_TASKS];
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:PREF_MY_TASKS];
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:PREF_SHOW_WELCOME];
	[defaults setObject:[NSNumber numberWithInt:0]    forKey:PREF_AUTO_SYNC_INTERVAL];
	[defaults setObject:[NSNumber numberWithInt:1]	  forKey:PREF_CALENDAR_SUFFIX];
	[defaults setObject:[NSNumber numberWithInt:0]    forKey:PREF_PROTECT_SFDC_LIMIT];
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:PREF_ENABLE_PROTECT_SFDC];
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:PREF_AUTO_JOIN_SYNC];
	
	NSString *prod = @"https://www.salesforce.com";
	NSString *test = @"https://test.salesforce.com";
	NSArray *servers = [NSArray arrayWithObjects:prod, test, nil];
	[defaults setObject:servers forKey:PREF_SERVERS];
	[defaults setObject:prod forKey:PREF_SERVER];

	// register app defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

@end
