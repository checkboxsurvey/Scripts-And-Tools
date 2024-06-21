DECLARE @CutoffDate DATETIME;
SET @CutoffDate = '2024-01-01';

SELECT CreatedBy AS UserName
FROM ckbx_Template
WHERE CreatedBy IS NOT NULL AND CreatedDate IS NOT NULL AND CreatedDate > @CutoffDate
UNION
SELECT ModifiedBy AS UserName
FROM ckbx_Template
WHERE ModifiedBy IS NOT NULL AND ModifiedDate IS NOT NULL AND ModifiedDate > @CutoffDate
UNION
SELECT CreatedBy AS UserName
FROM ckbx_Invitation
WHERE CreatedBy IS NOT NULL AND DateCreated IS NOT NULL AND DateCreated > @CutoffDate
UNION
SELECT CreatedBy AS UserName
FROM ckbx_StyleTemplate
WHERE CreatedBy IS NOT NULL AND DateCreated IS NOT NULL AND DateCreated > @CutoffDate
UNION
SELECT CreatedBy AS UserName
FROM ckbx_StyleTemplate
WHERE ModifiedBy IS NOT NULL AND DateModified IS NOT NULL AND DateModified > @CutoffDate
UNION
SELECT CreatedBy AS UserName
FROM ckbx_Report
WHERE CreatedBy IS NOT NULL AND CreatedDate IS NOT NULL AND CreatedDate > @CutoffDate
UNION
SELECT ModifiedBy AS UserName
FROM ckbx_Report
WHERE ModifiedBy IS NOT NULL AND ModifiedDate IS NOT NULL AND ModifiedDate > @CutoffDate
UNION
SELECT CreatedBy AS UserName
FROM ckbx_Group
WHERE CreatedBy IS NOT NULL AND DateCreated IS NOT NULL AND DateCreated > @CutoffDate
UNION
SELECT ModifiedBy AS UserName
FROM ckbx_Group
WHERE ModifiedBy IS NOT NULL AND ModifiedDate IS NOT NULL AND ModifiedDate > @CutoffDate
UNION
SELECT CreatedBy AS UserName
FROM ckbx_Credential
WHERE CreatedBy IS NOT NULL AND Created IS NOT NULL AND Created > @CutoffDate;
