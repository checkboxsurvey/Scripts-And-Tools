# delete-old-responses

This script is designed to allow you to quickly soft-delete all responses older than a set cutoff date.  In case of many responses, you may prefer to use a SQL query, but otherwise can use the powershell script.


# delete-old-responses.sql

This script directly queries the database for all responses older than the cutoff date (which you must set by editing the SQL script) and marks them all for soft deletion.  The data will not be permanently removed until the soft delete cleanup retention period has passed.
This script can only be used for on-premises installations.


# delete-old-responses.ps1

This script allows you to list all survey data older than a custom date and optionally delete it.
Note that this is a soft delete and the data will not be permanently removed until the soft delete cleanup retention period has passed.
This script is currently only written for on-premises but could easily be adjusted to work on Online, or both

## Usage

Parameters:
	[string]$Server = "http://127.0.0.1", *the Server to connect to*
	[string]$Username = "admin", *the Username of an admin account*
	[string]$Password = "admin", *the password of the same admin account*
    [datetime]$CutOffDate = (Get-Date "2023-6-24T00:00:00"), *any responses last edited before this date will be slated for deletion*
	[bool]$EnableLogging = $true *whether you want to see additional logging, which lists ALL responses to be deleted before offering to do so*


You should either edit the default values in the ps1 file or input your values as follows:

```ps1
.\delete-old-responses.ps1 -Server "http://127.0.0.1" -Username "admin" -Password "admin" -CutOffDate "2023-6-24T00:00:00" -EnableLogging $true
```
Of course, hopefully your server has a more secure username and password!

When the application runs, it will make a note of how many responses were found, and how many were older than the cutoff date as defined.  If Logging is turned on, every response will be shown in a table format, organized by the survey they belong to.  At this point, you will be asked if you wish to delete the responses, and if you do, they will be deleted via bulk-delete operations.
