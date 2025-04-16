# PKI Generator

This package provides a set of shared Trust Anchors and tool to quickly test
full PKI infrastructure. The issued certificates use minimal profiles
to ensure (a) no-expiration, and (b) compatibility.

## PKI Gen Script Usage

This package uses a makefile to execute the bin/gen-pki.sh script. The script
loads the parameters' files (one at a time) and generates the PKI according to
the provided parameters in the file.

Each parameter file provides the configuration for the Root, Intermediate, and
End Entity certificates. When the script is executed, each of the parameters'
files is executed and the configured chain is issued: private keys, certificates,
and convenient chain files.

To generate all configured use-cases, simply use the makefile default target:

```bash
$ bin/pki-gen.sh
Loading params/rsa4096-root ...
```

## Support

Please direct all your inquiries at Dr. Pala `<director@openca.org>`

Enjoy the ASC X9 PKI!
Dr. Pala
