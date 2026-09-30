# https://hub.docker.com/r/cfssl/cfssl
FROM cfssl/cfssl:v1.7.0@sha256:a4bd73ff0fcc19b2f9563431a083ec139f0e4f6a7a387de90f72ee46dc8cb360

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
