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

// we have one calendarTracker per sync session, if we're syncing both
// events & tasks, its shared across the 2 *Mapper classes

@interface CalendarTracker : NSObject {
	NSMutableArray *events;
	NSMutableArray *tasks;
	NSString	   *calendarId;
	NSString	   *userId;
	int				currentIdSuffix;
}

-(id)initForUserId:(NSString *)uid;
-(void)addEvent:(NSString *)eventId;
-(void)addTask:(NSString *)taskId;
-(void)incrementIdSuffix;
- (NSString *)calendarId;
- (NSString *)calendarIdOrDefault;
- (void)setCalendarId:(NSString *)aCalendarId;

-(NSDictionary *)asSyncObjectUsingSession:(ISyncSession *)s;

@end
