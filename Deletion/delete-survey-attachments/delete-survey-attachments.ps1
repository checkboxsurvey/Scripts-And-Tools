# ============================================================
# Delete attachments for a specific survey
#
# Parameters:
#   -ConnectionString (required)  connectionStrings.default from your Checkbox appsettings.json
#   -SurveyID         (required)  the survey's ResponseTemplateID
#   -DryRun                       preview what would be deleted without making changes
#   -IncludeSoftDeleted           also target attachments marked as soft-deleted
#
# Usage:
#   .\delete-survey-attachments.ps1 -ConnectionString "Server=localhost;Database=CheckboxSurveys;User Id=CheckboxUser;Password=YourPassword" -SurveyID 1012 -DryRun
#   .\delete-survey-attachments.ps1 -ConnectionString "..." -SurveyID 1012
#   .\delete-survey-attachments.ps1 -ConnectionString "..." -SurveyID 1012 -IncludeSoftDeleted -DryRun
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ConnectionString,
    [Parameter(Mandatory=$true)]
    [int]$SurveyID,
    [switch]$DryRun,
    [switch]$IncludeSoftDeleted
)

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

# Query attachments that would be affected
$previewQuery = @"
SELECT
    fu.FileID,
    fu.FileName,
    fu.FileType,
    fu.FileSize,
    fu.StorageType,
    CASE fu.StorageType
        WHEN 0 THEN 'Database'
        WHEN 1 THEN 'Amazon S3'
    END AS StorageLocation,
    fu.Deleted AS SoftDeleted,
    r.ResponseID,
    CASE
        WHEN fuf.FileID IS NOT NULL THEN 'File Upload'
        WHEN sf.FileID IS NOT NULL THEN 'Signature'
    END AS AttachmentType
FROM ckbx_FileUpload fu
LEFT JOIN ckbx_ItemData_FileUpload_Files fuf ON fu.FileID = fuf.FileID
LEFT JOIN ckbx_ItemData_Signature_Files sf ON fu.FileID = sf.FileID
INNER JOIN ckbx_ResponseAnswers ra ON COALESCE(fuf.AnswerID, sf.AnswerID) = ra.AnswerID
INNER JOIN ckbx_Response r ON ra.ResponseID = r.ResponseID
WHERE r.ResponseTemplateID = $SurveyID
  AND (fu.Deleted = 0$(if ($IncludeSoftDeleted) { " OR fu.Deleted = 1" }));
"@

$attachments = @(Invoke-Sqlcmd -ConnectionString $connString -Query $previewQuery)

if ($attachments.Count -eq 0) {
    Write-Host "No attachments found for SurveyID $SurveyID." -ForegroundColor Yellow
    exit
}

# Show what will be deleted
$mode = if ($DryRun) { "DRY RUN" } else { "DELETE" }
Write-Host "`n[$mode] Found $($attachments.Count) attachment(s) for SurveyID ${SurveyID}:`n" -ForegroundColor $(if ($DryRun) { "Cyan" } else { "Red" })
$tableColumns = @("FileID", "FileName", "FileSize", "StorageLocation", "ResponseID", "AttachmentType")
if ($IncludeSoftDeleted) { $tableColumns += "SoftDeleted" }
$attachments | Format-Table $tableColumns -AutoSize

$totalSize = ($attachments | Measure-Object -Property FileSize -Sum).Sum
Write-Host "Total size: $([math]::Round($totalSize / 1MB, 2)) MB ($totalSize bytes)" -ForegroundColor Cyan

# Warn about S3-stored files
$s3Files = @($attachments | Where-Object { $_.StorageType -eq 1 })
if ($s3Files.Count -gt 0) {
    Write-Host "`nWARNING: $($s3Files.Count) file(s) are stored in Amazon S3." -ForegroundColor Yellow
    Write-Host "This script will remove the database records but the actual S3 objects will remain" -ForegroundColor Yellow
    Write-Host "and must be deleted separately from the S3 bucket." -ForegroundColor Yellow
    $s3Files | Format-Table FileID, FileName, FileSize -AutoSize
}

if ($DryRun) {
    Write-Host "`nDry run complete. No changes were made." -ForegroundColor Cyan
    Write-Host "To delete, run again without -DryRun." -ForegroundColor Cyan
    exit
}

# Confirm before proceeding
Write-Host ""
$confirm = Read-Host "Are you sure you want to permanently delete these $($attachments.Count) attachment(s)? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit
}

# Execute deletion
$deleteQuery = @"
BEGIN TRANSACTION;

BEGIN TRY
    -- Collect FileIDs to delete (file uploads)
    SELECT fuf.FileID, fuf.AnswerID
    INTO #FileUploadFilesToDelete
    FROM ckbx_ItemData_FileUpload_Files fuf
    INNER JOIN ckbx_FileUpload fu ON fu.FileID = fuf.FileID
    INNER JOIN ckbx_ResponseAnswers ra ON fuf.AnswerID = ra.AnswerID
    INNER JOIN ckbx_Response r ON ra.ResponseID = r.ResponseID
    WHERE r.ResponseTemplateID = $SurveyID
      AND (fu.Deleted = 0$(if ($IncludeSoftDeleted) { " OR fu.Deleted = 1" }));

    -- Collect FileIDs to delete (signatures)
    SELECT sf.FileID, sf.AnswerID
    INTO #SignatureFilesToDelete
    FROM ckbx_ItemData_Signature_Files sf
    INNER JOIN ckbx_FileUpload fu ON fu.FileID = sf.FileID
    INNER JOIN ckbx_ResponseAnswers ra ON sf.AnswerID = ra.AnswerID
    INNER JOIN ckbx_Response r ON ra.ResponseID = r.ResponseID
    WHERE r.ResponseTemplateID = $SurveyID
      AND (fu.Deleted = 0$(if ($IncludeSoftDeleted) { " OR fu.Deleted = 1" }));

    -- Remove linking rows
    DELETE fuf
    FROM ckbx_ItemData_FileUpload_Files fuf
    INNER JOIN #FileUploadFilesToDelete d ON fuf.FileID = d.FileID AND fuf.AnswerID = d.AnswerID;

    DELETE sf
    FROM ckbx_ItemData_Signature_Files sf
    INNER JOIN #SignatureFilesToDelete d ON sf.FileID = d.FileID AND sf.AnswerID = d.AnswerID;

    -- Delete file records (and their binary data)
    DELETE fu
    FROM ckbx_FileUpload fu
    WHERE fu.FileID IN (
        SELECT FileID FROM #FileUploadFilesToDelete
        UNION
        SELECT FileID FROM #SignatureFilesToDelete
    );

    SELECT @@ROWCOUNT AS DeletedFiles;

    DROP TABLE #FileUploadFilesToDelete;
    DROP TABLE #SignatureFilesToDelete;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;

    IF OBJECT_ID('tempdb..#FileUploadFilesToDelete') IS NOT NULL DROP TABLE #FileUploadFilesToDelete;
    IF OBJECT_ID('tempdb..#SignatureFilesToDelete') IS NOT NULL DROP TABLE #SignatureFilesToDelete;

    THROW;
END CATCH;
"@

try {
    $result = Invoke-Sqlcmd -ConnectionString $connString -Query $deleteQuery
    Write-Host "`nDeleted $($result.DeletedFiles) file(s) for SurveyID $SurveyID." -ForegroundColor Green
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
    Write-Host "Transaction was rolled back. No data was deleted." -ForegroundColor Yellow
}
