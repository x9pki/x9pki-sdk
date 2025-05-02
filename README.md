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

## Certificate Issuance

Besides the available keys and certificates that can be used for testing, the
SDK provides a set of scripts that can be used to issue new certificates for
testing purposes. The scripts are provided in the `scripts` directory and are
described in the following sections.

For the scripts to work, you need to have the following dependencies installed:
* OpenSSL 3.5.0 or later
* WolfSSL 5.4.0 or later (with Composite Signature support)

In order to issue a new certificate, execute the following command:
```bash
./scripts/issue_cert.sh <ica_key_file> <ica_cert_file> <req_file> <template>
```
Where:
* `<ica_key_file>`: The private key file of the ICA that will issue the new
  certificate.
* `<ica_cert_file>`: The certificate file of the ICA that will issue the new
  certificate.
* `<req_file>`: The request file that contains the public key and the
  certificate request.
* `<template>`: The template file to use for the configuration of the new
  certificate (OpenSSL extensions format).

The script will generate a new certificate and save it in the current directory
with the name `new_cert.pem`. The new certificate will be signed by the selected
ICA.

Please make sure you use the correct ICA when issuing the new certificate. Specifically,
the ICA must be enabled for the specific use-case. For example, if you are testing
the ISO20022 use-case, you must use the ICA that is enabled for ISO20022. Similarly,
for the CDN use-case, you must use the ICA that is enabled for CDN. 

You can then use this certificate for testing purposes only.

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

- [Generic Usecase for TLS and Standard Protocols](docs/GENERIC.md)
- [Content Distribution Network and Virtual Front Door (CDN or VFD)](docs/CDN.md)
- [ISO 20022 Payment Messages](docs/ISO20022.md)
- [Secure Payment QR Codes](docs/QRCODES.md)

# Notice

This repository makes use of scripts and logic originally implemented in the OpenCA
Labs testpki-generator repository on GitHub.

