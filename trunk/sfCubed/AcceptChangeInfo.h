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

// tracking object for a single change
@interface AcceptChangeInfo : NSObject {
	id		recordId;
	id		formatted;
	id		newId;
	id  	newIdFormat;
	BOOL	isForDelete;
}

+ (AcceptChangeInfo *) acceptInfo:(id)recordId formatted:(id)f newId:(id)nid;
+ (AcceptChangeInfo *) acceptInfoWithIdFormat:(id)recordId formatted:(id)f newIdFormat:(id)nidf;

- (id) initAccept:(id)recordId formatted:(id)f newId:(id)nid newIdFormat:(id)nidf;
- (BOOL)isForDelete;
- (void)setIsForDelete:(BOOL)newIsForDelete;

// all AcceptChangeInfos are moved through preAccept / preAccept2 / accept in parrallel
// this is to allow us to switch Ids, so that in the case the calculated compound
// id for a child-record ends up having to switch between records, it'll actually
// work (e.g. you have a contact with both a work & home phone, and you switch the
// types on the pair of them, we'll need accept the id-Phone record with a new id
// of id-HomePhone, but there's anlready a different record with that id, so we
// need to register new tempororary unique id's for everything, then accept
// them with the temporary recordId, and give it the final required recordId
- (void)preAccept:(ISyncSession *)session sfId:(NSString *)sfId;
- (void)preAccept2:(ISyncSession *)session sfId:(NSString *)sfId;
- (void)accept:(ISyncSession*)session;
- (void)reject:(ISyncSession*)session;

@end
