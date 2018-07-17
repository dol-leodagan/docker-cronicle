FROM node:alpine

ARG BUILD_DATE=now
ARG VCS_REF=local
ARG BUILD_VERSION=latest

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.version=$BUILD_VERSION \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/dol-leodagan/docker-cronicle.git" \
      org.label-schema.name="cronicle" \
      org.label-schema.description="A simple, distributed task scheduler and runner with a web based UI" \
      org.label-schema.usage="https://github.com/dol-leodagan/docker-cronicle/blob/master/README.md" \
      org.label-schema.schema-version="1.0.0-rc1" \
      maintainer="Leodagan <leodagan@freyad.net>"

WORKDIR /opt/cronicle/

RUN set -ex; \
    \
    # Get Runtime Packages
    \
    apk add --no-cache --update \
        bash curl tar procps jq ca-certificates; \
    \
    # Update Certs
    update-ca-certificates; \
    \
    # Setup Cronicle
    CRONICLE_GITHUB_API_URL="https://api.github.com/repos/jhuckaby/Cronicle/releases/latest"; \
    [ "$BUILD_VERSION" != "latest" ] && CRONICLE_GITHUB_API_URL="https://api.github.com/repos/jhuckaby/Cronicle/releases/tags/$BUILD_VERSION"; \
    # Get Release
    CRONICLE_RELEASE_URL=$(curl -s "$CRONICLE_GITHUB_API_URL" |  jq -r ".tarball_url"); \
    curl -L "$CRONICLE_RELEASE_URL" | tar xz --strip-components 1; \
    # Install
    npm install --unsafe-perm; \
    node bin/build.js dist; \
    \
    # Patch
    curl -o /opt/cronicle/node_modules/pixl-server/server.js https://raw.githubusercontent.com/dol-leodagan/pixl-server/foreground-config/server.js; \
    \
    # Cleanup
    rm -rf /var/cache/* /tmp/* /var/log/* ~/.cache; \
    mkdir -p /var/cache/apk

COPY scripts /

CMD [ "/entrypoint.sh" ]
