# SDK for the official X9 ASC PKI (x9pki-sdk)

This repository contains a collection of private keys, certificates, and tools
to test the use of X9 ASC PKI in a development environment. The X9 ASC SDK is
intended to be used by developers who are integrating with the X9 ASC PKI
service and need to test their integration. The SDK is not intended for
production use.

## Getting Started

This repository provides the set of private keys and certificates that mimics the
X9 ASC PKI and its supported use-cases.

Each test root is provided together with the set of private keys and certificates
that allow testing of different scenarios and interoperability situations.

For example, it is possible to install the traditional (ECDSA) and post-quantum
(ML-DSA) test roots on different clients and test the use of different options
for the server certificate, including the use of traditional, post-quantum, or
even hybrid options.

If you need or want to generate a new set of Roots and Intermediate CAs, you can
follow the documentation in [docs/PKI-GENERATION.md](docs/PKI-GENERATION.md).

## Quick Start

1. Unpack the distribution package and enter its directory (all the commands
   below are run from here):

   ```bash
   tar xzf x9pki-sdk-3.tar.gz && cd x9pki-sdk-3
   ```

2. Install the trust store on the client under test. It contains the root CA
   certificates of all the trust chains:
   * `x9pki-trust-store.pem` (PEM bundle)
   * `x9pki-trust-store.p7b` (PKCS#7)

3. List the available use-cases:

   ```bash
   make list
   ```

4. Issue an end-entity certificate from the trust chain and use-case of your
   choice:

   ```bash
   # Post-quantum TLS server certificate
   bin/gen-cert.sh issue -t mldsa44 -u generic-server -a "DNS:myserver.example.com"

   # Traditional QR Codes merchant certificate
   bin/gen-cert.sh issue -t eccp256 -u qrcodes-merchant -c "Merchant XYZ Name"
   ```

   The certificate bundle is saved in the `newcerts/` directory:
   * `<use-case>.key` - the private key
   * `<use-case>.req` - the certificate request
   * `<use-case>.cer` - the certificate
   * `<use-case>.chain` - the certificate plus the issuing CA certificate
   * `root.cer` - the root CA certificate of the trust chain

   Remove existing files from `newcerts/` before issuing a new certificate for
   the same use-case, since the script does not overwrite existing keys.

5. Configure your server (or signer) with the private key and the chain file,
   and test the connection from the client that trusts the root.

For hybrid certificates, see [Chimera Hybrid Certificates](#chimera-hybrid-certificates).

## Installation

The SDK is provided as a set of files that can be directly used in your software
or protocol implementation.

The SDK includes, for each type of certificate and
algorithm, the following files:

* A private key file in PEM format (PKCS#8 - not encrypted)
* A certificate file in PEM format (unlimited validity)
* A certificate chain file in PEM format (CA plus EE certificate)

A separate trust store file is provided that includes the root CA certificates
from the different supported test roots in two different formats: PEM and P7B.

## Trust Chains

The trust chains are stored in the `x9pki-dev/` directory. Each chain is
generated from the parameter file with the matching name in the `params/`
directory. The name used with the `-t` option of `bin/gen-cert.sh` is the part
of the file name between `x9pki-` and `-trust-anchor`.

| Type | `-t` value | Algorithms (Root / ICA / EE) |
| ---- | ---------- | ---------------------------- |
| Traditional | `rsa2048` | RSA 2048 |
| Traditional | `rsa4096` | RSA 4096 |
| Traditional | `eccp256` | ECDSA P-256 |
| Post-Quantum | `mldsa44` | ML-DSA-44 |
| Post-Quantum | `mldsa65` | ML-DSA-65 |
| Post-Quantum | `mldsa87` | ML-DSA-87 |
| Chimera Hybrid | `chimera-rsa-mldsa44` | RSA + ML-DSA-44 |
| Chimera Hybrid | `chimera-rsa2048-mldsa44` | RSA 4096 / 3072 / 2048 + ML-DSA-44 |
| Chimera Hybrid | `chimera-nist-ecdsa-mldsa44` | ECDSA P-521 / P-384 / P-256 + ML-DSA-44 |
| Chimera Hybrid | `chimera-nist-eccp256-mldsa44` | ECDSA P-256 + ML-DSA-44 |
| Chimera Hybrid | `chimera-eu-ecdsa-mldsa44` | ECDSA Brainpool P-512 / P-384 / P-256 + ML-DSA-44 |
| Chimera Hybrid | `chimera-eu-eccb256-mldsa44` | ECDSA Brainpool P-256 + ML-DSA-44 |
| Chimera Hybrid | `chimera-eddsa-mldsa44` | Ed448 / Ed448 / Ed25519 + ML-DSA-44 |
| Chimera Hybrid | `chimera-ed25519-mldsa44` | Ed25519 + ML-DSA-44 |

## Certificate Issuance

Besides the available keys and certificates that can be used for testing, the
SDK provides the `bin/gen-cert.sh` script to issue new end-entity certificates
for testing purposes.

For the script to work, you need to have the following dependencies installed:

* OpenSSL 3.5.0 or later (required for ML-DSA)
* The `x9-sdk-chimera` tool, only for the chimera hybrid trust chains (see
  [Chimera Hybrid Certificates](#chimera-hybrid-certificates))

In order to issue a new certificate, execute the following command:

```bash
bin/gen-cert.sh issue -t <trust_chain> -u <use_case> [ -a <altname> ] [ -c <common_name> ]
```

Where:

* `<trust_chain>`: The trust chain to use (see [Trust Chains](#trust-chains)).
* `<use_case>`: The type of certificate to issue (e.g., `generic-server`,
  `cdn-client`, `iso20022-signer`, `qrcodes-merchant`). Use `bin/gen-cert.sh list`
  for the full list.
* `<altname>`: Optional subject alternative name (e.g., `DNS:*.example.com`).
  The option can be repeated.
* `<common_name>`: Optional value for the CN of the certificate subject.

Use `bin/gen-cert.sh help` for the full list of options.

The script generates the private key and the request, and issues the certificate
from the Intermediate CA (ICA) of the selected trust chain that is enabled for
the selected use-case. For example, ISO20022 certificates are issued by the
ISO20022 ICA and CDN certificates are issued by the CDN ICA. The resulting files
are saved in the `newcerts/` directory.

You can then use this certificate for testing purposes only.

## Chimera Hybrid Certificates

Chimera certificates are hybrid X.509 certificates that carry two public keys
and two signatures:

* **Native** - a traditional algorithm (RSA, ECDSA, or EdDSA) in the standard
  certificate fields. Clients that are not aware of the hybrid extensions use
  this key and signature to validate the certificate as usual.
* **Alternative** - a post-quantum algorithm (ML-DSA-44) carried in the
  certificate extensions (alternative public key, signature algorithm, and
  signature value). Hybrid-aware clients can validate this signature as well.

This allows the same certificate and trust chain to be used by both traditional
and post-quantum aware clients during the migration to post-quantum
cryptography.

### Requirements

Issuing chimera certificates (and generating chimera trust chains) requires the
`x9-sdk-chimera` tool from the **x9-sdk-tools** package. The package is
distributed through a private repository and **access is granted upon
request** - please contact the X9 PKI maintainers.

After installing the package (the default location is `/opt/qtls`), load the
environment before using the SDK scripts:

```bash
source env.sh
```

This adds the tool to the `PATH` and its libraries to the `LD_LIBRARY_PATH`.
You can verify the installation with:

```bash
type -path x9-sdk-chimera
```

### Issuing Chimera Certificates

Use `bin/gen-cert.sh` with one of the `chimera-*` trust chains. The script
detects the chimera chain and uses the `x9-sdk-chimera` tool automatically:

```bash
source env.sh
bin/gen-cert.sh issue -t chimera-nist-ecdsa-mldsa44 -u generic-server -a "DNS:myserver.example.com"
```

Besides the files described in the [Quick Start](#quick-start), the bundle
includes the private key for the alternative (ML-DSA) algorithm, which is
needed by hybrid-aware software to produce the alternative signatures.

In the trust chains, the alternative private keys of the CAs are stored next to
the native ones with the `-alt` suffix (e.g., `root.key` and `root-alt.key`).

### Validation

Standard X.509 tools (e.g., OpenSSL, browsers, TLS libraries) validate chimera
certificates using the native algorithm only and ignore the alternative
signature. Validating the ML-DSA alternative signature requires hybrid-aware
software, such as the x9-sdk-tools package.

## The ASC X9 PKI

The ASC X9 PKI is a public key infrastructure (PKI) that provides a set of
certificates and keys for different use-cases relevant for the financial industry.

The PKI is multi-rooted. This means that there are multiple root CAs that can
address different cryptographic needs (e.g., traditional, post-quantum, and hybrid).
Under each individual trust chain (or trust root), there are multiple intermediate
CAs that can be used to issue end-entity certificates for different use-cases.

You can find more information about the X9 PKI in the following documents:

* [X9 ASC PKI Overview](https://www.x9pki.org/wp-content/uploads/2023/01/X9-ASC-PKI-Overview.pdf)
* [X9 ASC PKI Certificate Policy](https://www.x9.org/wp-content/uploads/2023/01/X9-ASC-PKI-Certificate-Policy.pdf)

## Supported Use-Cases

The supported use-cases are:

* [Generic Usecase for TLS and Standard Protocols](docs/GENERIC.md)
* [Content Distribution Network and Virtual Front Door (CDN or VFD)](docs/CDN.md)
* [ISO 20022 Payment Messages](docs/ISO20022.md)
* [Secure Payment QR Codes](docs/QRCODES.md)

## Notice

This repository makes use of scripts and logic originally implemented in the OpenCA
Labs testpki-generator repository on GitHub.
