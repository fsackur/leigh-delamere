#!/usr/bin/bash

dir=$(dirname $0)

hostname=$(hostname)
playbook="${1:-$hostname/$hostname.yml}"
if [ "$playbook" == "" ]; then
    echo "Must specify a playbook"
    exit 1
fi
shift

if [ -z "$(which ansible-playbook)" ]; then
    echo "Installing ansible..."
    sudo apt install -y ansible
fi

_=$(sudo -n ls 2>&1)
if [ $? -eq 0 ]; then
    ask_become_pass=""
else
    ask_become_pass="--ask-become-pass"
fi

ansible-playbook \
    $dir/$playbook \
    -i "$(hostname)," \
    -l "$(hostname)," \
    -c local \
    -u $(whoami) \
    ${ask_become_pass} \
    $@
