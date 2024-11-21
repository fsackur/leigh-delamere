#! /bin/sh

# User should be able to sudo as tss.
# Example sudoers file contents:
#     <USER> ALL=(tss) NOPASSWD:/usr/bin/clevis-decrypt-tpm2
#
# See:
# https://unix.stackexchange.com/a/723048/610599
# https://codeberg.org/umglurf/gnome-keyring-unlock
# https://docs.leigh.delamere.dvlp.casa
#

arg1="$1"

set -euo pipefail

help_msg=$"Usage: $0 PASSWD\n    PASSWD: plaintext password to encrypt"
if [ "$arg1" == "-h" ] || [ "$arg1" == "--help" ]; then
    echo -e "$help_msg"
    exit 0
elif [ -z "$arg1" ]; then
    echo -e "$help_msg" >&2
    exit 1
fi

encrypt () {
    local passwd="$arg1"
    sudo -u tss clevis-encrypt-tpm2 '{"pcr_ids":"7"}' <<<"$passwd"
}

encrypt
