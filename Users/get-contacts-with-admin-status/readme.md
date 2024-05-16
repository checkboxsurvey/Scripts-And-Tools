# get-contacts-with-admin-status

This script allows you to scan all contacts within your checkbox installation and return two lists: admins that have logged in within the cutoff period, and non-admins who have logged in within the cutoff period.
This script as written will only work on-premise but could be easily modified to work with a Checkbox Online acount.


## Usage

Parameters and their default values are:

	[string]$Server = "http://127.0.0.1"
	[string]$Username = "admin"
	[string]$Password = "admin"
	[string]$ConnectionString = "Server=WIN-PG5QFTGT78T;Database=app;User Id=cbadmin;Password=password;"
    [datetime]$CutOffDate = (Get-Date "2023-12-16T00:00:00")
	[string]$AdminListPath = "recentAdmins.txt"
	[string]$NonadminListPath = "recentNonAdmins.txt"
	
You may adjust the values to fit your installation by either editing the ps1 file or by using the command line, like so:

```ps1
.\get-contacts-with-admin-status.ps1 -Server "http://127.0.0.1" -Username "admin" -Password "admin" -ConnectionString "Server=WIN-PG5QFTGT78T;Database=app;User Id=cbadmin;Password=password;" -CutOffDate (Get-Date "2023-12-16T00:00:00") -AdminListPath "recentAdmins.txt" -NonadminListPath "recentNonAdmins.txt"
```
Of course, hopefully your server has a more secure username and password (for the app and SQL both)

When the script runs, it will display the admins and non-admins that meet the datetime cutoff, and will additionally output them, one per line, into the files indicated.