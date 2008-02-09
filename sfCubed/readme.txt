SFCubed
-------

Uses Sync Services to provide 2 way sync between salesforce.com and AddressBook & iCal.


Most of the complexity in this project is handling data model mismatches between the 2 data models, for tasks & events there are minor differences, however
for contacts there are more significant differences, most notably that AdressBook uses child entities for addresses, phone numbers, IM, email address etc
while in Salesforce.com, its an entirly flat model. Most of the problems come in support subsets of the child entities, e.g. one work and one home phone number

The actual data model mapping is built up in layers
Mappers				- the set of entities to sync/map
	BaseMapper		- each entity to sync/map is represented by a sub class of base mapper
		FieldMappingInfo	- each data point in the entity is mapped using a FieldMappingInfo (or subclass of)
							- some fields, particularly in contacts are managed "by hand" with code directly at
							- the entity mapping level.
							
The code in the project is grouped as follows
common			- shared code between many of my OSX/Salesforce.com projects, for SF3 this is mainly about login & keychain management.
FieldMappers	- FieldMappingInfo and all its entity specific sub classes
Object Mappers  - BaseMapper, plus the entity specific sub classes and some related peices
Classes			- grab bag of random stuff to organize, SFCubed is the primary entry point.
Sforce Api		- set of classes for interacting with the Salesforce.com Web Services API.



There is much to do

Support fast sync, currently slow push everying each time we sync.
review error handling, both from SyncServices and from SF API calls.
create an URL in the contact to take you to their SFDC page.
handle fields hidden by FLS
custom field mappings (would be useful for home email)
support being able to pick which calendar in iCal to sync to (this would then enable entourage <-> ical <-> sfdc)
for contacts support an AddressBook subset using a Salesforce.com group
improve logging & diagnostics, fix the stupid logging draw.
UI clean-up
move sync process off the main thread
add a UI/Prompt similar to the protect the truth prompt for protecting SFDC.
prompt/do an AdressBook & iCal backup on first run
write some help
investigate "conflicts" on dates that are the same date (probably some TZ weirdness)
re-occuring events (ugh)
one of the reason we pull all the changes before working on any is to support the progress bar, perhaps we should
		give up on the progress bar, and just use an indterminate progress spinner instead.