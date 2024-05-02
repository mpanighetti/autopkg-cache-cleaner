#!/bin/sh

###
#
#            Name:  AutoPkg Cache Cleaner.sh
#     Description:  For each AutoPkg recipe cache, this script searches for and deletes all downloaded resources and compiled packages with creation dates older than the specified number of days.
#                   https://github.com/mpanighetti/autopkg-cache-cleaner
#          Author:  Mario Panighetti
#         Created:  2017-09-13
#   Last Modified:  2024-05-02
#         Version:  1.3.2.1
#
###



########## variable-ing ##########



# Leave these values as-is.
scriptName=$(basename "$0")
loggedInUser=$(/usr/bin/stat -f%Su "/dev/console")
loggedInUserHome=$(/usr/bin/dscl . -read "/Users/${loggedInUser}" NFSHomeDirectory | /usr/bin/awk '{print $NF}')
loggedInUserLibrary="${loggedInUserHome}/Library"
autopkgPrefs="${loggedInUserLibrary}/Preferences/com.github.autopkg"
autopkgCacheDir=$(/usr/bin/defaults read "$autopkgPrefs" CACHE_DIR 2> "/dev/null")
workingDir="/private/tmp/AutoPkg Cache Cleaner"
scriptLog="${loggedInUserLibrary}/Logs/AutoPkg Cache Cleaner.log"
defaultCutoff="30"



########## function-ing ##########



# Ends script.
exit_script () {

  # Reveal log file in Finder.
  /usr/bin/open -R "$scriptLog"

  echo "Script will end here."
  exit 0

}


# For exiting with error.
bail_out () {

  # Display error message from validation step.
  echo "${1}"

  # Reveal log file in Finder.
  /usr/bin/open -R "$scriptLog"

  exit 1

}



########## main process ##########



# Initialize and pass all script output to $scriptLog.
if [ -e "$scriptLog" ]; then
  /bin/rm "$scriptLog"
fi
touch "$scriptLog"
exec 1>>"$scriptLog" 2>&1


# Start script.
echo "Running ${scriptName}..."
echo "${scriptName} start timestamp: $(/bin/date)"


# Check desired cutoff for aging files in days (default to 30).
if [ -n "$1" ]; then
  integerTest=$(echo "${1}" | /usr/bin/tr -d "[:digit:]")
  if [ -z "$integerTest" ]; then
    oldCutoff="$1"
  else
    echo "Invalid input: \"${1}\", using script default."
    oldCutoff="$defaultCutoff"
  fi
else
  oldCutoff="$defaultCutoff"
fi
echo "Cutoff for aging files: ${oldCutoff} days"


# If CACHE_DIR is not defined in plist, use default path.
if [ -z "$autopkgCacheDir" ]; then
  autopkgCacheDir="${loggedInUserLibrary}/AutoPkg/Cache"
  echo "AutoPkg cache directory not defined, using default path: ${autopkgCacheDir}"
fi


# Exit with error if CACHE_DIR does not exist.
if [ ! -d "$autopkgCacheDir" ]; then
  bail_out "❌ ERROR: AutoPkg cache directory not found at ${autopkgCacheDir}, unable to proceed."
else
  echo "AutoPkg cache directory found: ${autopkgCacheDir}"
fi


# Initialize working directory for temp files.
if [ -d "$workingDir" ]; then
  /bin/rm -rf "$workingDir"
  echo "Deleted existing working directory."
fi
/bin/mkdir -p "$workingDir"
echo "Working directory created: ${workingDir}"


# Initialize deleted files list.
deleteTheseFilesPath="${workingDir}/delete-these-files"
if [ -e "$deleteTheseFilesPath" ]; then
  /bin/rm "$deleteTheseFilesPath"
fi
touch "$deleteTheseFilesPath"


# Initialize math file for space-saving calculation.
mathsFilePath="${workingDir}/maths"
if [ -e "$mathsFilePath" ]; then
  /bin/rm "$mathsFilePath"
fi
touch "$mathsFilePath"
echo "0" > "$mathsFilePath"


# Search CACHE_DIR downloads folders for aging files.
find "$autopkgCacheDir" -path "*/downloads" | \
while read -r cacheDownloadPath; do
  find "$cacheDownloadPath" -mtime +"$oldCutoff" >> "$deleteTheseFilesPath"
done


# Search CACHE_DIR top-level paths for aging .pkg files.
find "$autopkgCacheDir" -maxdepth 2 -mtime +"$oldCutoff" -name "*.pkg" >> "$deleteTheseFilesPath"


# Delete files, collecting byte size beforehand for space-saving calculation.
deleteTheseFiles=$(/bin/cat "$deleteTheseFilesPath")
if [ -z "$deleteTheseFiles" ]; then
  echo "No files found greater than ${oldCutoff} days old, no action required."
  exit_script
else
  echo "🧹 Removing files..."
  echo "$deleteTheseFiles" | while read -r deleteMe; do
    /bin/ls -l "$deleteMe" | /usr/bin/awk '{print $5}' >> "$mathsFilePath"
    /bin/rm -rv "$deleteMe"
  done
fi


# Add up space saved, display in least common denominator (from bytes up to gigabytes).
oldCacheSizeTotal=$(paste -s -d + "$mathsFilePath" | /usr/bin/tr -s "+" | /usr/bin/bc)
if [ -z "$oldCacheSizeTotal" ]; then
  oldCacheSizeTotal=0
fi
if [ "$oldCacheSizeTotal" -eq 0 ]; then
  oldCacheSizeLCD="0 B"
elif [ "$oldCacheSizeTotal" -gt 1023 ]; then
  if [ "$oldCacheSizeTotal" -gt 1048575 ]; then
    if [ "$oldCacheSizeTotal" -gt 1073741823 ]; then
      oldCacheSizeLCD=$(echo "$oldCacheSizeTotal" | /usr/bin/awk '{sizeGB = $1 / 1024 / 1024 / 1024 ; print sizeGB " GB" }')
    else
      oldCacheSizeLCD=$(echo "$oldCacheSizeTotal" | /usr/bin/awk '{sizeMB = $1 / 1024 / 1024 ; print sizeMB " MB" }')
    fi
  else
    oldCacheSizeLCD=$(echo "$oldCacheSizeTotal" | /usr/bin/awk '{sizeKB = $1 / 1024 ; print sizeKB " KB" }')
  fi
else
  oldCacheSizeLCD="${oldCacheSizeTotal} B"
fi
echo "✅ All clean! Space saved: ${oldCacheSizeLCD}"



exit_script
