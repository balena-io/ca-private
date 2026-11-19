# https://hub.docker.com/r/cfssl/cfssl
FROM cfssl/cfssl:v1.7.2@sha256:9d1a9a42faff6f84607e5046fb1e2a3fdcd87d41e0cd8b774935ddb15423df2f

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
