--- https://github.com/cloudflare/cfssl/tree/master/certdb/sqlite/migrations
CREATE TABLE certificates (
  serial_number            blob NOT NULL,
  authority_key_identifier blob NOT NULL,
  ca_label                 blob,
  status                   blob NOT NULL,
  reason                   int,
  expiry                   timestamp,
  revoked_at               timestamp,
  pem                      blob NOT NULL,
  PRIMARY KEY(serial_number, authority_key_identifier)
);

CREATE TABLE ocsp_responses (
  serial_number            blob NOT NULL,
  authority_key_identifier blob NOT NULL,
  body                     blob NOT NULL,
  expiry                   timestamp,
  PRIMARY KEY(serial_number, authority_key_identifier),
  FOREIGN KEY(serial_number, authority_key_identifier) REFERENCES certificates(serial_number, authority_key_identifier)
);
ALTER TABLE certificates ADD COLUMN "issued_at" timestamp;
ALTER TABLE certificates ADD COLUMN "not_before" timestamp;
ALTER TABLE certificates ADD COLUMN "metadata" text;
ALTER TABLE certificates ADD COLUMN "sans" text;
ALTER TABLE certificates ADD COLUMN "common_name" text;
