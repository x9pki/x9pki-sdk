# SDK for the official X9 ASC PKI (x9pki-sdk)

This repository contains a collection of private keys, certificates, and tools
to test the use of X9 ASC PKI in a development environment. The X9 ASC SDK is
intended to be used by developers who are integrating with the X9 ASC PKI
service and need to test their integration. The SDK is not intended for
production use.

## Getting Started

This repository provides three different test infrastructures:
* The EdDSA X9 ASC Test PKI
* The ML-DSA X9 ASC Test PKI

Each test PKI is provided together with the set of private keys and certificates
that allows to test different scenarios and interoperability situations.

For example, it is possible to install the traditional (EdDSA) and post-quantum
(ML-DSA) test PKIs on different clients and test the use of different options
for the server certificate, including the use of traditional, post-quantum, or
even hybrid options.

## Installation

The SDK is provided as a set of files that can be directly used in your software
or protocol implementation. The SDK includes, for each type of certificate and
algorithm, the following files:
* A private key file in PEM format (PKCS#8 - not encrypted)
* A certificate file in PEM format (unlimited validity)
* A certificate chain file in PEM format (CA plus EE certificate)

A separate trust store file is provided that includes the root CA certificates
from the different supported test PKIs.

## Certificate Issuance

Besides the available keys and certificates that can be used for testing, the
SDK provides a set of scripts that can be used to issue new certificates for
testing purposes. The scripts are provided in the `scripts` directory and are
described in the following sections.
