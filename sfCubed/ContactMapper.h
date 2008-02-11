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

#import "BaseMapper.h"
#import "LookupInfoCache.h"
#import "PulledItem.h"

// mapper for Contact/Account to Contacts/address/phone/ etc.
// this is complicated by the significant differences in datamodels, the
// salesforce.com model is flat, where as the apple side has various child
// entities for addresses, phone numbers, IM addresses etc.
// The salesforce.com side has some slots for these, but can't cope with
// the variable number that's supported on the AddressBook side, so we 
// have to do various dances to handle a subset of the child entities 
// and also a subset of the child entity types (e.g. one work and one home address)
//
// It feels like there must be an easier way to handle this mis-match, but
// its not clear yet how. the Sync Services folks suggested i might be making
// things harder on myself by pulling all the changes first before trying
// to process any of them.
@interface ContactMapper : BaseMapper {
	NSDictionary	*phoneMappings;
	NSDictionary	*addressParts;
	NSDictionary	*addressMappings;
	NSMutableSet	*duplicatedRecordIds;
	
	LookupInfoCache		*accountLookup;
	NSMutableDictionary *accountNameToIds;
}

+ (NSDictionary *)supportedPhoneTypes;

// init
- (ContactMapper *)initMapper:(ZKSforceClient *)sf options:(SyncOptions *)options;

// push impl
- (NSDictionary *)makeSyncEmailRecord:(ZKSObject *)src;
- (NSDictionary *)makeSyncPhoneRecord:(ZKSObject *)src sfdcField:(NSString *)sfdcField;
- (NSDictionary *)makeSyncAddressRecord:(ZKSObject *)src prefix:(NSString *)prefix appleType:(NSString *)appleType;
- (NSMutableDictionary *)makeRelatedRecordOfType:(NSString *)entityName type:(NSString *)appleType value:(NSString *)value sfdcId:(NSString *)sfdcId;
- (BOOL)hasAnyAddressField:(ZKSObject *)src addressPrefix:(NSString *)prefix;
- (NSString *)makeAddressKey:(NSString *)Id prefix:(NSString *)prefix;

// pull impl
- (PulledItem *)findOrCreatePulledItemForRelatedChange:(NSString *)parentId;
- (void)updateFieldValueForContactId:(NSString *)contactId field:(NSString *)field value:(NSString *)value acceptInfo:(AcceptChangeInfo *)cai;
- (void)updateAddressFieldsForContactId:(NSString *)contactId prefix:(NSString *)prefix newAddress:(NSDictionary *)record acceptInfo:(AcceptChangeInfo *)aci;
- (BOOL)pulledRecordWithId:(NSString *)contactId hasThisFieldPopulated:(NSString *)fieldName;

// accountName support
- (NSString *)lookupAccountIdFromName:(NSString *)accName;

@end
