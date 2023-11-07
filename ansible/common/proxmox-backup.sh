#!/bin/bash

set -euo pipefail
err=""


# default values
passwd_file="${passwd_file:-proxmox_backup_passwd}"
username="${username:-backup_user@pbs}"
token_name="${token_name:-$(hostname)}"
server="${server:-backoops}"
datastore="${datastore:-Test}"
# set by systemd, defaults to /root/.secrets
CREDENTIALS_DIRECTORY="${CREDENTIALS_DIRECTORY:-/root/.secrets/}"

PBS_REPOSITORY="$username!$token_name@$server:443:$datastore"
PBS_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/$passwd_file"


backup_target="harriet-home.pxar:/home/harriet/"
excludes=()
_excludes=(
    ".cache"
    ".Trash"
    ".gvfs"
    ".local/share/Trash/"
    ".thumbnails"
    "Downloads/"
    ".mozilla/"
)
for exclude in ${_excludes[@]}; do
    excludes+=" --exclude /home/harriet/$exclude"
done


backup_targets=($backup_target)
set +e
timeshift_base="/timeshift/timeshift/snapshots"
timeshift_path=$(ls $timeshift_base | tail -n1)
if [ -z "$timeshift_path" ]; then
    # If we couldn't parse the timeshift directory, we should still back up the main set
    err="Failed to find latest timeshift backup."
else
    backup_targets+=("timeshift.pxar:$timeshift_base/$timeshift_path/")
fi
set -e


for target in ${backup_targets[@]}; do
    args=($target)
    backup_spec="${args[0]}"
    name="${backup_spec%:*}"
    path="${backup_spec#*:}"
    echo "Backing up $path to $name ..."
done


proxmox-backup-client backup ${backup_targets[@]} $excludes --skip-lost-and-found true $@


if [ ! -z "$err" ]; then
    echo "$err"
    exit 1
fi
