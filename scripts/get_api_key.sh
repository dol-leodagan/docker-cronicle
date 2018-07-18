#!/bin/sh

/opt/cronicle/bin/storage-cli.js get "global/api_keys/0" \
    | jq -r '.items[] | select(.title == "Console CLI") | .key'
