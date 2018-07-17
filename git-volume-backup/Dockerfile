FROM leodagan/cronicle:latest

ARG BUILD_DATE=now
ARG VCS_REF=local

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/dol-leodagan/docker-cronicle.git" \
      org.label-schema.name="git-volume-backup" \
      org.label-schema.description="A simple, distributed task scheduler and runner with a web based UI, embedding git-lfs and docker client" \
      org.label-schema.usage="https://github.com/dol-leodagan/docker-cronicle/blob/master/README.md" \
      org.label-schema.schema-version="1.0.0-rc1" \
      maintainer="Leodagan <leodagan@freyad.net>"

WORKDIR /opt/cronicle/

RUN set -ex; \
    \
    # Get Runtime Packages
    \
    apk add --no-cache --update \
        git-lfs docker; \
    \
    # Cleanup
    rm -rf /var/cache/* /tmp/* /var/log/* ~/.cache; \
    mkdir -p /var/cache/apk
