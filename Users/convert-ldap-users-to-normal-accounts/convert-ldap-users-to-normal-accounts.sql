-- Create a temporary table to store the original usernames
CREATE TABLE #OriginalUsernames (
    OriginalUsername varchar(255)
);

-- Extract usernames and update ckbx_IdentityRoles
UPDATE ckbx_IdentityRoles
SET UniqueIdentifier = REVERSE(SUBSTRING(REVERSE(UniqueIdentifier), 1, CHARINDEX('\', REVERSE(UniqueIdentifier)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.UniqueIdentifier), 1, CHARINDEX('\', REVERSE(DELETED.UniqueIdentifier)) - 1)) INTO #OriginalUsernames
WHERE UniqueIdentifier LIKE '%\%';

-- Extract usernames and update ckbx_GroupMembers
UPDATE ckbx_GroupMembers
SET MemberUniqueIdentifier = REVERSE(SUBSTRING(REVERSE(MemberUniqueIdentifier), 1, CHARINDEX('\', REVERSE(MemberUniqueIdentifier)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.MemberUniqueIdentifier), 1, CHARINDEX('\', REVERSE(DELETED.MemberUniqueIdentifier)) - 1)) INTO #OriginalUsernames
WHERE MemberUniqueIdentifier LIKE '%\%';

-- Extract usernames and update ckbx_AccessControlEntry
UPDATE ckbx_AccessControlEntry
SET EntryIdentifier = REVERSE(SUBSTRING(REVERSE(EntryIdentifier), 1, CHARINDEX('\', REVERSE(EntryIdentifier)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.EntryIdentifier), 1, CHARINDEX('\', REVERSE(DELETED.EntryIdentifier)) - 1)) INTO #OriginalUsernames
WHERE EntryIdentifier LIKE '%\%';

-- Extract usernames and update ckbx_Template
UPDATE ckbx_Template
SET CreatedBy = REVERSE(SUBSTRING(REVERSE(CreatedBy), 1, CHARINDEX('\', REVERSE(CreatedBy)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.CreatedBy), 1, CHARINDEX('\', REVERSE(DELETED.CreatedBy)) - 1)) INTO #OriginalUsernames
WHERE CreatedBy LIKE '%\%';

-- Extract usernames and update ckbx_Invitation
UPDATE ckbx_Invitation
SET CreatedBy = REVERSE(SUBSTRING(REVERSE(CreatedBy), 1, CHARINDEX('\', REVERSE(CreatedBy)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.CreatedBy), 1, CHARINDEX('\', REVERSE(DELETED.CreatedBy)) - 1)) INTO #OriginalUsernames
WHERE CreatedBy LIKE '%\%';

-- Extract usernames and update ckbx_Group
UPDATE ckbx_Group
SET CreatedBy = REVERSE(SUBSTRING(REVERSE(CreatedBy), 1, CHARINDEX('\', REVERSE(CreatedBy)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.CreatedBy), 1, CHARINDEX('\', REVERSE(DELETED.CreatedBy)) - 1)) INTO #OriginalUsernames
WHERE CreatedBy LIKE '%\%';

-- Extract usernames and update ckbx_CustomUserFieldMap
UPDATE ckbx_CustomUserFieldMap
SET UniqueIdentifier = REVERSE(SUBSTRING(REVERSE(UniqueIdentifier), 1, CHARINDEX('\', REVERSE(UniqueIdentifier)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.UniqueIdentifier), 1, CHARINDEX('\', REVERSE(DELETED.UniqueIdentifier)) - 1)) INTO #OriginalUsernames
WHERE UniqueIdentifier LIKE '%\%';

-- Extract usernames and update ckbx_UserPanel
UPDATE ckbx_UserPanel
SET UserIdentifier = REVERSE(SUBSTRING(REVERSE(UserIdentifier), 1, CHARINDEX('\', REVERSE(UserIdentifier)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.UserIdentifier), 1, CHARINDEX('\', REVERSE(DELETED.UserIdentifier)) - 1)) INTO #OriginalUsernames
WHERE UserIdentifier LIKE '%\%';

-- Extract usernames and update ckbx_Panel
UPDATE ckbx_Panel
SET CreatedBy = REVERSE(SUBSTRING(REVERSE(CreatedBy), 1, CHARINDEX('\', REVERSE(CreatedBy)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.CreatedBy), 1, CHARINDEX('\', REVERSE(DELETED.CreatedBy)) - 1)) INTO #OriginalUsernames
WHERE CreatedBy LIKE '%\%';

-- Extract usernames and update ckbx_InvitationRecipients
UPDATE ckbx_InvitationRecipients
SET UniqueIdentifier = REVERSE(SUBSTRING(REVERSE(UniqueIdentifier), 1, CHARINDEX('\', REVERSE(UniqueIdentifier)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.UniqueIdentifier), 1, CHARINDEX('\', REVERSE(DELETED.UniqueIdentifier)) - 1)) INTO #OriginalUsernames
WHERE UniqueIdentifier LIKE '%\%';

-- Extract usernames and update ckbx_Folder
UPDATE ckbx_Folder
SET CreatedBy = REVERSE(SUBSTRING(REVERSE(CreatedBy), 1, CHARINDEX('\', REVERSE(CreatedBy)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.CreatedBy), 1, CHARINDEX('\', REVERSE(DELETED.CreatedBy)) - 1)) INTO #OriginalUsernames
WHERE CreatedBy LIKE '%\%';

-- Extract usernames and update ckbx_Content_Folders
UPDATE ckbx_Content_Folders
SET CreatedBy = REVERSE(SUBSTRING(REVERSE(CreatedBy), 1, CHARINDEX('\', REVERSE(CreatedBy)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.CreatedBy), 1, CHARINDEX('\', REVERSE(DELETED.CreatedBy)) - 1)) INTO #OriginalUsernames
WHERE CreatedBy LIKE '%\%';

-- Extract usernames and update ckbx_Content_Items
UPDATE ckbx_Content_Items
SET CreatedBy = REVERSE(SUBSTRING(REVERSE(CreatedBy), 1, CHARINDEX('\', REVERSE(CreatedBy)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.CreatedBy), 1, CHARINDEX('\', REVERSE(DELETED.CreatedBy)) - 1)) INTO #OriginalUsernames
WHERE CreatedBy LIKE '%\%';

-- Extract usernames and update ckbx_ResponseTemplate
UPDATE ckbx_ResponseTemplate
SET CreatedBy = REVERSE(SUBSTRING(REVERSE(CreatedBy), 1, CHARINDEX('\', REVERSE(CreatedBy)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.CreatedBy), 1, CHARINDEX('\', REVERSE(DELETED.CreatedBy)) - 1)) INTO #OriginalUsernames
WHERE CreatedBy LIKE '%\%';

-- Extract usernames and update ckbx_Response
UPDATE ckbx_Response
SET UniqueIdentifier = REVERSE(SUBSTRING(REVERSE(UniqueIdentifier), 1, CHARINDEX('\', REVERSE(UniqueIdentifier)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.UniqueIdentifier), 1, CHARINDEX('\', REVERSE(DELETED.UniqueIdentifier)) - 1)) INTO #OriginalUsernames
WHERE UniqueIdentifier LIKE '%\%';

-- Extract usernames and update ckbx_AppearancePreset
UPDATE ckbx_AppearancePreset
SET CreatedBy = REVERSE(SUBSTRING(REVERSE(CreatedBy), 1, CHARINDEX('\', REVERSE(CreatedBy)) - 1))
OUTPUT REVERSE(SUBSTRING(REVERSE(DELETED.CreatedBy), 1, CHARINDEX('\', REVERSE(DELETED.CreatedBy)) - 1)) INTO #OriginalUsernames
WHERE CreatedBy LIKE '%\%';

-- Select distinct usernames to avoid duplicates
SELECT DISTINCT OriginalUsername
FROM #OriginalUsernames;

-- Clean up the temporary table
DROP TABLE #OriginalUsernames;