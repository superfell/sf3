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

#import "ContactMapper.h"
#import "Constants.h"
#import "SyncFilters.h"
#import "FieldMappingInfo.h"
#import "zkSObject.h"
#import "zkSaveResult.h"
#import "zkQueryResult.h"
#import "zkUserInfo.h"
#import "AcceptChangeInfo.h"
#import "MyISyncChange.h"

@implementation ContactMapper

+ (NSDictionary *)supportedPhoneTypes
{
	// mapping between phone type (apple) and fieldName (sfdc)
	NSMutableDictionary *mapping = [[NSMutableDictionary alloc] init];
	[mapping setObject:@"work"     forKey:@"Phone"];
	[mapping setObject:@"home"     forKey:@"HomePhone"];
	[mapping setObject:@"mobile"   forKey:@"MobilePhone"];
	[mapping setObject:@"work fax" forKey:@"Fax"];
	return [mapping autorelease];
}

- (ContactMapper *)initMapper:(ZKSforceClient *)sf
{
	self = [super init];
	sforce = [sf retain];

	NSMutableDictionary * mapping = [[NSMutableDictionary alloc] init];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"first name"	sfdcName:@"FirstName"	 type:syncFieldTypeString] autorelease]  forKey:@"FirstName"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"last name"		sfdcName:@"LastName"	 type:syncFieldTypeString] autorelease]  forKey:@"LastName"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"job title"		sfdcName:@"Title"		 type:syncFieldTypeString] autorelease]  forKey:@"Title"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"department"	sfdcName:@"Department"	 type:syncFieldTypeString] autorelease]  forKey:@"Department"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"notes"			sfdcName:@"Description"	 type:syncFieldTypeString] autorelease]  forKey:@"Description"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"title"			sfdcName:@"Salutation"	 type:syncFieldTypeString] autorelease]  forKey:@"Salutation"];
	[mapping setObject:[[[FieldMappingInfo alloc] initWithInfo:@"birthday"		sfdcName:@"Birthdate"	 type:syncFieldTypeDate]   autorelease]  forKey:@"Birthdate"];
	fieldMapping = mapping;	

	phoneMappings = [[ContactMapper supportedPhoneTypes] retain];
	// mappings between address parts
	mapping = [[NSMutableDictionary alloc] init];
	[mapping setObject:@"street"		forKey:@"Street"];
	[mapping setObject:@"city"			forKey:@"City"];
	[mapping setObject:@"state"			forKey:@"State"];
	[mapping setObject:@"country"		forKey:@"Country"];
	[mapping setObject:@"postal code"	forKey:@"PostalCode"];
	addressParts = mapping;

	// address type mappings (on the salesforce.com side, the mapped name become a prefix of the field name
	// e.g. MailingStreet, MailingCity, MailingState etc.
	mapping = [[NSMutableDictionary alloc] init];
	[mapping setObject:@"work"		forKey:@"Mailing"];
	[mapping setObject:@"home"		forKey:@"Other"];
	addressMappings = mapping;
	
	accountLookup = [LookupInfoCache cacheForSObject:@"Account" fields:@"id, name" sforce:sforce];
	accountNameToIds = nil;

	describe = [[sforce describeSObject:@"Contact"] retain];
	duplicatedRecordIds = [[NSMutableSet set] retain];
	return self;
}

- (void)dealloc
{
	[phoneMappings release];
	[addressParts  release];
	[addressMappings release];
	[accountNameToIds release];
	[duplicatedRecordIds release];
	[super dealloc];
}

// the list of sync entities we care about
- (NSArray *)entityNames
{
	return [NSArray arrayWithObjects:Entity_Contact, Entity_Email, Entity_Phone, Entity_Address, nil];
}

// the set of filters we want to apply
- (NSArray *)filters
{
	CompanySyncFilter *cf = [[[CompanySyncFilter alloc] init] autorelease];
	EmailSyncFilter *f =	[[[EmailSyncFilter alloc] init] autorelease];
	PhoneSyncFilter *p =	[[[PhoneSyncFilter alloc] init] autorelease];
	AddressSyncFilter *a =	[[[AddressSyncFilter alloc] init] autorelease];
	return [NSArray arrayWithObjects:cf, f, p, a, nil];
}

- (NSString *)primarySalesforceObjectDisplayName
{
	return @"Contacts";
}

- (NSString *)primarySObject
{
	return @"Contact";
}

- (NSString *)primaryMacEntityName
{
	return Entity_Contact;
}

// builds the SOQL query from the Mapping dictionaries
- (NSString *)soqlQuery
{
	// accountId and account.id are the same thing, we select both versions for concience
	NSMutableString * soql = [NSMutableString stringWithString:@"select id, AccountId, account.id, account.name, email"];
	// additional fields based on field mappings
	[self appendValues:[fieldMapping  keyEnumerator] dest:soql format:@", %@"];
	// additional fields from the phone mappings
	[self appendValues:[phoneMappings keyEnumerator] dest:soql format:@", %@"];
	// additional fields for the address type/parts mappings
	NSString * prefix;
	NSEnumerator *e = [addressMappings keyEnumerator];
	while (prefix = [e nextObject]) {
		[self appendValues:[addressParts  keyEnumerator] dest:soql format:[NSString stringWithFormat:@", %@%%@", prefix]];
	}
	[soql appendString:@" from contact"];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:PREF_MY_CONTACTS]) 
		[soql appendFormat:@" where ownerId='%@'", [[sforce currentUserInfo] userId]];
	NSLog(@"soql : %@", soql);
	return soql;
}

// takes the field data from an SObject, and maps it into a sync record dictionary
// this will populate the relationships, but not generated the related records.
- (NSDictionary *)makeSyncRecord:(ZKSObject *)src sfId:(NSString *)sfId 
{
	// start with the easy base fields stuff
	NSMutableDictionary * c = [self mapFromSObject:src toAppleEntityName:Entity_Contact];

	// account.name -> company 
	if ([[src fieldValue:@"AccountId"] length] > 0) {
		ZKSObject *account = [src fieldValue:@"Account"];
		// for push we'll have the account info from the query, but during pull
		// we might not have the relevant account record, or it might be a new
		// account that needs creating as well.
		if (account == nil)
			account = [accountLookup findOrFetchEntry:[src fieldValue:@"AccountId"]];
		[c setObject:[account fieldValue:@"Name"] forKey:@"company name"];
	}

	// add child relationships
	// email, we only track the one
	NSString * emailAddr = [src fieldValue:@"Email"];
	if ([emailAddr length] > 0) {
		[c setObject:[NSArray arrayWithObject:[self makeCompoundKey:sfId type:@"Email"]] forKey:@"email addresses"];
	}
	// phones
	NSMutableArray *phones = [NSMutableArray arrayWithCapacity:[phoneMappings count]];
	NSEnumerator *e = [phoneMappings keyEnumerator];
	NSString *sfdcName;
	while (sfdcName = [e nextObject]) 
	{
		NSString * val = [src fieldValue:sfdcName];
		if ([val length] > 0)
			[phones addObject:[self makeCompoundKey:sfId type:sfdcName]];
	}
	if ([phones count] > 0)
		[c setObject:phones forKey:@"phone numbers"];
		
	// addresses
	NSMutableArray * addresses = [NSMutableArray arrayWithCapacity:[addressMappings count]];
	e = [addressMappings keyEnumerator];
	NSString * prefix;
	while (prefix = [e nextObject]) {
		if ([self hasAnyAddressField:src addressPrefix:prefix])
			[addresses addObject:[self makeAddressKey:sfId prefix:prefix]];
	}
	if ([addresses count] > 0)
		[c setObject:addresses forKey:@"street addresses"];
		
	return c;
}

- (NSDictionary *)makeSyncRecord:(ZKSObject *)src {
	return [self makeSyncRecord:src sfId:[src id]];
}

- (NSDictionary *)makeSyncFormattedRecord:(ZKSObject *)src sfId:(NSString *)sfId type:(ISyncChangeType)type {
	return [self makeSyncRecord:src sfId:sfId];
}

- (NSString *)makeAddressKey:(NSString *)Id prefix:(NSString *)prefix {
	return [self makeCompoundKey:Id type:[NSString stringWithFormat:@"Address%@", prefix]];
}

// make a simple related record, that just has a type and value (such as phone or email) and sets up its parent relationship to the contact
- (NSMutableDictionary *)makeRelatedRecordOfType:(NSString *)entityName type:(NSString *)appleType value:(NSString *)value sfdcId:(NSString *)sfdcId {
	NSMutableDictionary * e = [NSMutableDictionary dictionary];
	[e setObject:entityName forKey:key_RecordEntityName];
	[e setObject:appleType forKey:@"type"];
	if (value != nil)
		[e setObject:value forKey:@"value"];
	[e setObject:[NSArray arrayWithObject:sfdcId] forKey:@"contact"];
	return e;
}

// helpers for the various type of child related records 
- (NSDictionary *)makeSyncEmailRecord:(ZKSObject *)src {
	return [self makeRelatedRecordOfType:Entity_Email type:@"work" value:[src fieldValue:@"Email"] sfdcId:[src id]];
}

- (NSDictionary *)makeSyncPhoneRecord:(ZKSObject *)src sfdcField:(NSString *)sfdcField {
	return [self makeRelatedRecordOfType:Entity_Phone type:[phoneMappings objectForKey:sfdcField] value:[src fieldValue:sfdcField] sfdcId:[src id]];
}

- (NSDictionary *)makeSyncAddressRecord:(ZKSObject *)src prefix:(NSString *)prefix appleType:(NSString *)appleType {
	NSMutableDictionary * a = [self makeRelatedRecordOfType:Entity_Address type:appleType  value:nil sfdcId:[src id]];
	NSString * fn;
	NSEnumerator * e = [addressParts keyEnumerator];
	while (fn = [e nextObject]) {
		NSString * v = [src fieldValue:[NSString stringWithFormat:@"%@%@", prefix, fn]];
		if ([v length] >0)
			[a setObject:v forKey:[addressParts objectForKey:fn]];
	}
	return a;
}

- (BOOL)hasAnyAddressField:(ZKSObject *)src addressPrefix:(NSString *)prefix {
	NSString * f;
	NSEnumerator * e = [addressParts keyEnumerator];
	while (f = [e nextObject]) {
		if ([[src fieldValue:[NSString stringWithFormat:@"%@%@", prefix, f]] length] > 0)
			return YES;
	}
	return NO;
}

// this gets call multiple times by the SFCubed class to push a set of contacts to the sync session
// we like to get them in bulk so we can batch lookup the account names (which we do via the 
// accountLookup LookupInfoCache object
//
- (void)pushChangesForSObjects:(NSArray *)sobjects {
	// build up the mapping of account Ids & names
	ZKSObject * o;
	NSEnumerator * e = [sobjects objectEnumerator];
	while (o = [e nextObject]) {
		id acc = [o fieldValue:@"Account"];
		if (acc == nil || acc == [NSNull null]) continue;
		[accountLookup addEntry:acc forId:[acc id]];
	}
	// now push all the changes, which'll end up calling pushChangesForSObject below
	[super pushChangesForSObjects:sobjects];
}

- (void)pushChangesForSObject:(ZKSObject *)src
{
	NSDictionary * contact = [self makeSyncRecord:src];
	[session pushChangesFromRecord:contact withIdentifier:[src id]];

	// push email child if there is one
	if([[src fieldValue:@"Email"] length] > 0) {
		NSDictionary * email = [self makeSyncEmailRecord:src];
		[session pushChangesFromRecord:email withIdentifier:[self makeCompoundKey:[src id] type:@"Email"]];
	}

	// push phones child objects
	NSString * sfdcName;
	NSEnumerator * e = [phoneMappings keyEnumerator];
	while (sfdcName = [e nextObject]) {
		if([[src fieldValue:sfdcName] length] > 0) {
			NSDictionary * phone = [self makeSyncPhoneRecord:src sfdcField:sfdcName];
			[session pushChangesFromRecord:phone withIdentifier:[self makeCompoundKey:[src id] type:sfdcName]];
		}
	}

	// push address child objects
	NSString *prefix;
	e = [addressMappings keyEnumerator];
	while (prefix = [e nextObject]) {
		if([self hasAnyAddressField:src addressPrefix:prefix]) {
			NSDictionary * addr = [self makeSyncAddressRecord:src prefix:prefix appleType:[addressMappings objectForKey:prefix]];
			[session pushChangesFromRecord:addr withIdentifier:[self makeAddressKey:[src id] prefix:prefix]];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// pull impl
- (void)pulledChange:(ISyncChange *)change entityName:(NSString *)entity {

	if ([entity isEqualToString:Entity_Email] || [entity isEqualToString:Entity_Phone] || [entity isEqualToString:Entity_Address]) {
			[self relationshipUpdate:change];

	} else if ([entity isEqualToString:Entity_Contact]) {
		if ([[[change record] objectForKey:@"last name"] length] > 0) {
			[self topLevelEntityUpdate:change];
		} else {
			// gotta have a last name 
			NSLog(@"refusing contact change %@", [change recordIdentifier]);
			[session clientRefusedChangesForRecordWithIdentifier:[change recordIdentifier]];
		}
	} else {
		NSLog(@"got unexpected change for entity %@", [change record]);
	}
}

// this takes an sObject and updates it from the data in the syncData, applying the relevant field mappings
- (void)updateSObject:(ZKSObject *)o withChanges:(NSDictionary *)syncData
{
	[self mapFromApple:syncData toSObject:o];
	// handle company name -> accountId nonsense
	NSString * companyName = [syncData objectForKey:@"company name"];
	if (companyName == nil || [companyName length] == 0)
		[o setFieldToNull:@"AccountId"];
	else {
		[o setFieldValue:[self lookupAccountIdFromName:companyName] field:@"AccountId"];
	}
}

// sometimes we need to convert a single change record from SyncServices into multiple changes that
// we run through our code, however there's still only one "real" change record, and we can only
// accept that once. So we keep track of the Ids we know we've created dupes for, then before
// doing an accept we'll see if its here.
// the first check will remove the id from the set, so that the 2nd check will actually do the accept
- (void)registerDuplicateRecordId:(NSString *)recordId {
	[duplicatedRecordIds addObject:recordId];
}

- (BOOL)isDuplicatedRecordId:(NSString *)recordId {
	if ([duplicatedRecordIds containsObject:recordId]) {
		[duplicatedRecordIds removeObject:recordId];
		return YES;
	}
	return NO;
}

- (void)preprocessChildChanges:(NSMutableArray *)childChanges {
	// for phone & address, change updates to be a pair of delete/create changes instead.
	// this allows all the deletes to be applied before any of the change's, so type swaps
	// will work correctly (e.g. home phone <-> work phone changes.)
	ISyncChange *c;
	int idx = 0;
	NSEnumerator *e = [childChanges objectEnumerator];
	while (c = [e nextObject]) {
		if ([c type] == ISyncChangeTypeModify) {
			NSString * appleType = [[c record] objectForKey:key_RecordEntityName];
			if ([appleType isEqualToString:Entity_Phone] || [appleType isEqualToString:Entity_Address]) {
				ISyncChange *del = [MyISyncChange wrap:c withType:ISyncChangeTypeDelete];
				ISyncChange *add = [MyISyncChange wrap:c withType:ISyncChangeTypeAdd];
				[childChanges replaceObjectAtIndex:idx withObject:del];
				[childChanges insertObject:add atIndex:idx+1];
				[self registerDuplicateRecordId:[c recordIdentifier]];
				idx++;
			}
		}
		idx++;
	}
//	e = [childChanges objectEnumerator];
//	NSLog(@"Finalized list of child changes");
//	while (c = [e nextObject]) {
//		NSLog(@"%@", c);
//	}
//	NSLog(@"Finalized list of child changes - end");
}

// update a relationship (on the sync side) regular field update(s) on the sfdc side
- (void)relationshipUpdate:(ISyncChange *)change
{
	if ([change type] == ISyncChangeTypeDelete) {
		// can always delete a related record
		NSString *i = [change recordIdentifier];
		NSString *sfId = [self compoundKeySfId:i];
		NSString *type = [self compoundKeyType:i];
		// 003 is the sfdc keyPrefix for a contact.
		if ([[sfId substringToIndex:3] isEqualToString:@"003"]) {
			AcceptChangeInfo * aci = nil;
			if (![self isDuplicatedRecordId:[change recordIdentifier]])
				aci = [AcceptChangeInfo acceptInfo:[change recordIdentifier] formatted:nil newId:nil];
			[aci setIsForDelete:YES];
			if ([self stringStartsWith:@"Address" src:type])
				[self updateAddressFieldsForContactId:sfId prefix:[type substringFromIndex:7] newAddress:nil acceptInfo:aci];
			else {				
				[self updateFieldValueForContactId:sfId field:type value:nil acceptInfo:aci];
			}
		}
		return;
	} 
	NSString * appleType = [[change record] objectForKey:key_RecordEntityName];
	// note that for brand new records, contactId is the sync services contactId, not the salesforce.com contactId
	NSString * contactId = [[[change record] objectForKey:@"contact"] objectAtIndex:0];
	if ([appleType isEqualToString:Entity_Email]) {
		// before we can add a new relationship, we need to make sure there's not something already mapped to it.
		if ([change type] == ISyncChangeTypeAdd) {
			if ([self pulledRecordWithId:contactId hasThisFieldPopulated:@"Email"]) {
				NSLog(@"rejecting addition because we already have a value for this field, for type %@ %@", appleType, [change recordIdentifier]);
				[session clientRefusedChangesForRecordWithIdentifier:[change recordIdentifier]];					
				return;
			}
		}
		AcceptChangeInfo *aci = nil;
		if (![self isDuplicatedRecordId:[change recordIdentifier]])
			aci = [AcceptChangeInfo acceptInfoWithIdFormat:[change recordIdentifier] formatted:nil newIdFormat:@"%@-Email"]; 
		[self updateFieldValueForContactId:contactId field:@"Email" value:[[change record] objectForKey:@"value"] acceptInfo:aci];
		return;
	}
	else if ([appleType isEqualToString:Entity_Phone]) {
		NSString * phoneType = [[change record] objectForKey:@"type"];
		// have to walk the mapping, bleh
		NSString * sfdcName;
		NSEnumerator * e = [phoneMappings keyEnumerator];
		while (sfdcName = [e nextObject]) {
			if ([[phoneMappings objectForKey:sfdcName] isEqualToString:phoneType]) {
				// supported phone type
				// before we can add a new relationship, we need to make sure there's not something already mapped to it.
				if ([change type] == ISyncChangeTypeAdd) {
					if ([self pulledRecordWithId:contactId hasThisFieldPopulated:sfdcName]) {
						NSLog(@"rejecting addition because we already have a value for this field, for type %@ %@", appleType, [change recordIdentifier]);
						[session clientRefusedChangesForRecordWithIdentifier:[change recordIdentifier]];					
						return;
					}
				} else {
					// this is a change, so check to see if the type changed!
					// we conviently have the old type encoded in the relationship name, so we can find out the last type we saw it as
					NSString *oldType = [self compoundKeyType:[change recordIdentifier]];
					// oldType is the sfdcName of the old type, which is the field name on our side, so that makes it easy to kill off
					[self updateFieldValueForContactId:contactId field:oldType value:nil acceptInfo:nil];
				}
				AcceptChangeInfo *aci = nil;
				if (![self isDuplicatedRecordId:[change recordIdentifier]])
					aci = [AcceptChangeInfo acceptInfoWithIdFormat:[change recordIdentifier] formatted:nil newIdFormat:[NSString stringWithFormat:@"%%@-%@", sfdcName]]; 
				[self updateFieldValueForContactId:contactId field:sfdcName value:[[change record] objectForKey:@"value"] acceptInfo:aci];
				return;
			}
		}	
	} 
	else if ([appleType isEqualToString:Entity_Address]) {
		NSString *addrType = [[change record] objectForKey:@"type"];
		NSString *sfdcPrefix;
		NSEnumerator * e = [addressMappings keyEnumerator];
		while (sfdcPrefix = [e nextObject]) {
			if([[addressMappings objectForKey:sfdcPrefix] isEqualToString:addrType]) {
				// before we can add a new relationship, we need to make sure there's not something already mapped to it.
				if ([change type] == ISyncChangeTypeAdd) {
					ZKSObject *contact = [[self findOrCreatePulledItemForRelatedChange:contactId] sobject];
					if (contact == nil || [self hasAnyAddressField:contact addressPrefix:sfdcPrefix]) {
						NSLog(@"rejecting addition because we already have a value for this field, for type %@ %@", appleType, [change recordIdentifier]);
						[session clientRefusedChangesForRecordWithIdentifier:[change recordIdentifier]];					
						return;
					}
				}
				// supported addr type
				AcceptChangeInfo *aci = nil;
				if (![self isDuplicatedRecordId:[change recordIdentifier]])
					aci = [AcceptChangeInfo acceptInfoWithIdFormat:[change recordIdentifier] formatted:nil newIdFormat:[NSString stringWithFormat:@"%%@-Address%@", sfdcPrefix]]; 
				[self updateAddressFieldsForContactId:contactId prefix:sfdcPrefix newAddress:[change record] acceptInfo:aci];
				return;
			}
		}
	}
	NSLog(@"rejecting unexpected change for type %@ %@ %@", appleType, [change recordIdentifier], [change record]);
	[session clientRefusedChangesForRecordWithIdentifier:[change recordIdentifier]];
}

- (PulledItem *)findOrCreatePulledItemForRelatedChange:(NSString *)parentId {
	PulledItem * pi = [pulledEntities objectForKey:parentId];
	if (pi != nil) return pi;
	// no PulledItem yet for the this Id, we need to make one, first we need to find the actual SObject
	ZKSObject *sobject = [pushedSObjects objectForKey:parentId];
	if (sobject == nil) return nil;
	pi = [PulledItem itemForChange:nil SObject:sobject];
	[pi setShouldFormatForAccept:NO];
	[pulledEntities setObject:pi forKey:parentId];
	return pi;
}

// given the contacts recordIdentifier, find it and update this field
// in addition, add an ChangeAcceptInfo for this contact to the list of things that need accepting
-(void)updateFieldValueForContactId:(NSString *)contactId field:(NSString *)field value:(NSString *)value acceptInfo:(AcceptChangeInfo *)aci 
{
	PulledItem * pi = [self findOrCreatePulledItemForRelatedChange:contactId];
	[[pi sobject] setFieldValue:value field:field];
	[pi addChildAccept:aci];
}

-(void)updateAddressFieldsForContactId:(NSString *)contactId prefix:(NSString *)prefix newAddress:(NSDictionary *)record acceptInfo:(AcceptChangeInfo *)aci 
{
	PulledItem * pi = [self findOrCreatePulledItemForRelatedChange:contactId];
	[pi addChildAccept:aci];
		
	ZKSObject *contact = [pi sobject];
	NSString * fn;
	NSEnumerator * e = [addressParts keyEnumerator];
	while(fn = [e nextObject])	{
		id v = [record objectForKey:[addressParts objectForKey:fn]];
		[contact setFieldValue:v field:[NSString stringWithFormat:@"%@%@", prefix, fn]];
	}
}

- (BOOL)pulledRecordWithId:(NSString *)contactId hasThisFieldPopulated:(NSString *)fieldName {
	PulledItem * pi = [self findOrCreatePulledItemForRelatedChange:contactId];
	return [[[pi sobject] fieldValue:fieldName] length] > 0;
}

- (NSString *)escapeForSoql:(NSString *)src {
	NSMutableString *s = [NSMutableString stringWithString:src];
	[s replaceOccurrencesOfString:@"'" withString:@"\\'" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
	return s;
}


// look in the accountLookupCache first, if not there
// run a query against sfdc for it
// still can't find it?, then create one.
- (NSString *)lookupAccountIdFromName:(NSString *)accName {
	if (accountNameToIds == nil) {
		// init the accountName to Id mapping from whatever got cached by the id->name lookups we did for the push
		accountNameToIds = [[NSMutableDictionary alloc] init];
		ZKSObject * acc;
		NSEnumerator * e = [[accountLookup allFetchedObjects] objectEnumerator];
		while (acc = [e nextObject]) 
			[accountNameToIds setObject:[acc id] forKey:[acc fieldValue:@"Name"]];			
	}
	NSString * accId = [accountNameToIds objectForKey:accName];
	if (accId == nil) {
		// not in the local cache, try a query
		ZKQueryResult * qr = [sforce query:[NSString stringWithFormat:@"Select id from Account where name='%@'", [self escapeForSoql:accName]]];
		if ([qr size] > 0) {
			accId = [[[qr records] objectAtIndex:0] id];
		} else {
			// query didn't find one either, create it
			ZKSObject * newAccount = [ZKSObject withType:@"Account"];
			[newAccount setFieldValue:accName field:@"Name"];
			// TODO, we should be checking that this really did succeed
			ZKSaveResult * sr = [[sforce create:[NSArray arrayWithObject:newAccount]] objectAtIndex:0];
			accId = [sr id];
		}
		// stick it in the cache
		[accountNameToIds setObject:accId forKey:accName];
	}
	return accId;
}

@end
