# Makefile for X9 PKI SDK
# (c) 2025 by Massimiliano Pala and ASC X9
# All rights reserved.

# This Makefile is used to generate new test X9 PKI and to generate
# certificates for the supported use-cases. Please refer to the
# documentation for more information.
#
# This software and its components are licensed under the MIT License.
# See the LICENSE file for more information.

.PHONY: help all pki list cert clean

help:
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  pki              Build all PKIs"
	@echo "  list             List supported use-cases"
	@echo "  help             Show this help message"
	@echo "  cert <options>   Generate certificates (use cert-help for options)"
	@echo "  cert-help        Show help for certificate generation"
	@echo "  stores           Generate trust stores for the ASC X9 PKI"
	@echo "  clean            Clean up generated files"
	@echo ""
	@echo "Use 'make <target>' to execute the desired target."

all: pki list
	@echo "All targets completed."
	@echo ""

pki: genpki stores
	@echo "All Done."

genpki:
	@echo "Building all PKIs..."
	@bin/gen-pki.sh

list:
	@bin/gen-cert.sh list

cert:
	@echo "Generating certificates for use-case: $@"
	@bin/gen-cert.sh issue $@

cert-help:
	@bin/gen-cert.sh help

stores:
	@echo "Generating trust stores for the ASC X9 PKI..."
	@bin/build-stores.sh && echo "Trust stores generated successfully."
	@echo ""

clean:
	@echo "Cleaning up generated files..."
	@[[ -d "certs/" ]] && rm -rf certs
	@echo "Clean up completed."
	@echo ""

