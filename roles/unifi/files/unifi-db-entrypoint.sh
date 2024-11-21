#!/bin/bash
set -Eeuo pipefail

# Workaround for docker-entrypoint.sh restarting itself as uid 999, which
# cannot read the password file
export MONGO_INITDB_ROOT_PASSWORD=$(< $MONGO_INITDB_ROOT_PASSWORD_FILE)
export MONGO_INITDB_ROOT_PASSWORD_FILE=""
exec docker-entrypoint.sh $@
