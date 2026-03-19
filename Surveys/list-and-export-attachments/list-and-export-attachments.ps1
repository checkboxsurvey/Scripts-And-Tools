# ============================================================
# List and export all survey attachments
#
# Parameters:
#   -ConnectionString (required)  connectionStrings.default from your Checkbox appsettings.json
#   -OutputPath                   output directory (default: .\CheckboxAttachments)
#   -SurveyID                     filter to a specific survey by ResponseTemplateID
#   -IncludeSoftDeleted           also include attachments marked as soft-deleted
#
# Usage:
#   .\list-and-export-attachments.ps1 -ConnectionString "Server=localhost;Database=CheckboxSurveys;User Id=CheckboxUser;Password=YourPassword"
#   .\list-and-export-attachments.ps1 -ConnectionString "..." -SurveyID 1012
#   .\list-and-export-attachments.ps1 -ConnectionString "..." -SurveyID 1012 -IncludeSoftDeleted
#   .\list-and-export-attachments.ps1 -ConnectionString "..." -OutputPath "C:\Exports\Attachments"
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ConnectionString,
    [string]$OutputPath = ".\CheckboxAttachments",
    [int]$SurveyID = 0,
    [switch]$IncludeSoftDeleted
)

# Build query — when filtering by survey, use INNER JOINs up the response chain
if ($SurveyID -gt 0) {
    $surveyFilter = "AND r.ResponseTemplateID = $SurveyID"
    $responseJoin = "INNER JOIN"
    Write-Host "Filtering to SurveyID: $SurveyID" -ForegroundColor Cyan
} else {
    $surveyFilter = ""
    $responseJoin = "LEFT JOIN"
}

$query = @"
SELECT
    fu.FileID,
    fu.FileGuid,
    fu.FileName,
    fu.FileType,
    fu.FileSize,
    fu.MIMEContentType,
    fu.CreatedDate,
    fu.StorageType,
    CASE fu.StorageType
        WHEN 0 THEN 'Database'
        WHEN 1 THEN 'Amazon S3'
    END AS StorageLocation,
    DATALENGTH(fu.FileData) AS BinaryDataBytes,
    fu.Deleted AS SoftDeleted,
    rt.ResponseTemplateID AS SurveyID,
    rt.TemplateName AS SurveyName,
    r.ResponseID,
    r.GUID AS ResponseGUID,
    ra.AnswerID,
    i.Alias AS QuestionAlias,
    CASE
        WHEN fuf.FileID IS NOT NULL THEN 'File Upload'
        WHEN sf.FileID IS NOT NULL THEN 'Signature'
        ELSE 'Orphaned'
    END AS AttachmentType
FROM ckbx_FileUpload fu
LEFT JOIN ckbx_ItemData_FileUpload_Files fuf ON fu.FileID = fuf.FileID
LEFT JOIN ckbx_ItemData_Signature_Files sf ON fu.FileID = sf.FileID
$responseJoin ckbx_ResponseAnswers ra ON COALESCE(fuf.AnswerID, sf.AnswerID) = ra.AnswerID
$responseJoin ckbx_Response r ON ra.ResponseID = r.ResponseID
LEFT JOIN ckbx_ResponseTemplate rt ON r.ResponseTemplateID = rt.ResponseTemplateID
LEFT JOIN ckbx_Item i ON ra.ItemID = i.ItemID
WHERE (fu.Deleted = 0$(if ($IncludeSoftDeleted) { " OR fu.Deleted = 1" })) $surveyFilter
ORDER BY rt.TemplateName, r.ResponseID, fu.CreatedDate DESC;
"@

# Normalize connection string keywords that Invoke-Sqlcmd may not accept
$connString = $ConnectionString
$connString = $connString -replace "(?i)Trust Server Certificate", "TrustServerCertificate"
$connString = $connString -replace "(?i)Initial Catalog", "Database"
$connString = $connString -replace "(?i)Data Source", "Server"
$connString = $connString -replace "(?i)User ID", "User Id"
$connString = $connString -replace "(?i)Connect Timeout", "Connection Timeout"
if ($connString -notmatch "(?i)TrustServerCertificate") {
    $connString += ";TrustServerCertificate=true"
}

# Query the attachment listing
$attachments = @(Invoke-Sqlcmd -ConnectionString $connString -Query $query)

if ($attachments.Count -eq 0) {
    Write-Host "No attachments found." -ForegroundColor Yellow
    exit
}

# Print summary to console
Write-Host "`nFound $($attachments.Count) attachment(s):`n" -ForegroundColor Green
$tableColumns = @("FileID", "FileName", "FileSize", "StorageLocation", "SurveyName", "ResponseID", "AttachmentType")
if ($IncludeSoftDeleted) { $tableColumns += "SoftDeleted" }
$attachments | Format-Table $tableColumns -AutoSize

# Resolve to absolute path using PowerShell's $PWD (not .NET's working directory)
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)

# Check if output directory already has content
if ((Test-Path $OutputPath) -and (Get-ChildItem $OutputPath | Measure-Object).Count -gt 0) {
    Write-Host "Output directory already contains files: $OutputPath" -ForegroundColor Yellow
    $confirm = Read-Host "Existing files may be overwritten. Continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit
    }
}

# Create output directory and export CSV report
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$csvPath = Join-Path $OutputPath "attachments-report.csv"
$attachments | Select-Object FileID, FileGuid, FileName, FileType, FileSize, MIMEContentType,
    CreatedDate, StorageType, StorageLocation, BinaryDataBytes, SoftDeleted, SurveyID, SurveyName,
    ResponseID, ResponseGUID, AnswerID, QuestionAlias, AttachmentType |
    Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "CSV report saved to: $csvPath" -ForegroundColor Cyan

# Export DB-stored files to disk
$filesDir = Join-Path $OutputPath "files"
$exported = 0
$skipped = 0

# Query file binary data one at a time to avoid loading everything into memory
foreach ($att in $attachments) {
    if ($att.StorageType -ne 0) {
        Write-Host "  SKIP FileID $($att.FileID) '$($att.FileName)' - S3-stored, cannot export from DB" -ForegroundColor Yellow
        $skipped++
        continue
    }

    # Build folder path: files/<SurveyName>/Response-<ResponseID>/
    $surveyFolder = if ($att.SurveyName -and $att.SurveyName -isnot [DBNull]) { $att.SurveyName -replace '[\\/:*?"<>|]', '_' } else { "_Orphaned" }
    $responseFolder = if ($att.ResponseID -and $att.ResponseID -isnot [DBNull]) { "Response-$($att.ResponseID)" } else { "_NoResponse" }
    $folder = Join-Path $filesDir (Join-Path $surveyFolder $responseFolder)
    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    # Fetch binary data for this file
    $fileQuery = "SELECT FileData FROM ckbx_FileUpload WHERE FileID = $($att.FileID) AND FileData IS NOT NULL"
    $conn = New-Object System.Data.SqlClient.SqlConnection($connString)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $fileQuery
        $reader = $cmd.ExecuteReader([System.Data.CommandBehavior]::SequentialAccess)

        if ($reader.Read() -and -not $reader.IsDBNull(0)) {
            $size = $reader.GetBytes(0, 0, $null, 0, 0)
            $bytes = [byte[]]::new($size)
            $reader.GetBytes(0, 0, $bytes, 0, $size)

            $name = [System.IO.Path]::GetFileNameWithoutExtension($att.FileName)
            $ext = [System.IO.Path]::GetExtension($att.FileName)
            $targetName = $att.FileName
            if (Test-Path (Join-Path $folder $targetName)) {
                $targetName = "${name}_FileID$($att.FileID)${ext}"
            }
            $filePath = Join-Path $folder $targetName
            [System.IO.File]::WriteAllBytes($filePath, $bytes)
            Write-Host "  OK   FileID $($att.FileID) -> $filePath" -ForegroundColor Green
            $exported++
        }
        else {
            Write-Host "  SKIP FileID $($att.FileID) '$($att.FileName)' - no binary data in FileData column" -ForegroundColor Yellow
            $skipped++
        }

        $reader.Close()
    }
    finally {
        $conn.Close()
    }
}

Write-Host "`nDone. Exported: $exported, Skipped: $skipped" -ForegroundColor Cyan
Write-Host "Output directory: $OutputPath" -ForegroundColor Cyan
