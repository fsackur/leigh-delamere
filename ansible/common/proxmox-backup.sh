#!/bin/bash

set -euo pipefail

echo "====== Starting backup: $0 ======"


# default values
backup_name="${backup_name:-harriet-home.pxar}"
backup_root="${backup_root:-/home/harriet/}"
include_timeshift="${include_timeshift:-false}"
timeshift_path="${timeshift_path:-/timeshift/}"
passwd_file="${passwd_file:-proxmox_backup_passwd}"
username="${username:-backup_user@pbs}"
token_name="${token_name:-$(hostname)}"
server="${server:-backoops}"
datastore="${datastore:-Test}"

if [ ! -f $passwd_file ]; then
    # set by systemd, defaults to /root/.secrets
    CREDENTIALS_DIRECTORY="${CREDENTIALS_DIRECTORY:-/root/.secrets/}"
    passwd_file="$CREDENTIALS_DIRECTORY/$passwd_file"
fi


export PBS_REPOSITORY="$username!$token_name@$server:443:$datastore"
export PBS_PASSWORD_FILE=$(realpath $passwd_file)


backup_specs=("$backup_name:$backup_root")


# Excludes match anywhere in path... e.g. ImapMail will exclude /home/timmy/.thunderbird/jkasgd87ad.default-release/ImapMail/outlook.office365.com
# Wildcards supported, e.g. .thunderbird/*/ImapMail, .wine/drive_c/**/INetCache
# Warning: excludes apply to all backup sets!
excludes=()
home_excludes=(
    ".cache"
    ".Trash"
    ".gvfs"
    ".thumbnails"
    "Trash"
    "Downloads"
    "Crash Reports"
    "CachedData"
    ".thunderbird/*/ImapMail"
    ".wine/drive_c/windows"
    ".wine/drive_c/**/INetCache"
)
for exclude in ${home_excludes[@]}; do
    excludes+=" --exclude $exclude"
done


include_timeshift="$(tr [A-Z] [a-z] <<< "$include_timeshift")"
if [ "$include_timeshift" == "0" -o "$include_timeshift" == "false" -o -z "$include_timeshift" ]; then
    echo "Skipping timeshift"
else
    timeshift_path="$(realpath $timeshift_path)"
    if [ "$(basename $timeshift_path)" != "snapshots" ]; then
        if [ -d "$timeshift_path/snapshots" ]; then
            timeshift_path="$timeshift_path/snapshots"
        elif [ -d "$timeshift_path/timeshift/snapshots" ]; then
            timeshift_path="$timeshift_path/timeshift/snapshots"
        else
            echo "$0: Failed to find snapshots in $timeshift_path" 1>&2
            exit 1
        fi
    fi

    snapshot="$(ls -d $timeshift_path/* | tail -n1)"
    if [ ! -d "$snapshot" ]; then
        echo "$0: Failed to find snapshots in $timeshift_path" 1>&2
        exit 1
    else
        echo "Including timeshift snapshot $snapshot ..."
        backup_specs+=("timeshift.pxar:$snapshot")
    fi
fi


for backup_spec in ${backup_specs[@]}; do
    name="${backup_spec%:*}"
    path="${backup_spec#*:}"
    echo "Backing up $path to $name ..."
done


proxmox-backup-client backup ${backup_specs[@]} ${excludes[@]} --skip-lost-and-found true $@
