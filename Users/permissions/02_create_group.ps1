# Finds all contacts who have the role and create group for them
# This script is primarily useful if you would like to create the groups for some roles with big number of contacts.
# This script is only written for on-premises and cannot be run online since it uses SQL.

param (
    [string]$Server = "http://localhost:37431",
    [string]$Username = "admin",
    [string]$Password = "***",
    [string]$ConnectionString = "Server=SQLServer;Database=CheckboxAccount;User Id=CheckboxUser;Password=***;Application Name=CheckboxTools;",
    [string]$RoleName = "Contact Administrator",
	[string]$GroupName = "AllContactAdmins"
)

$baseUri = "$($Server)/api/v1"
$tokenUri = "$($baseUri)/oauth2/token"
$createGroupUri = "$($baseUri)/contact-groups"
$addMembersToFroupUri = "$($baseUri)/contact-groups/{0}/members"

# Modify SQL query if you would like to extend the logic
$getContactsByRole = @"
	SELECT ir.UniqueIdentifier as Id
	FROM [dbo].[ckbx_IdentityRoles] as ir
	JOIN [dbo].[ckbx_Role] as r ON r.RoleID = ir.RoleID
	WHERE r.RoleName = '{0}'
	GROUP BY ir.UniqueIdentifier
"@

# Get access token
try {
    $response = Invoke-RestMethod -Uri $tokenUri -Method Post -Headers @{
        "Content-Type" = "application/x-www-form-urlencoded"
    } -Body @{
        username = $Username
        password = $Password
        grant_type = "password"
    } -ErrorAction Stop
	# Check if the response indicates success
    if ($response.is_success_status_code -eq $false) {
        throw "Request failed with status code: $($response.status_code) - $($response.reason_phrase)"
    }
} catch {
    Write-Error "Failed to call $($tokenUri), check the Server address, username, and password. $($_.Exception.Message)"
    exit 1
}

$accessToken = $response.access_token
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

# Function to run SQL query
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

    $contacts = @()
    while ($reader.Read()) {
        $contacts += [string]$reader["Id"]
    }

    $connection.Close()
    return $contacts
}

$query = [string]::Format($getContactsByRole, $RoleName)
# Get admin users from the database
$adminUsers = Get-AdminUsers -ConnectionString $ConnectionString -Query $query

Write-Output "Contacts:"
$adminUsers | ForEach-Object { Write-Host $_ }

# Function to create group
function CreateGroup {
	try {
		$requestBody = @{
			description = ""
			name = $GroupName
		} | ConvertTo-Json -Depth 10
		$response = Invoke-RestMethod -Uri $createGroupUri -Headers $headers -Method Post -Body $requestBody -ErrorAction Stop
		if ($response.is_success_status_code -eq $false) {
			throw "Request failed with status code: $($response.status_code) - $($response.reason_phrase)"
		}
		return $response.id
	} catch {
		Write-Error "Failed to create group Name: $($GroupName). Error: $($_.Exception.Message)"
		exit 1
	}
}
	
# Function to create group
function AddMembersToGroup {
	foreach ($item in $adminUsers) {
		try{		
			$uri = [string]::Format($addMembersToFroupUri, $groupId)
			$requestBody = [string]::Format("[`"{0}`"]", $item)
			$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body $requestBody
			Write-Output "Added contact: $($item)"
		} catch {
		}
	}
}

$confirmation = Read-Host "Do you want to create the group $($GroupName) for these contacts? (Y/N)"
if ($confirmation.ToUpper() -eq 'Y') {	
	# Create group
	$groupId = CreateGroup
	Write-Output "Group created Id: $($groupId), Name: $($GroupName)"

	# Add members to Group
	AddMembersToGroup
	Write-Output "Added members to group $($GroupName)"
}
