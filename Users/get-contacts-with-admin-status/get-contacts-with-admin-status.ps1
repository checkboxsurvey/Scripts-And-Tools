# List all recent admins and non-admins by running this powershell script, which uses the Checkbox API.
# This script is currently only written for on-premise but could easily be adjusted to work on Online, or both

param (
	[string]$Server = "http://127.0.0.1",
	[string]$Username = "admin",
	[string]$Password = "admin",
	[string]$ConnectionString = "Server=WIN-PG5QFTGT78T;Database=app;User Id=cbadmin;Password=password;",
    [datetime]$CutOffDate = (Get-Date "2023-12-16T00:00:00"),
	[string]$AdminListPath = "recentAdmins.txt",
	[string]$NonadminListPath = "recentNonAdmins.txt"
)

$adminRoles = @("System Administrator", "Contact Administrator", "Survey Administrator", "Report Administrator", "Survey Editor")

$baseUri = "$($Server)/api/v1"
$tokenUri = "$($baseUri)/oauth2/token"
$contactsListUri = "$($baseUri)/contacts"
$getContactRolesUriBase = "$($baseUri)/contacts/{0}/roles"

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
	$result = Invoke-RestMethod -Uri $contactsListUri -Method Get -Headers $headers
}
catch {
	Write-Error "Failed to call $($surveyListUri)."
	exit 1
}

$adminUsernames = [System.Collections.ArrayList]::new()
$nonAdminUsernames = [System.Collections.ArrayList]::new()

# Assuming $response contains the server response as shown above
foreach ($item in $result.items) {
	try{		
		$getRolesUri = $getContactRolesUriBase -f $item.id
		$rolesResponse = Invoke-RestMethod -Uri $getRolesUri -Method Get -Headers $Headers
		$commonValues = Compare-Object -ReferenceObject $adminRoles -DifferenceObject $rolesResponse -IncludeEqual -ExcludeDifferent
		if ($commonValues) {
			$adminUsernames.Add($item.id) > $null
	    } else {
			$nonAdminUsernames.Add($item.id) > $null
		}
	}
	catch {
		Write-Error "Failed to call $($getRolesUri)."
	}
}

function Get-RecentLogins {
    param (
        [string]$ConnectionString,
        [datetime]$CutOffDate,
        [string[]]$UniqueIdentifiers
    )

    # Convert the list of unique identifiers to a comma-separated string for the SQL query
    $uniqueIdentifiersString = "'" + ($UniqueIdentifiers -join "','") + "'"

    # Define the SQL query to get all LastLogin datetimes for the list of UniqueIdentifiers after the CutOffDate
    # and ensure LastLogin is not null
    $query = @"
SELECT UniqueIdentifier, LastLogin 
FROM ckbx_IdentityLoginActivity 
WHERE UniqueIdentifier IN ($uniqueIdentifiersString) AND LastLogin IS NOT NULL AND LastLogin > @CutOffDate
"@

    # Create a SQL connection
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $ConnectionString

    # Create a SQL command
    $command = $connection.CreateCommand()
    $command.CommandText = $query

    # Add the CutOffDate parameter to the SQL command
    $command.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@CutOffDate", [System.Data.SqlDbType]::DateTime))).Value = $CutOffDate

    # Create a Data Adapter to fill the DataTable
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $dataTable = New-Object System.Data.DataTable

    # Open the connection, execute the query and fill the DataTable
    $connection.Open()
    [void]$adapter.Fill($dataTable)
    $connection.Close()

    # Initialize an empty array list to store identifiers with recent logins
    $recentLogins = New-Object System.Collections.ArrayList

    # Iterate through the DataTable and add UniqueIdentifiers to the recentLogins list
    foreach ($row in $dataTable.Rows) {
        [void]$recentLogins.Add($row["UniqueIdentifier"])
    }

    # Return the list of recent logins
    return $recentLogins
}

$RecentAdmins = Get-RecentLogins -ConnectionString $ConnectionString -CutOffDate $CutOffDate -UniqueIdentifiers $adminUsernames
$RecentNonAdmins = Get-RecentLogins -ConnectionString $ConnectionString -CutOffDate $CutOffDate -UniqueIdentifiers $nonAdminUsernames

Write-Output "Recent Admins:"
foreach ($adminId in $RecentAdmins) {
	Write-Output $adminId
}

Write-Output "Recent Non-Admins:"
foreach ($nonAdminId in $RecentNonAdmins) {
	Write-Output $nonAdminId
}

$RecentAdmins | Out-File -FilePath $AdminListPath
$RecentNonAdmins | Out-File -FilePath $NonadminListPath
