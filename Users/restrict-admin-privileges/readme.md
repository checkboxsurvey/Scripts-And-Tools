# restrict-admin-privileges

Finds all users who have taken an "admin-like" action since the CutOffDate, and optionally removes admin
permissions from all other contacts (setting them to only have respondent and report viewer permissions).
This script is primarily useful if you have historically been very generous with admin permissions and would
like to quickly restrict these permissions only to those who have used them recently.
This script is only written for on-premises and cannot be run online since it uses SQL.

## Usage

Parameters:
	[string]$Server = "http://127.0.0.1", *the Server to connect to*
	[string]$Username = "admin", *the Username of an admin account*
	[string]$Password = "admin", *the password of the same admin account*
	[string]$ConnectionString = "Server=WIN-PG5QFTGT78T;Database=app;User Id=cbadmin;Password=password;", *the connection string for your Checkbox app database*
    [datetime]$CutOffDate = (Get-Date "2024-1-1T00:00:00"), *any users who have not taken admin actions more recently than this cutoff will have permissions downgraded*
	[bool]$EnableLogging = $true *whether you want to see additional logging, which lists all users to have permissions downgraded*

You should either edit the default values in the ps1 file or input your values as follows:

```ps1
.\delete-old-content.ps1 -Server "http://127.0.0.1" -Username "admin" -Password "admin" -ConnectionString "Server=WIN-PG5QFTGT78T;Database=app;User Id=cbadmin;Password=password;" -CutOffDate "2024-1-1T00:00:00" -EnableLogging $true
```
Of course, hopefully your server has a more secure username and password!

When the script runs, it will first make a note of all users which have taken an "Admin-Like" action within the cutoff period.  It will then note the contacts that did not fit this criteria, listing them out if *EnableLogging* is set to true.  You will be asked if you wish to change the roles of all listed contacts, and if yes each will be confirmed as its roles are set.

Please note that the "admin" account will always be excluded, since it should not have roles downgraded.