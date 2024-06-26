# List all content (Surveys, Style Templates, Reports, Invitations) older than a custom date and optionally delete it.
# Note that deleting Invitations, Reports, and Style Templates is PERMANENT and they cannot be un-deleted.
# Surveys are soft-deleted and will be cleaned up a period of time after deletion (set in configuration),
# after which they are permanently deleted.
# Style Templates that are marked uneditable (built-ins), as well as the "Default" style template, will not be deleted.
# This script is currently only written for on-premise but could easily be adjusted to work on Online, or both

param (
    [string]$Server = "http://127.0.0.1",
    [string]$Username = "admin",
    [string]$Password = "admin",
    [datetime]$CutOffDate = (Get-Date "2023-6-24T00:00:00"),
    [bool]$EnableLogging = $true
)

$baseUri = "$($Server)/api/v1"
$tokenUri = "$($baseUri)/oauth2/token"
$surveyListUri = "$($baseUri)/surveys?page_size=10&page_num={0}"
$invitationsListUri = "$($baseUri)/surveys/{0}/invitations?page_size=10&page_num={1}"
$deleteInvitationUri = "$($baseUri)/surveys/{0}/invitations/{1}"
$reportsListUri = "$($baseUri)/dashboards?report_type=Dashboard&page_size=10&page_num={0}"
$deleteReportUri = "$($baseUri)/reports/{0}"
$deleteSurveyUri = "$($baseUri)/surveys/{0}"
$styleTemplatesUri = "$($baseUri)/style-templates?in_use=false&page_size=10&page_num={0}"
$deleteStyleTemplateUri = "$($baseUri)/style-templates/{0}"

function Get-AllItems($uriTemplate) {
    $pageNumber = 1
    $allItems = @()

    do {
        $uri = [string]::Format($uriTemplate, $pageNumber)
        try {
            $result = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
            $allItems += $result.items
            $pageNumber++
        } catch {
            Write-Error "Failed to call $($uri)."
            exit 1
        }
    } while ($result.items.Count -gt 0)

    return $allItems
}

function Delete-Item($uri) {
    try {
        Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers
        Write-Host "Successfully deleted $uri"
    } catch {
        Write-Error "Failed to delete $uri"
    }
}

function Ask-Confirmation($itemType, $items) {
    if ($items.Count -eq 0) {
        Write-Host "No $itemType to delete."
        return $false
    }

    if ($EnableLogging) {
        Write-Host "$itemType to be deleted:"
        $items | Format-Table -AutoSize | Out-String | Write-Host
    }

    $confirmation = Read-Host "Do you want to delete these $itemType? (yes/no)"
    $confirmation = $confirmation.Trim().ToLower()
    $shouldDelete = ($confirmation -eq "yes" -or $confirmation -eq "y")
    return $shouldDelete
}

try {
    $response = Invoke-RestMethod -Uri $tokenUri -Method Post -Headers @{
        "Content-Type" = "application/x-www-form-urlencoded"
    } -Body @{
        username = $Username
        password = $Password
        grant_type = "password"
    }
} catch {
    Write-Error "Failed to call $($tokenUri), check the Server address, username, and password."
    exit 1
}

$accessToken = $response.access_token

$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

# Get all surveys
$allSurveys = Get-AllItems $surveyListUri
Write-Host "Found $($allSurveys.Count) surveys."

# Process Invitations
$allOldInvitations = @()
foreach ($survey in $allSurveys) {
    $surveyId = $survey.id
    $allInvitations = Get-AllItems ([string]::Format($invitationsListUri, $surveyId, '{0}'))
    $oldInvitations = $allInvitations | Where-Object { $_.created -lt $CutOffDate }

    foreach ($invitation in $oldInvitations) {
        $invitation | Add-Member -MemberType NoteProperty -Name 'surveyId' -Value $surveyId -Force
    }

    $allOldInvitations += $oldInvitations
}

if (Ask-Confirmation "invitations" $allOldInvitations) {
    foreach ($invitation in $allOldInvitations) {
        $uri = [string]::Format($deleteInvitationUri, $invitation.surveyId, $invitation.id)
        if ($EnableLogging) { Write-Host "Deleting invitation: $uri" }
        Delete-Item $uri
    }
}

# Process Reports
$allReports = Get-AllItems $reportsListUri
$oldReports = $allReports | Where-Object { $_.created -lt $CutOffDate }

if (Ask-Confirmation "reports" $oldReports) {
    foreach ($report in $oldReports) {
        $uri = [string]::Format($deleteReportUri, $report.id)
        if ($EnableLogging) { Write-Host "Deleting report: $uri" }
        Delete-Item $uri
    }
}

# Process Surveys
$oldSurveys = $allSurveys | Where-Object { $_.created -lt $CutOffDate }

if (Ask-Confirmation "surveys" $oldSurveys) {
    foreach ($survey in $oldSurveys) {
        $uri = [string]::Format($deleteSurveyUri, $survey.id)
        if ($EnableLogging) { Write-Host "Deleting survey: $uri" }
        Delete-Item $uri
    }
}

# Process Style Templates
$allStyleTemplates = Get-AllItems $styleTemplatesUri
$oldStyleTemplates = $allStyleTemplates | Where-Object { $_.created -lt $CutOffDate -and $_.is_editable -and $_.name -ne "Default" }

if (Ask-Confirmation "style templates" $oldStyleTemplates) {
    foreach ($template in $oldStyleTemplates) {
        $uri = [string]::Format($deleteStyleTemplateUri, $template.id)
        if ($EnableLogging) { Write-Host "Deleting style template: $uri" }
        Delete-Item $uri
    }
}

Write-Host "Script completed."
