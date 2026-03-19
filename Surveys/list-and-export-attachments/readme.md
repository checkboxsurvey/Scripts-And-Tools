# list-and-export-attachments

This script queries the Checkbox database for all survey attachments (file uploads and signatures), prints a summary, exports a CSV report, and dumps all database-stored files to disk.

This script can only be used for on-premises installations.

## Requirements

- PowerShell 5.1+
- `SqlServer` PowerShell module (`Install-Module SqlServer` if not already installed)

## Usage

Parameters:

- `[string]$ConnectionString` (required) — the `connectionStrings.default` value from your Checkbox `appsettings.json`
- `[string]$OutputPath` — output directory (default: `.\CheckboxAttachments`)
- `[int]$SurveyID` — filter to a specific survey by its ResponseTemplateID (default: all surveys)
- `[switch]$IncludeSoftDeleted` — also include attachments that have been soft-deleted

### List and export all attachments

```ps1
.\list-and-export-attachments.ps1 -ConnectionString "Server=localhost;Database=CheckboxSurveys;User Id=CheckboxUser;Password=YourPassword"
```

### List and export attachments for a specific survey

```ps1
.\list-and-export-attachments.ps1 -ConnectionString "Server=localhost;Database=CheckboxSurveys;User Id=CheckboxUser;Password=YourPassword" -SurveyID 1012
```

## Output

The script creates the following structure in the output directory:

```
CheckboxAttachments/
├── attachments-report.csv
└── files/
    └── <SurveyName>/
        └── Response-<ResponseID>/
            └── <FileName>
```

- **attachments-report.csv** — full listing of all attachments with metadata (FileID, survey name, response ID, storage type, etc.)
- **files/** — exported binary files organized by survey name and response

## Notes

- Files stored in Amazon S3 (`StorageType=1`) are included in the CSV report but cannot be exported from the database — they are skipped with a warning during file export.
- The `ConnectionString` is automatically normalized to handle common keyword variants (e.g., `Initial Catalog` vs `Database`, `Trust Server Certificate` vs `TrustServerCertificate`).
