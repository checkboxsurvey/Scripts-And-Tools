# List all survey data older than a custom date and optionally delete it.
# Note that this is a soft delete and the data will not be permanently removed until the soft delete cleanup retention period has passed.
# This script is currently only written for on-premise but could easily be adjusted to work on Online, or both

param (
	[string]$Server = "http://127.0.0.1",
	[string]$Username = "admin",
	[string]$Password = "admin",
	[string]$ConnectionString = "Server=WIN-PG5QFTGT78T;Database=app;User Id=cbadmin;Password=password;",
    [datetime]$CutOffDate = (Get-Date "2023-6-24T00:00:00"),
	[bool]$EnableLogging = $true
)

#Process: Get all surveys, use this to query all survey data, compose list of all survey data IDs older than a given date, delete those IDs.

$baseUri = "$($Server)/api/v1"
$tokenUri = "$($baseUri)/oauth2/token"
$surveyListUri = "$($baseUri)/surveys?page_size=10&page_num={0}"
$responsesUri = "$($baseUri)/surveys/{0}/responses?page_size=10&page_num={1}"
$bulkDeleteUri = "$($baseUri)/surveys/{0}/responses/bulk-delete"

# Helper function to get all surveys
function Get-AllSurveys {
    $pageNumber = 1
    $allSurveys = @()

    do {
        $uri = [string]::Format($surveyListUri, $pageNumber)
        try {
            $result = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
            $allSurveys += $result.items
            $pageNumber++
        } catch {
            Write-Error "Failed to call $($uri)."
            exit 1
        }
    } while ($result.items.Count -gt 0)

    return $allSurveys
}

# Helper function to get all responses for a survey
function Get-AllResponsesForSurvey {
    param (
        [string]$SurveyId
    )
    $pageNumber = 1
    $allResponses = @()

    do {
        $uri = [string]::Format($responsesUri, $SurveyId, $pageNumber)
        try {
            $result = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
            $allResponses += $result.items
            $pageNumber++
        } catch {
            Write-Error "Failed to call $($uri) for survey ID $SurveyId."
            exit 1
        }
    } while ($result.items.Count -gt 0)

    return $allResponses
}

try{
	$response = Invoke-RestMethod -Uri $tokenUri -Method Post -Headers @{
		"Content-Type" = "application/x-www-form-urlencoded"
	} -Body @{
		username = $Username
		password = $Password
		grant_type = "password"
	}
}
catch {
	Write-Error "Failed to call $($tokenUri), check the Server address, username, and password."
	exit 1
}

$accessToken = $response.access_token

$headers = @{
    "Authorization" = "Bearer $accessToken"
	"Content-Type" = "application/json"
}

# Get all surveys
$allSurveys = Get-AllSurveys

Write-Host "Found $($allSurveys.Count) surveys."

# Collect all responses from all old surveys
$allResponses = @()

foreach ($survey in $allSurveys) {
    $surveyId = $survey.id
    $responses = Get-AllResponsesForSurvey -SurveyId $surveyId
    $allResponses += $responses
}

Write-Host "Found $($allResponses.Count) responses."

# Filter responses older than the CutOffDate
$oldResponses = $allResponses | Where-Object { [datetime]$_.last_edit -lt $CutOffDate }

Write-Host "Found $($oldResponses.Count) responses older than $CutOffDate."

# Group responses by survey ID
$responsesBySurvey = $oldResponses | Group-Object -Property survey_id

# Optional logging for troubleshooting/information
if ($EnableLogging) {
    foreach ($group in $responsesBySurvey) {
        Write-Host "Survey ID: $($group.Name)"
        Write-Host "Responses:"
        $group.Group | Format-Table -AutoSize
    }
}

# Optionally delete old responses
$deleteChoice = Read-Host "Do you want to delete these responses? (y/n)"

if ($deleteChoice -eq 'y') {
    foreach ($group in $responsesBySurvey) {
        $surveyId = $group.Name
        $responseIds = $group.Group | Select-Object -ExpandProperty id

        $deletePayload = @{
            survey_id = $surveyId
            response_ids = $responseIds
        } | ConvertTo-Json

        $bulkDeleteRequest = [string]::Format($bulkDeleteUri, $surveyId)

        try {
            Invoke-RestMethod -Uri $bulkDeleteRequest -Method Post -Headers $headers -Body $deletePayload > $null
            Write-Host "Deleted $($responseIds.Count) responses for survey ID $surveyId."
        } catch {
            Write-Error "Failed to delete responses for survey ID $surveyId."
            Write-Host "Delete Payload: $deletePayload"
            Write-Host "Error Message: $_"
            Write-Host "Response from delete call: $($_.Exception.Response.GetResponseStream() | New-Object System.IO.StreamReader).ReadToEnd()"
        }
    }
} else {
    Write-Host "No responses were deleted."
}

Write-Host "Script completed."