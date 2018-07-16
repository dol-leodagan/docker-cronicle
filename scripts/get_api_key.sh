#/bin/sh

/opt/cronicle/bin/storage-cli.js get "global/api_keys/0" | tail -n +2 \
    | jq -r '.items[] | select(.title == "Console CLI") | .key'
