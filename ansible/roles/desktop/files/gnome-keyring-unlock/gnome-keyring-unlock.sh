#! /bin/sh

# GNOME_KEYRING_CONTROL should be set.
# Should probably run after gnome-keyring-daemon.
#
# User should be able to sudo as tss.
# Example sudoers file contents:
#     <USER> ALL=(tss) NOPASSWD:/usr/bin/clevis-decrypt-tpm2
#
# See:
# https://unix.stackexchange.com/a/723048/610599
# https://codeberg.org/umglurf/gnome-keyring-unlock
#

doc_url="https://docs.leigh.delamere.dvlp.casa"

arg1="$1"

set -euo pipefail

help_msg=$"Usage: $0 PASSWD_FILE_ENCRYPTED\n    PASSWD_FILE_ENCRYPTED: file encrypted with clevis-encrypt-tpm2"
if [ "$arg1" == "-h" ] || [ "$arg1" == "--help" ]; then
    echo -e "$help_msg"
    exit 0
elif [ ! -f "$arg1" ]; then
    echo -e "$help_msg" >&2
    exit 1
fi

passwd_file="$arg1"

unlock () {
    echo "====== Unlocking keyring: $0 ======"
    echo "====== Documentation: $doc_url ======"

    local passwd=$(sudo -u tss clevis-decrypt-tpm2 < $passwd_file)
    echo "decrypted password from ${passwd_file}"

    echo -n "${passwd}" | /usr/local/bin/gnome-keyring-unlock-umglurf/unlock.py

    echo "unlocked keyring"
}

unlock
