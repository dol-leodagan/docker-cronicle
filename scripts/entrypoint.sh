#!/bin/sh

# Set Hostname
if [ "${VIRTUAL_HOST}x" != "x" ]; then
    export HOSTNAME="${VIRTUAL_HOST}"
elif [ "${BASE_APP_URL}x" != "x" ]; then
    URL_HOSTNAME=$(echo "${BASE_APP_URL}" | sed -e "s/[^/]*\/\/\([^@]*@\)\?\([^:/]*\).*/\2/")
    export HOSTNAME="${URL_HOSTNAME}"
fi

# Set Configuration
jq  " \
    .secret_key = \"${SECRET_KEY:-$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 32 | head -n 1)}\" | \
    .email_from = \"${EMAIL_FROM}\" | \
    .smtp_hostname = \"${SMTP_HOSTNAME}\" | \
    .smtp_port = \"${SMTP_PORT}\" | \
    .mail_options.secure = \"${SMTP_SECURE}\" | \
    .mail_options.auth.user = \"${SMTP_USER}\" | \
    .mail_options.auth.pass = \"${SMTP_PASSWORD}\" | \
    .web_socket_use_hostnames = ${WEB_SOCKET_USE_HOSTNAMES:-1} | \
    .server_comm_use_hostnames = ${SERVER_COMM_USE_HOSTNAMES:-1} | \
    .WebServer.http_port = ${WEBSERVER_HTTP_PORT:-80} | \
    .WebServer.https_port = ${WEBSERVER_HTTPS_PORT:-443} | \
    .WebServer.https = ${WEBSERVER_HTTPS:-true} | \
    .base_app_url = \"${BASE_APP_URL:-https://${HOSTNAME}:${WEBSERVER_HTTPS_PORT}}\" | \
    .master_ping_timeout = ${MASTER_PING_TIMEOUT:-60} \
    " conf/config.json \
    > conf/config.json.edit \
&& mv -f conf/config.json.edit conf/config.json

# Setup Data Storage
if [ ! -d "data" ] || [ -z "$(ls -A "data")" ]; then
    node bin/storage-cli.js setup \
    && node bin/storage-cli.js get "global/api_keys/0/" \
        | jq -r '.items += [ {
      "privileges": {
        "admin": 0,
        "create_events": 1,
        "edit_events": 1,
        "delete_events": 1,
        "run_events": 1,
        "abort_events": 1,
        "state_update": 1
      },
      "key": "'"$(tr -dc 'a-f0-9' < /dev/urandom | fold -w 32 | head -n 1)"'",
      "active": "0",
      "title": "Console CLI",
      "description": "Can be used from Console with /get_api_key.sh",
      "id": "k'"$(tr -dc 'a-z0-9' < /dev/urandom | fold -w 10 | head -n 1)"'",
      "username": "'"${CRONICLE_ADMIN_USERNAME:-admin}"'",
      "modified": '"$(date +%s)"',
      "created": '"$(date +%s)"'
    } ]' \
        | node bin/storage-cli.js put "global/api_keys/0/" \
    && node bin/storage-cli.js get "global/api_keys" \
        | jq -r ' .length = 1 ' \
        | node  bin/storage-cli.js put "global/api_keys"
fi

# Setup Admin Account
node bin/storage-cli.js admin "${CRONICLE_ADMIN_USERNAME:-admin}" "${CRONICLE_ADMIN_PASSWORD:-admin}" "${CRONICLE_ADMIN_EMAIL:-admin@localhost}"

# Set Local API Key
node bin/storage-cli.js get "global/api_keys/0/" \
    | jq -r " .items |= map(if .title == \"Console CLI\" then .active=\"${CRONICLE_ENABLE_CLI_APIKEY:-0}\" else . end) " \
    | node bin/storage-cli.js put "global/api_keys/0/"

exec node --expose_gc --always_compact lib/main.js --foreground --echo --debug_level "${DEBUG_LEVEL:-4}" "$@"
