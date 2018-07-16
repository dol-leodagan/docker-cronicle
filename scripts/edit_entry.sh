#!/bin/sh

set -x

sleep 1

FILE_TO_EDIT="$1"

TEMP_FILE_TO_EDIT="$(mktemp -p "$(dirname "$FILE_TO_EDIT")")"

jq --raw-output "$CRONICLE_EDIT_FILTER" "$FILE_TO_EDIT" > "$TEMP_FILE_TO_EDIT" \
    && mv -f "$TEMP_FILE_TO_EDIT" "$FILE_TO_EDIT"
