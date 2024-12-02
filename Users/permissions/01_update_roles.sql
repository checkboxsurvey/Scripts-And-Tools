-- UPDATE VARIABLES BEFORE EXECUTION
DECLARE @lastLoginDate datetime = '2024-05-23'

/* extend black list if you would like to save other admins from modification */
DECLARE @BlackListAdmin TABLE(Id nvarchar(611))
INSERT INTO @BlackListAdmin VALUES
('admin')
--,('someIdHere')


DECLARE @AdminsBefore TABLE(Id nvarchar(611))
DECLARE @RespondentsBefore TABLE(Id nvarchar(611))
DECLARE @AdminsAfter TABLE(Id nvarchar(611))
DECLARE @RespondentsAfter TABLE(Id nvarchar(611))

-- Define all admins BEFORE running script
INSERT INTO @AdminsBefore
SELECT ir.UniqueIdentifier as Id
FROM [dbo].[ckbx_IdentityRoles] as ir
JOIN [dbo].[ckbx_Role] as r ON r.RoleID = ir.RoleID
WHERE r.RoleName IN('System Administrator', 'Contact Administrator', 'Survey Administrator', 'Report Administrator', 'Survey Editor')
GROUP BY ir.UniqueIdentifier

-- Define all respondents BEFORE running script
INSERT INTO @RespondentsBefore
SELECT ir.UniqueIdentifier as Id
FROM [dbo].[ckbx_IdentityRoles] as ir
JOIN [dbo].[ckbx_Role] as r ON r.RoleID = ir.RoleID
LEFT JOIN @AdminsBefore as ab ON ab.Id = ir.UniqueIdentifier
WHERE r.RoleName IN('Respondent', 'Report Viewer') AND ab.Id IS NULL
GROUP BY ir.UniqueIdentifier

-- Define contacts that have admin activities
DECLARE @HasAdminAcitivities TABLE(Id nvarchar(611))
INSERT INTO @HasAdminAcitivities
SELECT t.Id FROM
	(
	-- create survey
	SELECT CreatedBy as Id
	FROM [dbo].[ckbx_Template]
	WHERE CreatedBy IS NOT NULL
	GROUP BY CreatedBy
	UNION
	-- edit survey
	SELECT ModifiedBy as Id
	FROM [dbo].[ckbx_Template]
	WHERE ModifiedBy IS NOT NULL
	GROUP BY ModifiedBy
	UNION
	-- create contact
	SELECT CreatedBy as Id
	FROM [dbo].[ckbx_Credential]
	WHERE CreatedBy IS NOT NULL
	GROUP BY CreatedBy
	UNION
	-- edit contact
	SELECT ModifiedBy as Id
	FROM [dbo].[ckbx_Credential]
	WHERE ModifiedBy IS NOT NULL
	GROUP BY ModifiedBy
	UNION
	-- create report
	SELECT CreatedBy as Id
	FROM [dbo].[ckbx_Report]
	WHERE CreatedBy IS NOT NULL
	GROUP BY CreatedBy
	UNION
	-- edit report
	SELECT ModifiedBy as Id
	FROM [dbo].[ckbx_Report]
	WHERE ModifiedBy IS NOT NULL
	GROUP BY ModifiedBy
	UNION
	-- create style
	SELECT CreatedBy as Id
	FROM [dbo].[ckbx_StyleTemplate]
	WHERE CreatedBy IS NOT NULL
	GROUP BY CreatedBy
	UNION
	-- edit style
	SELECT ModifiedBy as Id
	FROM [dbo].[ckbx_StyleTemplate]
	WHERE ModifiedBy IS NOT NULL
	GROUP BY ModifiedBy
	UNION
	-- create invitation
	SELECT CreatedBy as Id
	FROM [dbo].[ckbx_Invitation]
	WHERE CreatedBy IS NOT NULL
	GROUP BY CreatedBy
	UNION
	-- create folder
	SELECT CreatedBy as Id
	FROM [dbo].[ckbx_Folder]
	WHERE CreatedBy IS NOT NULL
	GROUP BY CreatedBy
	UNION
	-- create group
	SELECT CreatedBy as Id
	FROM [dbo].[ckbx_Group]
	WHERE CreatedBy IS NOT NULL
	GROUP BY CreatedBy
	UNION
	-- edit group
	SELECT ModifiedBy as Id
	FROM [dbo].[ckbx_Group]
	WHERE ModifiedBy IS NOT NULL
	GROUP BY ModifiedBy
	) t
GROUP BY t.Id;

-- Define new admins AFTER running script
INSERT INTO @AdminsAfter
SELECT haa.Id as Id
FROM [dbo].[ckbx_IdentityLoginActivity] ila
JOIN @HasAdminAcitivities haa ON haa.Id = ila.UniqueIdentifier
LEFT JOIN @BlackListAdmin bla ON bla.Id = ila.UniqueIdentifier
WHERE ila.LastLogin > @lastLoginDate AND bla.Id IS NULL
GROUP BY haa.Id

-- Define all respondents AFTER running script
INSERT INTO @RespondentsAfter
SELECT c.UniqueIdentifier
FROM [dbo].[ckbx_Credential] c
LEFT JOIN @AdminsAfter aa ON aa.Id = c.UniqueIdentifier
LEFT JOIN @BlackListAdmin bla ON bla.Id = c.UniqueIdentifier
WHERE aa.Id IS NULL AND bla.Id IS NULL
GROUP BY c.UniqueIdentifier

-- View data BEFORE running scripts
SELECT Id as AdminIdBeforeScript FROM @AdminsBefore
SELECT Id as RespondentIdBeforeScript FROM @RespondentsBefore
-- View data AFTER running scripts
SELECT Id as BlackListAdminIdAfterScript FROM @BlackListAdmin
SELECT Id as NewAdminIdAfterScript FROM @AdminsAfter
SELECT Id as RespondentIdAfterScript FROM @RespondentsAfter

-- If you are satisfied with the results uncomment the next section and RUN the script again
/*

-- Clear roles except for BlackListAdmin
DELETE FROM [dbo].[ckbx_IdentityRoles]
WHERE UniqueIdentifier NOT IN(SELECT Id FROM @BlackListAdmin)

SET NOCOUNT ON;
DECLARE @contact_id nvarchar(611), @contact_admin_id int, @survey_admin_id int, @report_admin_id int, @survey_editor_id int, @respondent_id int, @report_viewer_id int;
SELECT @contact_admin_id = [RoleID] FROM [dbo].[ckbx_Role] WHERE [RoleName] = 'Contact Administrator'
SELECT @survey_admin_id = [RoleID] FROM [dbo].[ckbx_Role] WHERE [RoleName] = 'Survey Administrator'
SELECT @report_admin_id = [RoleID] FROM [dbo].[ckbx_Role] WHERE [RoleName] = 'Report Administrator'
SELECT @survey_editor_id = [RoleID] FROM [dbo].[ckbx_Role] WHERE [RoleName] = 'Survey Editor'
SELECT @respondent_id = [RoleID] FROM [dbo].[ckbx_Role] WHERE [RoleName] = 'Respondent'
SELECT @report_viewer_id = [RoleID] FROM [dbo].[ckbx_Role] WHERE [RoleName] = 'Report Viewer'

-- Update roles for admins
DECLARE admin_cursor CURSOR FOR
SELECT Id FROM @AdminsAfter
OPEN admin_cursor
FETCH NEXT FROM admin_cursor INTO @contact_id

WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO [dbo].[ckbx_IdentityRoles] (UniqueIdentifier, RoleID) VALUES
	(@contact_id, @contact_admin_id),
	(@contact_id, @survey_admin_id),
	(@contact_id, @report_admin_id),
	(@contact_id, @survey_editor_id)

    FETCH NEXT FROM admin_cursor INTO @contact_id
END
CLOSE admin_cursor;
DEALLOCATE admin_cursor;

-- Update roles for respondents
DECLARE respondent_cursor CURSOR FOR
SELECT Id FROM @RespondentsAfter
OPEN respondent_cursor
FETCH NEXT FROM respondent_cursor INTO @contact_id

WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO [dbo].[ckbx_IdentityRoles] (UniqueIdentifier, RoleID) VALUES
	(@contact_id, @respondent_id),
	(@contact_id, @report_viewer_id)

    FETCH NEXT FROM respondent_cursor INTO @contact_id
END
CLOSE respondent_cursor;
DEALLOCATE respondent_cursor;

*/