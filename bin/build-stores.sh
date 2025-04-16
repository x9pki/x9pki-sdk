#!/bin/bash

# This script builds the trust stores from the set of trust achors
# in the x9pki-dev/ directory.

# The script collects the root certificates from the x9pki-dev/ directory
# and builds a simple concatenated PEM file with all the trust roots
# you need to interoperate in the X9PKI DEV ecosystem (only when using the
# provided Root and Intermediate CAs).

# The script is intended to be run from the root of the repository.

# OpenSSL Command Line Tool
OSSL_CMD=$(type -path openssl)
CURR_DIR=$PWD

# Sets defaults
TRUST_STORE_PEM="x9pki-trust-store.pem"
TRUST_STORE_P7B="x9pki-trust-store.p7b"
ROOT_DIR="x9pki-dev"

# Let's reset the trust store
echo -n > $TRUST_STORE_PEM

# Info
echo && echo "* Creating PEM concatenated Trust Store ($TRUST_STORE_PEM):"

# Process the individual chains
for i in params/* ; do
  
  # Skip directories
  [ -d "$i" ] && continue

  # Loads the parameters
  . $i

  # Some Debugging Info
  echo "   - Processing $i ($ROOT_DIR/$OUT_DIR)..."
  if ! [ -d "$ROOT_DIR/$OUT_DIR" ] ; then
    echo && echo "ERROR: Directory $ROOT_DIR/$OUT_DIR does not exist." && echo
    exit 1
  fi

  # Append the root certificate to the trust store
  cat "$ROOT_DIR/$OUT_DIR/root.cer" >> $TRUST_STORE_PEM

done

# Create the p7b file from the pem file
if [ -f "$TRUST_STORE_P7B" ] ; then
    rm -f "$TRUST_STORE_P7B"
    if [ $? != 0 ] ; then
        echo && echo "ERROR: Failed to remove $TRUST_STORE_P7B." && echo
        exit 1
    fi
fi

echo && echo "Creating P7B Trust Store ($TRUST_STORE_P7B):"
$OSSL_CMD crl2pkcs7 -nocrl -certfile "$TRUST_STORE_PEM" -outform DER -out "$TRUST_STORE_P7B"
if [ $? != 0 ] ; then
  echo && echo "ERROR: Failed to create $TRUST_STORE_P7B." && echo
  exit 1
fi

exit 0