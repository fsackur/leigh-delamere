#!/bin/bash
set -Eeuo pipefail

export MONGO_PASS=$(< $MONGO_PASSWORD_FILE)
export MONGO_PASSWORD_FILE=""
exec /init $@
