#!/bin/bash

###
#
#            Name:  AutoPkg Cache Cleaner.sh
#     Description:  For each AutoPkg recipe cache, searches for and deletes all
#                   downloaded resources and compiled packages with creation
#                   dates older than the specified number of days.
#                   https://github.com/mpanighetti/autopkg-cache-cleaner
#          Author:  Mario Panighetti
#         Created:  2017-09-13
#   Last Modified:  2019-06-28
#         Version:  1.1
#
###



########## variable-ing ##########



# Leave these values as-is.
scriptName=$(basename "$0")
loggedInUser=$("/usr/bin/stat" -f%Su "/dev/console")
loggedInUserHome=$("/usr/bin/dscl" . -read "/Users/$loggedInUser" NFSHomeDirectory | "/usr/bin/awk" '{print $NF}')
loggedInUserLibrary="$loggedInUserHome/Library"
autopkgPrefs="$loggedInUserLibrary/Preferences/com.github.autopkg"
autopkgCacheDir=$("/usr/bin/defaults" read "$autopkgPrefs" CACHE_DIR 2> "/dev/null")
workingDir="/tmp/AutoPkgCacheCleaner"
scriptLog="$loggedInUserLibrary/Logs/AutoPkg Cache Cleaner.log"
defaultCutoff="30"



########## main process ##########



# Pass all script output to $scriptLog.
if [[ ! -e "$scriptLog" ]]; then
  "/bin/echo" "Generating log at $scriptLog."
  touch "$scriptLog"
fi
exec > >("/usr/bin/tee" -a "$scriptLog") 2>&1


# Start script.
"/bin/echo" "Running $scriptName..."
"/bin/echo" "$scriptName start timestamp: $(/bin/date)"


# Check desired cutoff for aging files in days (default to 30).
if [[ -n "$1" ]]; then
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    oldCutoff="$1"
  else
    "/bin/echo" "Invalid input: \"$1\", using script default."
    oldCutoff="$defaultCutoff"
  fi
else
  oldCutoff="$defaultCutoff"
fi
"/bin/echo" "Cutoff for aging files in days: $oldCutoff"


# If CACHE_DIR is not defined in plist, use default path.
if [[ "$autopkgCacheDir" = "" ]]; then
  autopkgCacheDir="$loggedInUserLibrary/AutoPkg/Cache"
  "/bin/echo" "AutoPkg cache directory not defined, using default path ($autopkgCacheDir)."
fi


# Exit if CACHE_DIR does not exist.
if [[ ! -d "$autopkgCacheDir" ]]; then
  "/bin/echo" "AutoPkg cache directory not found at $autopkgCacheDir, unable to proceed."
  exit 1
else
  "/bin/echo" "AutoPkg cache directory found at $autopkgCacheDir."
fi


# Initialize working directory for temp files.
if [[ ! -d "$workingDir" ]]; then
  "/bin/mkdir" -p "$workingDir"
fi


# Initialize deleted files list.
deleteTheseFilesPath="$workingDir/delete-these-files"
if [[ -e "$deleteTheseFilesPath" ]]; then
  "/bin/rm" "$deleteTheseFilesPath"
fi
touch "$deleteTheseFilesPath"


# Initialize math file for space-saving calculation.
mathsFilePath="$workingDir/maths"
if [[ -e "$mathsFilePath" ]]; then
  "/bin/rm" "$mathsFilePath"
fi
touch "$mathsFilePath"
"/bin/echo" "0" > "$mathsFilePath"


# Search CACHE_DIR downloads folders for aging files.
find "$autopkgCacheDir" -path "*/downloads" | \
while read cacheDownloadPath; do
  find "$cacheDownloadPath" -mtime +"$oldCutoff" >> "$deleteTheseFilesPath"
done


# Search CACHE_DIR top-level paths for aging .pkg files.
find "$autopkgCacheDir" -maxdepth 2 -mtime +"$oldCutoff" -name "*.pkg" >> "$deleteTheseFilesPath"


# Delete files, collecting byte size beforehand for space-saving calculation.
deleteTheseFiles=$("/bin/cat" "$deleteTheseFilesPath")
if [[ "$deleteTheseFiles" = "" ]]; then
  "/bin/echo" "No files found greater than $oldCutoff days old, no action required."
  exit 0
else
  "/bin/echo" ""
  "/bin/echo" "Removing files:"
  "/bin/echo" ""
  "/bin/echo" "$deleteTheseFiles" | while read deleteMe; do
    "/bin/ls" -l "$deleteMe" |"/usr/bin/awk" '{print $5}' >> "$mathsFilePath"
    "/bin/rm" -rv "$deleteMe"
  done
fi


# Add up space saved, display in least common denominator (from bytes up to gigabytes).
oldCacheSizeTotal=$(paste -s -d + "$mathsFilePath" | "/usr/bin/tr" -s "+" | "/usr/bin/bc")
if [[ "$oldCacheSizeTotal" = "" ]]; then
  oldCacheSizeTotal=0
fi
if [[ "$oldCacheSizeTotal" -eq 0 ]]; then
  oldCacheSizeLCD="0 B"
elif [[ "$oldCacheSizeTotal" -gt 1023 ]]; then
  if [[ "$oldCacheSizeTotal" -gt 1048575 ]]; then
    if [[ "$oldCacheSizeTotal" -gt 1073741823 ]]; then
      oldCacheSizeLCD=$("/bin/echo" "$oldCacheSizeTotal" |"/usr/bin/awk" '{sizeGB = $1 / 1024 / 1024 / 1024 ; print sizeGB " GB" }')
    else
      oldCacheSizeLCD=$("/bin/echo" "$oldCacheSizeTotal" |"/usr/bin/awk" '{sizeMB = $1 / 1024 / 1024 ; print sizeMB " MB" }')
    fi
  else
    oldCacheSizeLCD=$("/bin/echo" "$oldCacheSizeTotal" | "/usr/bin/awk" '{sizeKB = $1 / 1024 ; print sizeKB " KB" }')
  fi
else
  oldCacheSizeLCD=$("/bin/echo" "$oldCacheSizeTotal B")
fi
echo ""
echo "Space saved: $oldCacheSizeLCD"
echo ""



exit 0
