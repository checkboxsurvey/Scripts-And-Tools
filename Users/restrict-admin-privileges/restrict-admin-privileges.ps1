# Finds all users who have taken an "admin-like" action since the CutOffDate, and optionally removes admin
# permissions from all other contacts (setting them to only have respondent and report viewer permissions).
# This script is primarily useful if you have historically been very generous with admin permissions and would
# like to quickly restrict these permissions only to those who have used them recently.
# This script is only written for on-premises and cannot be run online since it uses SQL.

param (
    [string]$Server = "http://127.0.0.1",
    [string]$Username = "admin",
    [string]$Password = "admin",
    [string]$ConnectionString = "Server=WIN-PG5QFTGT78T;Database=app;User Id=cbadmin;Password=password;",
    [datetime]$CutOffDate = (Get-Date "2024-1-1T00:00:00"),
    [bool]$EnableLogging = $true
)

$baseUri = "$($Server)/api/v1"
$tokenUri = "$($baseUri)/oauth2/token"
$contactsListUri = "$($baseUri)/contacts?page_size=10&page_num={0}"
$editContactRolesUri = "$($baseUri)/contacts/{0}/roles"

# Modified SQL query to use the CutOffDate parameter
$adminActionsQuery = @"
DECLARE @CutoffDate DATETIME;
SET @CutoffDate = '$CutOffDate';

SELECT  CreatedBy AS UserName
FROM ckbx_Template
WHERE CreatedBy IS NOT NULL AND CreatedDate IS NOT NULL AND CreatedDate > @CutoffDate
UNION
SELECT  ModifiedBy AS UserName
FROM ckbx_Template
WHERE ModifiedBy IS NOT NULL AND ModifiedDate IS NOT NULL AND ModifiedDate > @CutoffDate
UNION
SELECT  CreatedBy AS UserName
FROM ckbx_Invitation
WHERE CreatedBy IS NOT NULL AND DateCreated IS NOT NULL AND DateCreated > @CutoffDate
UNION
SELECT  CreatedBy AS UserName
FROM ckbx_StyleTemplate
WHERE CreatedBy IS NOT NULL AND DateCreated IS NOT NULL AND DateCreated > @CutoffDate
UNION
SELECT  CreatedBy AS UserName
FROM ckbx_StyleTemplate
WHERE ModifiedBy IS NOT NULL AND DateModified IS NOT NULL AND DateModified > @CutoffDate
UNION
SELECT  CreatedBy AS UserName
FROM ckbx_Report
WHERE CreatedBy IS NOT NULL AND CreatedDate IS NOT NULL AND CreatedDate > @CutoffDate
UNION
SELECT  ModifiedBy AS UserName
FROM ckbx_Report
WHERE ModifiedBy IS NOT NULL AND ModifiedDate IS NOT NULL AND ModifiedDate > @CutoffDate
UNION
SELECT  CreatedBy AS UserName
FROM ckbx_Group
WHERE CreatedBy IS NOT NULL AND DateCreated IS NOT NULL AND DateCreated > @CutoffDate
UNION
SELECT  ModifiedBy AS UserName
FROM ckbx_Group
WHERE ModifiedBy IS NOT NULL AND ModifiedDate IS NOT NULL AND ModifiedDate > @CutoffDate
UNION
SELECT  CreatedBy AS UserName
FROM ckbx_Credential
WHERE CreatedBy IS NOT NULL AND Created IS NOT NULL AND Created > @CutoffDate;
"@

# Get access token
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

# Function to run SQL query and get admin users
function Get-AdminUsers {
    param (
        [string]$ConnectionString,
        [string]$Query
    )

    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $ConnectionString

    $command = $connection.CreateCommand()
    $command.CommandText = $Query

    $connection.Open()
    $reader = $command.ExecuteReader()

    $users = @()
    while ($reader.Read()) {
        $users += [string]$reader["UserName"]
    }

    $connection.Close()
    return $users
}

# Get admin users from the database
$adminUsers = Get-AdminUsers -ConnectionString $ConnectionString -Query $adminActionsQuery

if ($EnableLogging) {
    Write-Output "Admin Users:"
    $adminUsers | Format-Table -AutoSize | Out-String | Write-Host
}

# Function to get all contacts
function Get-AllContacts {
    $page = 1
    $contacts = @()

    while ($true) {
        $uri = [string]::Format($contactsListUri, $page)
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

        if ($response.items.Count -eq 0) {
            break
        }

        $contacts += $response.items
        $page++
    }

    return $contacts
}

# Get all contacts
$allContacts = Get-AllContacts

# Filter out admin users from contacts, exclude the "admin" user, and filter out contacts with null or empty IDs
$nonAdminContacts = $allContacts | Where-Object { $adminUsers -notcontains [string]$_.id -and [string]$_.id -ne "admin" -and -not [string]::IsNullOrEmpty($_.id) }

if ($EnableLogging) {
    Write-Output "Contacts to be updated:"
    $nonAdminContacts | Select-Object id, email, phone_sms, status, is_email_verified | Format-Table -AutoSize | Out-String | Write-Host
}

# Confirm with user before proceeding
$confirmation = Read-Host "Do you want to change the roles of all listed contacts to 'Respondent and Report Viewer' only? (Y/N)"

if ($confirmation.ToUpper() -eq 'Y') {
    foreach ($contact in $nonAdminContacts) {
        try {
            $editUri = [string]::Format($editContactRolesUri, $contact.id)
            $body = @("Respondent") | ConvertTo-Json

            $null = Invoke-RestMethod -Uri $editUri -Headers $headers -Method Put -Body $body
            Write-Output "Updated roles for contact: $($contact.id)"
        } catch {
            Write-Error "Failed to update roles for contact: $($contact.id). Error: $_"
        }
    }
}
