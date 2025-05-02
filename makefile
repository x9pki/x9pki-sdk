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
	@echo "  cert <use-case>  Generate certificates for the specified use-case"
	@echo "  clean            Clean up generated files"
	@echo ""
	@echo "Use 'make <target>' to execute the desired target."

banner:
	@echo "X9 PKI SDK - Test Environment"
	@echo "(c) 2025 by ASC X9 and Contributors"
	@echo " All rights reserved."
	@echo ""

all: banner pki list
	@echo "All targets completed."
	@echo ""

pki:
	@echo "Building all PKIs..."
	@bin/gen-pki.sh

list:
	@echo "Listing supported use-cases..."
	@bin/gen-cert.sh --list

cert:
	@echo "Generating certificates for use-case: $(@)"
	@bin/gen-cert.sh $(@)

clean:
	@echo "Cleaning up generated files..."
	@[[ -d "certs/" ]] && rm -rf certs
	@echo "Clean up completed."
	@echo ""

