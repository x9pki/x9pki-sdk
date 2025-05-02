# Generic Usecase for TLS and Standard Protocols

This use case provide certificates for the following scenarions:

- **TLS Server**: The CDN or VFD is the TLS server and the origin server is the TLS client.
- **TLS Client**: The CDN or VFD is the TLS client and the origin server is the TLS server.
- **Code Signing**: The CDN or VFD is the code signing authority and the origin server is the code signing client.
- **OCSP Responder**: The CDN or VFD is the OCSP responder and the origin server is the OCSP client.

More information about the QR use case can be found on the [ASC X9 website](https://x9.org/).

## TLS Server (generic-server)

The TLS Server certificate is used to secure TLS handshake. The certifcate should carry information
about the origin server that allows the client to validate it is connecting to the right server.

The certificate template is as follows:

- Certificate Policies = <x9pki-cp> (1.3.133.16.840.79.0.1)
- Authority Information Access (AIA) = <OCSP and caIssuers URLs> (not in SDK)
- Authority Key Identifier (AKID) = <Copy of the Issuer SKID>
- Subject Key Identifier (SKID) = <Calculated as per Method 1 from RFC 5280>
- Subject Alternative Name (SAN) = <DNS names of the CDN or VFD>
- Extended Key Usage = serverAuth (TLS Web Server Authentication), x9cdn (1.3.133.16.840.79.0.34)
- Key Usage = digitalSignature

The subject distinguished name (DN) is as follows:
- Organization (O) = <The organization name of the CDN or VFD (max 64 chars)>
- Common Name (CN) = <The name of the client application or device (max 64 chars)>

This certificate type is issued from:
- GENERIC Intermediate CA

## TLS Client (cdn-client)

The TLS Client certificate is used to connect to the CDN or VFD. The CDN or VFD will use
this certificate to verify the identity of the connecting client.

The certificate template is as follows:

- Certificate Policies = <x9pki-cp> (1.3.133.16.840.79.0.1)
- Authority Information Access (AIA) = <OCSP and caIssuers URLs> (not in SDK)
- Authority Key Identifier (AKID) = <Copy of the Issuer SKID>
- Subject Key Identifier (SKID) = <Calculated as per Method 1 from RFC 5280>
- Subject Alternative Name (SAN) = <DNS names of the CDN or VFD>
- Extended Key Usage = clientAuth (TLS Web Client Authentication), x9cdn (1.3.133.16.840.79.0.34)
- Key Usage = digitalSignature

The subject distinguished name (DN) is as follows:
- Organization (O) = <The organization name of the CDN or VFD (max 64 chars)>
- Common Name (CN) = <The DNS name of server interface (max 64 chars)>

This certificate type is issued from:
- GENERIC Intermediate CA