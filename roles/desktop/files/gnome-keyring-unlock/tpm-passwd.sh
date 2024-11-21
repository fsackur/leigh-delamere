#! /bin/sh

# When password is changed, encrypt the new password to the user's home
# for use later by gnome-keyring-unlock.
#
# See: https://docs.leigh.delamere.dvlp.casa
#

set -eo pipefail

if [ "$PAM_TYPE" != "password" ]; then
    echo "$0 only valid for PAM password type. Called with type: $PAM_TYPE" >&2
    exit 1
fi

PAM_USER_HOME=$(getent passwd "$PAM_USER" | cut -d: -f6)
/usr/local/bin/encrypt-passwd "$PAM_AUTHTOK" > "$PAM_USER_HOME/.passwd-tpm"
