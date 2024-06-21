# get-users-that-performed-admin-actions

This SQL query produces a time-gated list of all contacts within your checkbox installation that performed "admin-like" actions within a cutoff time period.
An "admin-like" action includes: survey creation and modification, Invitation creation, Template creation and modification, Report creation and modification, Group creation and modification, and finally Contact creation.
This query is useful if your installation was overly permissive with "admin" roles and you want to see who has actually been using them in the last N months or days.
Since it is an SQL query, this will only work on-premises.

## Usage

Simply modify the value in the CutoffDate variable and run the query!

**WARNING** Take care not to alter the script to modify any data, as it is liable to cause irreversible damage and we cannot support databases that have been modified by the customer.