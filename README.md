# AutoPkg Cache Cleaner
For each AutoPkg recipe cache, this script searches for and deletes all downloaded resources and compiled packages with creation dates older than the specified number of days.

This script expects to run in user context (the same user account running AutoPkg) and does not require `sudo` for a typical AutoPkg install.
