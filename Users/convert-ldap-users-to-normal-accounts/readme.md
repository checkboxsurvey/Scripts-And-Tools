# convert-ldap-users-to-normal-accounts

This SQL script finds all instances of "LDAP/AD Identities" in the database, which typically look like "DOMAIN\Username" but may also contain multiple separating slashes without breaking the script (ie: "Domain\Subdomain\Username").  All that it finds are converted to just the Username, and finally a list of usernames is selected/output by the script.

The next step to complete converting users is to use this list of usernames and import these users via the "import contacts" functionality, after adding in whatever extra information you need.  For instance, if migrating from LDAP/Active Directory to SAML, you'll want to look up each user's email address so you can import that along with the username.  Once the import is complete, the newly created users should automatically be granted access to the data which was formally attached to their LDAP/AD identity.

This script only functions for on-premises, since Online users cannot directly interact with their database and cannot use LDAP/AD anyways.