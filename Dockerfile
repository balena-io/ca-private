# https://hub.docker.com/r/cfssl/cfssl
FROM cfssl/cfssl:v1.6.5@sha256:c9018c2ddf0b1f8dbef166057cc751d1becd5c3b0b7014cb9fe06972f725106f

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
