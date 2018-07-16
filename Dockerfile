FROM node:alpine

WORKDIR /opt/cronicle/

RUN set -ex; \
    \
    # Get Build Dependencies
    \
    apk --no-cache --update add --virtual .build-deps\
        perl perl-pathtools wget tar curl bash; \
    \
    # Get Runtime Packages
    \
    apk add --no-cache --update \
        procps jq ca-certificates; \
    \
    # Update Certs
    update-ca-certificates; \
    \
    # Setup Cronicle
    curl -s https://raw.githubusercontent.com/jhuckaby/Cronicle/master/bin/install.js | node; \
    \
    # Patch
    curl -o /opt/cronicle/node_modules/pixl-server/server.js https://raw.githubusercontent.com/dol-leodagan/pixl-server/foreground-config/server.js; \
    \
    # Cleanup
    apk del .build-deps; \
    rm -rf /var/cache/* /tmp/* /var/log/* ~/.cache; \
    mkdir -p /var/cache/apk

COPY scripts /

CMD [ "/entrypoint.sh" ]
