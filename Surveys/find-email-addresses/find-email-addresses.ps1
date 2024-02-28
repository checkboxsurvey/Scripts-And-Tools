# Find any email addresses in your surveys by running this powershell script, which uses the Checkbox API.
# This script is currently only written for on-premise but could easily be adjusted to work on Online, or both

param (
	[string]$Server = "http://127.0.0.1",
	[string]$Username = "admin",
	[string]$Password = "admin"
)

$baseUri = "$($Server)/api/v1"
$tokenUri = "$($baseUri)/oauth2/token"
$surveyListUri = "$($baseUri)/survey-list"
$exportUri = "$($baseUri)/surveys/{0}/export?language=en-US"
$emailPattern = '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
$surveysUri = "$($Server)/admin/surveys/{0}"

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
}

try{
	$result = Invoke-RestMethod -Uri $surveyListUri -Method Get -Headers $headers
}
catch {
	Write-Error "Failed to call $($surveyListUri)."
	exit 1
}

# Assuming $response contains the server response as shown above
foreach ($item in $result.items) {
	try{		
		if ($item.list_item_type -eq "Survey") {
			Write-Output "Inspecting Survey ID: $($item.id)"
			$surveyUri = $exportUri -f $item.id
			$surveyExport = Invoke-WebRequest -Uri $surveyUri -Method Get -Headers $headers
		
			$matches = $surveyExport.Content | Select-String -Pattern $emailPattern -AllMatches

			if ($matches.Matches.Count -gt 0) {
				Write-Output "Found email addresses:"
				$matches.Matches.Value | ForEach-Object { Write-Output $_ }
				$thisSurveyUri = $surveysUri -f $item.id
				Write-Output "This survey can be edited at $($thisSurveyUri)"
			} else {
				Write-Output "No email addresses found."
			}
		}
	}
	catch {
		Write-Error "Failed to call $($surveyUri)."
	}
}