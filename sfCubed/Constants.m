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

#import "Constants.h"

// SyncServices entity names
NSString *Entity_Contact = @"com.apple.contacts.Contact";
NSString *Entity_Email   = @"com.apple.contacts.Email Address";
NSString *Entity_Phone   = @"com.apple.contacts.Phone Number";
NSString *Entity_Address = @"com.apple.contacts.Street Address";
NSString *Entity_Task	  = @"com.apple.calendars.Task";
NSString *Entity_Calendar= @"com.apple.calendars.Calendar";
NSString *Entity_Event   = @"com.apple.calendars.Event";

NSString *key_RecordEntityName = @"com.apple.syncservices.RecordEntityName";

// user preferences
NSString *PREF_SEEN_PREFS = @"SEEN_PREFS";
NSString *PREF_SHOW_WELCOME  = @"SHOW_WELCOME";
NSString *PREF_SERVERS = @"servers";
NSString *PREF_SERVER = @"server";

NSString *PREF_SYNC_CONTACTS = @"SYNC_CONTACTS";
NSString *PREF_MY_CONTACTS   = @"MY_CONTACTS";

NSString *PREF_SYNC_TASKS = @"SYNC_TASKS";
NSString *PREF_MY_TASKS   = @"MY_TASKS";
NSString *PREF_SYNC_EVENTS = @"SYNC_EVENTS";
NSString *PREF_MY_EVENTS   = @"MY_EVENTS";

// how often to do auto sync
NSString *PREF_AUTO_SYNC_INTERVAL = @"AUTO_SYNC_INTERVAL";
// do we want to sync when sync services says there's a sync ?
NSString *PREF_AUTO_JOIN_SYNC = @"AUTO_JOIN_SYNC";

// when did we last sync ?
NSString *PREF_LAST_SYNC_DATE = @"LAST_SYNC_DATE";

// what version number were we when we last registered
NSString *PREF_VERSION_OF_LAST_REGISTRATION = @"VERSION_LAST_REGISTERED";

NSString *PREF_CALENDAR_SUFFIX = @"CALENDAR_ID_SUFFIX";

NSString *PREF_ENABLE_PROTECT_SFDC = @"ENABLE_PROTECT_SFDC";
NSString *PREF_PROTECT_SFDC_LIMIT = @"PROTECT_SFDC_LIMIT";

NSString *PREF_ONE_WAY_SYNC = @"ONE_WAY_SYNC";