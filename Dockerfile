# https://hub.docker.com/r/cfssl/cfssl
FROM cfssl/cfssl:1.6.1

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
