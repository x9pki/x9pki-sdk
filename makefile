# Makefile for X9 PKI SDK
# (c) 2025 by Massimiliano Pala and ASC X9
# All rights reserved.

# This Makefile is used to generate new test X9 PKI and to generate
# certificates for the supported use-cases. Please refer to the
# documentation for more information.
#
# This software and its components are licensed under the MIT License.
# See the LICENSE file for more information.

NOW=$(shell date +%Y%m%d)

.PHONY: help all pki list cert clean

help:
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  pki              Build all PKIs"
	@echo "  list             List supported use-cases"
	@echo "  cert <use-case>  Generate certificates for the specified use-case"
	@echo "  cert-help        Show help for certificate generation"
	@echo "  stores           Generate trust stores for the ASC X9 PKI"
	@echo "  docker-build     Builds the Docker image with OpenSSL and X9 PKI SDK"
	@echo "  docker-push      Pushes the Docker image to the openca repository"
	@echo "  clean            Clean up generated files"
	@echo "  help             Show this help message"
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

docker-build:
	@echo "Building the Docker environment..."
		@cmd="docker" ; \
	 opt="build" ; \
	 $$cmd $$opt --help 2>&1 >/dev/null; \
	 if [ $$? -gt 0 ] ; then \
	 	cmd="docker-build" ; \
		opt="" ; \
	 	$$cmd $$opt --help 2>&1 >/dev/null; \
		if [ $$? -gt 0 ]; then \
			echo && echo "    ERROR: docker cmd not detected, aborting. ($$cmd)" && echo ; \
			exit 1 ; \
		fi ; \
	fi ; \
	$$cmd $$opt -t "openca/x9pki-dev:latest" -t "openca/x9pki-dev:$(NOW)" .

docker-push:
	@echo "Pushing the Docker image to the repository..."
	@docker login && docker push "openca/x9pki-dev:latest"
	@docker login && docker push "openca/x9pki-dev:$(NOW)"
	@echo "Docker image pushed successfully."
	@echo ""

