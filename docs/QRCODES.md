# Payment QR Codes

This use case provide certificates for signing payment QR codes. There are two type of supported certificates for QR codes:

- **Cardholder**: The cardholder executing the transaction.
- **Merchant**: The merchant executing the transaction.

More information about the QR use case can be found in the announcement of the publication of the standard [here](https://x9.org/x9-publishes-standard-for-qr-code-protection-using-cryptography/).

## Cardholder (qrcode-cardholder)

The TLS Server certificate is used when the CDN or VFD is the TLS server and the origin server is the TLS client. The CDN or VFD will present this certificate to the client during the TLS handshake. The origin server will use this certificate to verify the identity of the CDN or VFD.

The certificate template is as follows:

- Certificate Policies = <x9pki-cp> (1.3.133.16.840.79.0.1)
- Authority Information Access (AIA) = <OCSP and caIssuers URLs> (not in SDK)
- Authority Key Identifier (AKID) = <Copy of the Issuer SKID>
- Subject Key Identifier (SKID) = <Calculated as per Method 1 from RFC 5280>
- Extended Key Usage = x9qrcodes (1.3.133.16.840.79.0.30)
- Key Usage = digitalSignature

The subject distinguished name (DN) is as follows:
- Organization (O) = <The organization name of the CDN or VFD (max 64 chars)>
- Common Name (CN) = <The DNS name of the CDN or VFD (max 64 chars)>

This certificate type is issued from:
- CDN Intermediate CA

## Merchant (qrcode-merchant)

The Merchant certificate is used to sign payment transactions. The QR Code exchange
will use this certificate to verify the identity of the merchant for the transaction.

The certificate template is as follows:

- Certificate Policies = <x9pki-cp> (1.3.133.16.840.79.0.1)
- Authority Information Access (AIA) = <OCSP and caIssuers URLs> (not in SDK)
- Authority Key Identifier (AKID) = <Copy of the Issuer SKID>
- Subject Key Identifier (SKID) = <Calculated as per Method 1 from RFC 5280>
- Key Usage = digitalSignature
- Extended Key Usage = clientAuth (TLS Web Client Authentication)
- Subject Alternative Name (SAN) = <DNS names of the CDN or VFD>

The subject distinguished name (DN) is as follows:
- Organization (O) = <The CDN or VFD organization name (max 64 chars)>
- Common Name (CN) = <The CDN or VFD DNS name (max 64 chars)>

This certificate type is issued from:
- CDN Intermediate CA