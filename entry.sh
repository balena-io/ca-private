#!/usr/bin/env bash

set -ea

[[ "${VERBOSE}" =~ on|On|Yes|yes|true|True ]] && set -x

if [[ -n "${BALENA_DEVICE_UUID}" ]]; then
    # prepend the device UUID if running on balenaOS
    TLD="${BALENA_DEVICE_UUID}.${DNS_TLD}"
else
    TLD="${DNS_TLD}"
fi

country=${COUNTRY:-US}
state=${STATE:-Washington}
locality_name=${LOCALITY_NAME:-Seattle}
org=${ORG:-balena}
org_unit=${ORG_UNIT:-balenaCloud}
# ~ 13 months (397 days) https://stackoverflow.com/a/65239775/1559300
validity_hours=${VALIDITY_HOURS:-9528}
auth_key=${AUTH_KEY:-$(openssl rand -hex 16)}
key_algo=${KEY_ALGO:-ecdsa}
key_size=${KEY_SIZE:-256}
root_ca_gen=${ROOT_CA_GEN:-0}
server_ca_gen=${SERVER_CA_GEN:-0}

mkdir -p /pki /certs/private && cd /pki

tmpjson="$(mktemp)"

function cleanup() {
   remove_update_lock
}

trap 'cleanup' EXIT

function generate_ca_config {
    cat << EOF > config.json
{
  "auth_keys": {
    "primary": {
      "type": "standard",
      "key": "${auth_key}"
    }
  },
  "signing": {
    "default": {
      "auth_key": "primary",
      "ocsp_url": "https://ocsp.${TLD}",
      "crl_url": "https://ca.${TLD}/api/v1/cfssl/crl",
      "expiry": "${validity_hours}h",
      "usages": [
        "signing",
        "key encipherment",
        "server auth"
      ]
    },
    "profiles": {
      "CA": {
        "auth_key": "primary",
        "expiry": "$(( validity_hours * 5 ))h",
        "pathlen": 0,
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "cert sign",
          "crl sign"
        ],
        "ca_constraint": {
          "is_ca": true
        }
      },
      "intermediate": {
        "usages": [
          "signing",
          "key encipherment",
          "cert sign",
          "crl sign"
        ],
        "expiry": "$(( validity_hours * 3 ))h",
        "ca_constraint": {
          "is_ca": true,
          "max_path_len": 1
        },
        "auth_key": "primary"
      },
      "ocsp": {
        "usages": [
          "digital signature",
          "ocsp signing"
        ],
        "expiry": "${validity_hours}h",
        "auth_key": "primary"
      },
      "server": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth"
        ],
        "expiry": "${validity_hours}h",
        "auth_key": "primary"
      },
      "client": {
        "usages": [
          "signing",
          "key encipherment",
          "client auth",
          "email protection"
        ],
        "expiry": "${validity_hours}h",
        "auth_key": "primary"
      }
    }
  }
}
EOF
}

function generate_root_ca {
    if ! [ -f "ca-${root_ca_gen}.pem" ]; then
        cat << EOF > "${tmpjson}"
{
  "CN": "${org} Root CA ${root_ca_gen}",
  "key": {
    "algo": "${key_algo}",
    "size": ${key_size}
  },
  "names": [
    {
      "C": "${country}",
      "L": "${locality_name}",
      "O": "${org}",
      "OU": "${org_unit}",
      "ST": "${state}"
    }
  ]
}
EOF

        cfssl gencert -initca "${tmpjson}" | cfssljson -bare "ca-${root_ca_gen}"

        rm -f "${tmpjson}"
    fi
}

function generate_server_ca {
    if ! [ -f "server-ca-${server_ca_gen}.pem" ]; then
        cat << EOF > "${tmpjson}"
{
  "CN": "${org} Server CA ${server_ca_gen}",
  "key": {
    "algo": "${key_algo}",
    "size": ${key_size}
  },
  "hosts": [
    "ca.${TLD}"
  ],
  "names": [
    {
      "C": "${country}",
      "L": "${locality_name}",
      "O": "${org}",
      "OU": "${org_unit}",
      "ST": "${state}"
    }
  ]
}
EOF

        cfssl gencert \
          -ca "ca-${root_ca_gen}.pem" \
          -ca-key "ca-${root_ca_gen}-key.pem" \
          -config config.json \
          -profile intermediate \
          "${tmpjson}" | cfssljson -bare "server-ca-${server_ca_gen}"

        rm -f "${tmpjson}"
    fi
}

function generate_ocsp_cert {
    if ! [ -f ocsp.pem ]; then
        cat << EOF > ocsp.json
{
  "CN": "${org} OCSP signer",
  "key": {
    "algo": "${key_algo}",
    "size": ${key_size}
  },
  "hosts": [
    "ocsp.${TLD}"
  ],
  "names": [
    {
      "C": "${country}",
      "L": "${locality_name}",
      "O": "${org}",
      "OU": "${org_unit}",
      "ST": "${state}"
    }
  ]
}
EOF

        cfssl gencert \
          -ca "server-ca-${server_ca_gen}.pem" \
          -ca-key "server-ca-${server_ca_gen}-key.pem" \
          -config config.json \
          -profile ocsp \
          ocsp.json | cfssljson -bare ocsp

        rm -f "${tmpjson}"
    fi
}

function set_update_lock {
    while [[ $(curl --silent --retry "${attempts}" --fail \
      "${BALENA_SUPERVISOR_ADDRESS}/v1/device?apikey=${BALENA_SUPERVISOR_API_KEY}" \
      -H "Content-Type: application/json" | jq -r '.update_pending') == 'true' ]]; do

        curl --silent --retry "${attempts}" --fail \
          "${BALENA_SUPERVISOR_ADDRESS}/v1/device?apikey=${BALENA_SUPERVISOR_API_KEY}" \
          -H "Content-Type: application/json" | jq -r

        sleep "$(( (RANDOM % 1) + 1 ))s"
    done
    sleep "$(( (RANDOM % 5) + 5 ))s"

    # https://www.balena.io/docs/learn/deploy/release-strategy/update-locking/
    lockfile /tmp/balena/updates.lock
}

function remove_update_lock() {
    rm -f /tmp/balena/updates.lock
}

function bootstrap_ca {
    generate_ca_config
    generate_root_ca
    generate_server_ca
    generate_ocsp_cert
}

set_update_lock

bootstrap_ca

remove_update_lock

if ! [ -f balena.db ]; then
    cat < /workdir/sqlite.sql | sqlite3 balena.db
fi

! [ -f ocsp_responses ] && touch ocsp_responses
cfssl ocspserve \
  -address 0.0.0.0 \
  -port 8889 \
  -responses ocsp_responses &

(while true; do
    inotifywait -e create -e modify /pki/balena.db

    for pid in $(pgrep -f 'cfssl ocspserve'); do
        kill "${pid}"
    done

    cfssl ocsprefresh \
      -db-config /workdir/sqlite.json \
      -responder ocsp.pem \
      -responder-key ocsp-key.pem \
      -ca "server-ca-${server_ca_gen}.pem" \
      && cfssl ocspdump -db-config /workdir/sqlite.json > ocsp_responses

    cfssl ocspserve \
      -address 0.0.0.0 \
      -port 8889 \
      -responses ocsp_responses &

    sleep 1s;
done) &

set_update_lock

# save root CA certificate
cat "ca-${root_ca_gen}.pem" > "/certs/private/root-ca.${TLD}.pem"

# save server CA certificate
cat "server-ca-${server_ca_gen}.pem" \
  > "/certs/private/server-ca.${TLD}.pem"

# assemble CA bundle
cat "server-ca-${server_ca_gen}.pem" "ca-${root_ca_gen}.pem" \
  > "/certs/private/ca-bundle.${TLD}.pem"

remove_update_lock

chmod 0600 /pki/*-key.pem \
  && cfssl serve \
  -address 0.0.0.0 \
  -port 8888 \
  -ca "server-ca-${server_ca_gen}.pem" \
  -ca-key "server-ca-${server_ca_gen}-key.pem" \
  -ca-bundle "ca-${root_ca_gen}.pem" \
  -int-bundle "server-ca-${server_ca_gen}.pem" \
  -db-config /workdir/sqlite.json \
  -responder ocsp.pem \
  -responder-key ocsp-key.pem \
  -config config.json &

# (TBC) implement automatic renewals
sleep infinity
