# delete-old-content

List all content (Surveys, Style Templates, Reports, Invitations) older than a custom date and optionally delete it.
Note that deleting Invitations, Reports, and Style Templates is PERMANENT and they cannot be un-deleted.
Surveys are soft-deleted and will be cleaned up a period of time after deletion (set in configuration),
after which they are permanently deleted.
Style Templates that are marked uneditable (built-ins), as well as the "Default" style template, will not be deleted.
This script is currently only written for on-premise but could easily be adjusted to work on Online, or both

## Usage

Parameters:
	[string]$Server = "http://127.0.0.1", *the Server to connect to*
	[string]$Username = "admin", *the Username of an admin account*
	[string]$Password = "admin", *the password of the same admin account*
    [datetime]$CutOffDate = (Get-Date "2022-6-24T00:00:00"), *any content last edited before this date will be slated for deletion*
	[bool]$EnableLogging = $true *whether you want to see additional logging, which lists ALL content to be deleted before offering to do so*


You should either edit the default values in the ps1 file or input your values as follows:

```ps1
.\delete-old-content.ps1 -Server "http://127.0.0.1" -Username "admin" -Password "admin" -CutOffDate "2022-6-24T00:00:00" -EnableLogging $true
```
Of course, hopefully your server has a more secure username and password!

When the application runs, it will make a note of how many of each kind of content were found that are older than the cutoff date as defined.  If Logging is turned on, every content item will be shown in a table format.  After each set of content is listed, you will be asked if you wish to delete it and if so, it will be deleted.
