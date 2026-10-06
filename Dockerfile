# https://hub.docker.com/r/cfssl/cfssl
FROM cfssl/cfssl:v1.7.1@sha256:a32a9048078819d3035f5dc46637346a0e7da9df297ab234994c9a80cde10b98

RUN apt-get update && apt-get install -y --no-install-recommends \
    inotify-tools \
    jq \
    procmail \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

VOLUME /pki

COPY sqlite.* ./

COPY entry.sh /usr/local/bin/

ENTRYPOINT ["/bin/bash"]

CMD [ "-c", "/usr/local/bin/entry.sh" ]
