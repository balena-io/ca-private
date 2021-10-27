# ca-private
> private certificate authority based on [CloudFlare's PKI/TLS toolkit](https://github.com/cloudflare/cfssl)

Generates the following private trust chain:

	depth=2 C = {{country}}, ST = {{state}}, L = {{locality_name}}, O = {{org}}, OU = {{org_unit}}, CN = {{org}} Root CA {{root_ca_gen}}
	verify error:num=19:self signed certificate in certificate chain
	verify return:1

	depth=2 C = {{country}}, ST = {{state}}, L = {{locality_name}}, O = {{org}}, OU = {{org_unit}}, CN = {{org}} Root CA {{root_ca_gen}}
	verify return:1

	depth=1 C = {{country}}, ST = {{state}}, L = {{locality_name}}, O = {{org}}, OU = {{org_unit}}, CN = {{org}} Server CA {{server_ca_gen}}
	verify return:1

	depth=0 C = {{country}}, ST = {{state}}, L = {{locality_name}}, O = {{org}}, OU = {{org_unit}}, CN = {{cn}}.{{tld}}
	verify return:1

The resulting volume will have the following structure:

	/pki
	├── balena.db
	├── ca-{{root_ca_gen}}-key.pem
	├── ca-{{root_ca_gen}}.csr
	├── ca-{{root_ca_gen}}.pem
	├── config.json
	├── ocsp-key.pem
	├── ocsp.csr
	├── ocsp.json
	├── ocsp.pem
	├── ocsp_responses
	├── server-ca-{{server_ca_gen}}-key.pem
	├── server-ca-{{server_ca_gen}}.csr
	└── server-ca-{{server_ca_gen}}.pem
