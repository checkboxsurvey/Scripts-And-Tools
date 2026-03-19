# ============================================================
# List and export all survey attachments
#
# Usage (all attachments):
#   .\list-and-export-attachments.ps1 -ConnectionString "Server=localhost;Database=CheckboxSurveys;User Id=CheckboxUser;Password=YourPassword"
#
# Usage (single survey):
#   .\list-and-export-attachments.ps1 -ConnectionString "Server=localhost;Database=CheckboxSurveys;User Id=CheckboxUser;Password=YourPassword" -SurveyID 1012
#
# The ConnectionString is the same value as connectionStrings.default in your Checkbox appsettings.json.
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ConnectionString,
    [string]$OutputPath = ".\CheckboxAttachments",
    [int]$SurveyID = 0
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
WHERE fu.Deleted = 0 $surveyFilter
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
$attachments | Format-Table FileID, FileName, FileSize, StorageLocation, SurveyName, ResponseID, AttachmentType -AutoSize

# Resolve to absolute path using PowerShell's $PWD (not .NET's working directory)
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)

# Create output directory and export CSV report
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$csvPath = Join-Path $OutputPath "attachments-report.csv"
$attachments | Select-Object FileID, FileGuid, FileName, FileType, FileSize, MIMEContentType,
    CreatedDate, StorageType, StorageLocation, BinaryDataBytes, SurveyID, SurveyName,
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
    $surveyFolder = if ($att.SurveyName) { $att.SurveyName -replace '[\\/:*?"<>|]', '_' } else { "_Orphaned" }
    $responseFolder = if ($att.ResponseID) { "Response-$($att.ResponseID)" } else { "_NoResponse" }
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

            $filePath = Join-Path $folder $att.FileName
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
