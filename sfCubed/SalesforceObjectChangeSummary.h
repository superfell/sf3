//
//  SalesforceObjectChangeSummary.h
//  sfCubed
//
//  Created by Simon Fell on 6/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// tracks data about changes we're planning to make to salesforce.com
@interface SalesforceObjectChangeSummary : NSObject {
	NSString	*entityName;
	NSString	*entitylabel;
	int			adds;
	int			updates;
	int			deletes;
}

-(void)incrementAdds:(int)num;
-(void)incrementUpdates:(int)num;
-(void)incrementDeletes:(int)num;

-(NSNumber *)adds;
-(NSNumber *)deletes;
-(NSNumber *)updates;

-(NSString *)entityName;
-(NSString *)entityLabel;

@end

// summary data about the set of entities we're planning to change in salesforce.com
@interface SalesforceChangeSummary : NSObject {
	NSMutableDictionary *changes;
}

-(SalesforceObjectChangeSummary *)changesForEntity:(NSString *)entityName;

@end