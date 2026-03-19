# delete-survey-attachments

This script permanently deletes all file attachments (file uploads and signatures) for a specific survey from the Checkbox database. It includes a dry-run mode to preview what would be deleted before making any changes.

This script can only be used for on-premises installations.

## Requirements

- PowerShell 5.1+
- `SqlServer` PowerShell module (`Install-Module SqlServer` if not already installed)

## Usage

Parameters:

- `[string]$ConnectionString` (required) — your Checkbox database connection string (see [Finding your connection string](#finding-your-connection-string))
- `[int]$SurveyID` (required) — the survey's ResponseTemplateID
- `[switch]$DryRun` — preview what would be deleted without making any changes
- `[switch]$IncludeSoftDeleted` — also target attachments that have been soft-deleted

### Dry run (preview only, no changes)

```ps1
.\delete-survey-attachments.ps1 -ConnectionString "Server=localhost;Database=CheckboxSurveys;User Id=CheckboxUser;Password=YourPassword" -SurveyID 1012 -DryRun
```

### Delete attachments

```ps1
.\delete-survey-attachments.ps1 -ConnectionString "Server=localhost;Database=CheckboxSurveys;User Id=CheckboxUser;Password=YourPassword" -SurveyID 1012
```

You will be asked to confirm before any data is deleted.

## What gets deleted

The script removes, within a single transaction:

1. Linking rows in `ckbx_ItemData_FileUpload_Files` and `ckbx_ItemData_Signature_Files`
2. File records (and binary data) in `ckbx_FileUpload`

Only attachments belonging to responses for the specified survey are affected. If anything goes wrong, the entire transaction is rolled back and no data is deleted.

## Finding your connection string

- **Checkbox 8**: `connectionStrings.default` in `appsettings.json` (in the API Core application directory)
- **Checkbox 7**: `DefaultConnection` in `Web.config` (in the API application directory, under `<connectionStrings>`)

## Notes

- **Always run with `-DryRun` first** to review what will be affected.
- **Back up your database** before running without `-DryRun`.
- Use the companion script `list-and-export-attachments` (in `Surveys/list-and-export-attachments`) to export attachment files to disk before deleting.
- If any files are stored in Amazon S3 (`StorageType=1`), the script will warn you — it removes the database records but the actual S3 objects must be deleted separately.
- The `ConnectionString` is automatically normalized to handle common keyword variants (e.g., `Initial Catalog` vs `Database`, `Trust Server Certificate` vs `TrustServerCertificate`).
