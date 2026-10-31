#!/bin/bash

# OpenSSL Command Line Tool
OSSL_CMD=$(type -path openssl)
X9_SDK_CMD=$(type -path x9-sdk-chimera)
SUDO_CMD=$(type -path sudo)
NOW=$(date +%Y%m%d%H%M%S)

# Prefix for chains
PREFIX_DIR="x9pki-dev"
VERSION="0.0.1"

# Default Parameters
PARAMS=""
USECASE=""
EXPORT_DIR="newcerts"
TRUST_CHAIN="mldsa44"
ALTNAME=""
COMMON_NAME=""
SUBJECT=""
FORMAT="PEM"
EE_VALIDITY_DAYS=90
EE_ALG=
EE_PARAMS=
EXTFILE=
DEBUG=0
QUIET="no"

function banner() {
  echo
  echo "X9 Financial PKI - SDK for DEV (v$VERSION)"
  echo "(c) 2025 ASC X9 Financial PKI and Contributors"
  echo "Licensed under the MIT License (see LICENSE file)"
  echo
}

# Trust Chain Usage help function
function available_chains() {
  echo "Available Trust Chains:"
  echo
  echo "* Single Algorithm Trust Chains:"
  echo "  - eccp256 ....: Traditional ECC (only P-256)"
  echo "  - rsa ........: Traditional RSA (4096/3072/2048)"
  echo "  - rsa2048 ....: Traditional RSA (only 2048)"
  echo "  - rsa4096 ....: Traditional RSA (only 4096)"
  echo "  - mldsa ......: Post-Quantum ML-DSA (87/65/44)"
  echo "  - mldsa44 ....: Post-Quantum ML-DSA-44 (only ML-DSA-44)"
  echo "  - mldsa65 ....: Post-Quantum ML-DSA-65 (only ML-DSA-65)"
  echo "  - mldsa87 ....: Post-Quantum ML-DSA-87 (only ML-DSA-87)"
  echo
  echo "* Chimera Hybrid Trust Chains:"
  echo "  - chimera-eccp-mldsa44 ......... : Chimera NIST ECDSA (P-256/384/521) + ML-DSA-44"
  echo "  - chimera-eccp256-mldsa44 ...... : Chimera NIST ECDSA Small (P-256) + ML-DSA-44"
  echo "  - chimera-bpool-mldsa44 ........ : Chimera BPool (Bpool512/384/256) + ML-DSA-44"
  echo "  - chimera-bpool256-mldsa44 ..... : Chimera BPool Small (Bpool256) + ML-DSA-44"
  echo "  - chimera-ed25519-mldsa44 ...... : Chimera EdDSA Small (Ed25519) + ML-DSA-44"
  echo "  - chimera-eddsa-mldsa44 ........ : Chimera EdDSA (Ed448/25519)+ ML-DSA-44"
  echo "  - chimera-rsa-mldsa44 .......... : Chimera RSA (RSA 4096/3072/2048) + ML-DSA-44"
  echo "  - chimera-rsa4096-mldsa44 ...... : Chimera RSA 4096 (only) + ML-DSA-44"
  echo "  - chimera-rsa2048-mldsa44 ...... : Chimera RSA Small (2048) + ML-DSA-44"
  echo
  echo "* Composite Hybrid Trust Chains:"
  echo "  - not supported, yet."
  echo
  echo "  For more information, please use the -l|--list option."
}

function available_formats() {
  echo "Available Formats:"
  echo "------------------"
  echo "  PEM"
  echo "  DER"
  echo
}

function available_usecases() {
  echo "Available Usecases:"
  echo "--------------------"
  echo ""
  echo " * Generic:"
  echo "   - TLS Server (generic-server)"
  echo "   - TLS Client (generic-client)"
  echo "   - Code Validation (generic-cvc)"
  echo
  echo " * Content Distribution Networks (CDN):"
  echo "   - TLS Server (cdn-server)"
  echo "   - TLS Client (cdn-client)"
  echo
  echo " * ISO20022 Payment Settlement:"
  echo "   - ISO20022 Payment Entity (iso20022-signer)"
  echo
  echo " * Payment QRCodes:"
  echo "   - Merchant (qrcodes-merchant)"
  echo "   - Cardholder (qrcodes-cardholder)"
  echo
}

function subject_cn_fix() {

  if [ "x$SUBJECT" = "x" ] ; then
    SUBJECT="/O=X9 Financial PKI/CN=localhost"
  fi

  if ! [ "x$COMMON_NAME" = "x" ] ; then
    res=$( echo "$SUBJECT" | sed -e "s|/CN=[^/]*|/CN=$COMMON_NAME|" )
    if [ $? -gt 0 ] ; then
      echo && echo "    ERROR: issue with replacing the CN value" && echo
      exit 1
    fi
    echo "NEW SUBJECT: $res"
    SUBJECT=$res
  fi
}

function subject_cn_fix_chimera() {

  if [ "x$SUBJECT" = "x" ] ; then
    SUBJECT="/O=X9 Financial PKI/CN=localhost"
  fi

  if ! [ "x$COMMON_NAME" = "x" ] ; then
    res=$( echo "$SUBJECT" | sed -e "s|/CN=[^/]*|/CN=$COMMON_NAME|" )
    if [ $? -gt 0 ] ; then
      echo && echo "    ERROR: issue with replacing the CN value" && echo
      exit 1
    fi
    echo "NEW SUBJECT: $res"
    SUBJECT=$res
  fi

  # Let's now remove any ',' characters from the SUBJECT
  SUBJECT=$( echo "$SUBJECT" | sed -e "s|,||g" )

  # Now let's convert any remaining '/' characters to ',' and remove the leading one
  SUBJECT=$( echo "$SUBJECT" | sed -e "s|/|,|g" -e "s|^,||" )
}

# Process the command (first argument)
case "$1" in
  help)
    if [ "$QUIET" = "no" ] ; then
      banner
    fi

    echo
    echo "Usage:"
    echo
    echo "   $0 list"
    echo "   $0 issue [ options ]"
    echo "   $0 help"
    echo
    echo "Where Cmd is:"
    echo "  list ................: List available trustchains, usecases, and formats."
    echo "  issue [ options ]....: Issue a certificate bundle."
    echo "  help ................: Prints this help message."
    echo 
    echo "Where [ options ] are:"
    echo "  -f|--format <PEM|DER> ..: Output format (def. 'PEM')"
    echo "  -o|--outdir <path> .....: Output directory (def. './newcerts/')"
    echo "  -u|--usecase <name> ....: Certificate use case (i.e., cdn-client, qrcode-signer, etc.)"
    echo "  -a|--altname <name> ....: Alternative names (i.e., 'DNS:*.example.com', 'IP:1.2.3.4', 'Email: ', etc.)"
    echo "  -t|--trust <name> ......: Trust chain name. Use null value for the available list."
    echo "  -c|--cname <val> .......: Subject CN value (e.g., 'SERVER-ID2034912-AQ')"
    echo "  -q|--quiet .............: Keep the output quiet (no banner, no extra info)"
    echo "  -d|--debug .............: Show debugging information"
    echo
    echo "Examples:"
    echo
    echo "   $0 list"
    echo "   $0 issue -t mldsa44 -u cdn-server -a \"DNS:myserver.x9pki.org\""
    echo "   $0 issue -t eccp256 -u qrcodes-merchant -c \"Merchant XYZ Name\""
    echo "   $0 issue -t chimera-rsa-mldsa44 -u generic-cvc"
    echo "   $0 help"
    echo

    exit 1
  ;;
  
  list)
    if [ "$QUIET" = "no" ] ; then
      banner
    fi

    available_chains
    echo && available_usecases
    echo && available_formats
    exit 0
  ;;
  
  version)
    echo "Version: 0.1"
    exit 0
  ;;
  
  issue)
    if [ "$QUIET" = "no" ] ; then
      banner
    fi
  ;;

  *)
    echo
    echo "    ERROR: command not recognized, supported are [list|issue]."
    echo
    exit 1
    ;;
esac

# Shifts the arg
shift 1

# Processes the command line options and allow the user
# to specify the PKI to use and the profile to use. Process
# the command line one by one
while [ "$1" != "" ] ; do
  case $1 in
    -d|--debug)
      set -x
      DEBUG=1
      shift
    ;;
    -t|--trust)
      if [ "x$2" = "x" ] ; then
        echo
        echo "    ERROR: Trust chain name is required."
        echo
        available_chains
        echo
        exit 1
      fi
      PARAMS="params/x9pki-$2-trust-anchor"
      if ! [ -f "$PARAMS" ] ; then
        echo
        echo "  ERROR: Trust chain file does not exist, aborting ($PARAMS)."
        echo
        exit 1
      fi
      shift 2
      ;;
    -u|--usecase)
      USECASE=$2
      if [ "x$2" = "x" ] ; then
        echo
        echo "    ERROR: Usecase is required."
        echo
        echo "For the supported usecases, please use the -l|--list option."
        echo
        exit 1
      fi
      shift 2
    ;;
    -a|--altname)
      if [ "x$ALTNAME" = "x" ] ; then
        ALTNAME=$2
      else
        ALTNAME="$ALTNAME,$2"
      fi
      shift 2
    ;;
    -c|--cname)
      if [ "$2" != "" ] ; then
        COMMON_NAME="$2"
      else
        echo
        echo "    ERROR: missing common name's value ('-c|--cname')."
        echo
        exit 1
      fi
      shift 2
    ;;
    *)
      if [ "$1" != "" ] ; then
        echo "Unknown option: $1"
        exit 1
      fi
    ;;
  esac
done

# Loads the parameters
. $PARAMS

# Sets initial values
EXTFILE="profiles/$USECASE.profile"
PROFILE=$USECASE

# Sets CN as AltName
if [ "x$ALTNAME" = "x" ] ; then
  if ! [ "x$COMMON_NAME" = "x" ] ; then
    ALTNAME="subjectAltName=DNS:$COMMON_NAME"
  fi
fi

# Checks the use-case is one of the supported ones
case $USECASE in
  generic-server)
    ICA_VAR="GENERIC_ICA"
    EE_VAR="GENERIC_EE_SERVER"

    # Checks we have a value for the altname
    if [ "x$ALTNAME" = "x" ] ; then
        echo
        echo "   ERROR: Alternative names are required for server certificates."
        echo
        exit 1
    fi
  ;;

  generic-client)
    ICA_VAR="GENERIC_ICA"
    EE_VAR="GENERIC_EE_CLIENT"
  ;;

  generic-cvc)
    ICA_VAR="GENERIC_ICA"
    EE_VAR="GENERIC_EE_CVC"
  ;;

  cdn-server)
    ICA_VAR="CDN_ICA"
    EE_VAR="CDN_EE_SERVER"

    # Checks we have a value for the altname
    if [ "x$ALTNAME" = "x" ] ; then
        echo
        echo "   ERROR: Alternative names are required for server certificates."
        echo
        exit 1
    fi
  ;;

  cdn-client)
    ICA_VAR="CDN_ICA"
    EE_VAR="CDN_EE_CLIENT"
  ;;

  iso20022-signer)
    ICA_VAR="ISO20022_ICA"
    EE_VAR="ISO20022_EE"
  ;;

  qrcodes-merchant)
    ICA_VAR="QRCODES_ICA"
    EE_VAR="QRCODES_EE_MERCHANT"
  ;;

  qrcodes-cardholder)
    ICA_VAR="QRCODES_ICA"
    EE_VAR="QRCODES_EE_CARDHOLDER"
  ;;

  *)
    echo
    echo "Unknown use-case: $USECASE"
    echo
    available_usecases
    echo
    exit 1
    ;;
esac

ICA_HYBRID_TYPE_VAR="${ICA_VAR}_HYBRID_TYPE"

ICA_KEY_VAR="${ICA_VAR}_KEY"
ICA_ALT_KEY_VAR="${ICA_VAR}_ALT_KEY"
ICA_CERT_VAR="${ICA_VAR}_CERT"

## ----- Issuing CA values

ICA_DIR="$OUT_DIR"

ICA_HYBRID_TYPE="${!ICA_HYBRID_TYPE_VAR}"

ICA_KEY="x9pki-dev/$ICA_DIR/${!ICA_KEY_VAR}"
ICA_ALT_KEY="x9pki-dev/$ICA_DIR/${!ICA_ALT_KEY_VAR}"
ICA_CERT="x9pki-dev/$ICA_DIR/${!ICA_CERT_VAR}"

## End Entity:

## ----- End Entity variables

EE_HYBRID_TYPE_VAR="${EE_VAR}_HYBRID_TYPE"

EE_KEY_VAR="${EE_VAR}_KEY"
EE_ALG_VAR="${EE_VAR}_ALG"
EE_PARAMS_VAR="${EE_VAR}_PARAMS"

EE_ALT_KEY_VAR="${EE_VAR}_ALT_KEY"
EE_ALT_ALG_VAR="${EE_VAR}_ALT_ALG"
EE_ALT_PARAMS_VAR="${EE_VAR}_ALT_PARAMS"

EE_EXTFILE_VAR="${EE_VAR}_TEMPLATE"

EE_REQ_VAR="${EE_VAR}_REQ"
EE_CERT_VAR="${EE_VAR}_CERT"
EE_CHAIN_VAR="${EE_VAR}_CHAIN"
EE_VALIDITY_DAYS_VAR="${EE_VAR}_VALIDITY_DAYS"

## ----- End Entity values

EE_HYBRID_TYPE="${!EE_HYBRID_TYPE_VAR}"

EE_ALG="${!EE_ALG_VAR}"
EE_KEY="${!EE_KEY_VAR}"
EE_PARAMS="${!EE_PARAMS_VAR}"

EE_ALT_ALG="${!EE_ALT_ALG_VAR}"
EE_ALT_KEY="${!EE_ALT_KEY_VAR}"
EE_ALT_PARAMS="${!EE_ALT_PARAMS_VAR}"

EE_REQ="${!EE_REQ_VAR}"
EE_CERT="${!EE_CERT_VAR}"
EE_VALIDITY_DAYS="${!EE_VALIDITY_DAYS_VAR}"
EE_CHAIN="${!EE_CHAIN_VAR}"

EE_EXTFILE="${!EE_EXTFILE_VAR}"
EXTFILE="profiles/${EE_EXTFILE}.tmp"

# Copy the profile to a tmp one with the altname replaced
res=$( cat "profiles/${EE_EXTFILE}" | sed "s|@SUBJECT_ALT_NAME@|subjectAltName=$ALTNAME|g" > "$EXTFILE" )

# Checks we have the chain and the usecase
if [ "x$TRUST_CHAIN" = "x" ] ; then
  echo
  echo "    ERROR: missing trust chain name, aborting."
  echo
  exit 1
fi

if [ "x$PROFILE" = "x" ] ; then
  echo
  echo "    ERROR: missing usecase parameter, aborting."
  echo
  exit 1
fi

# Builds the output direct
if ! [ "x$EXPORT_DIR" = "x" ] ; then
  SERVICE_DIR="$EXPORT_DIR"
else
  SERVICE_DIR="newcerts"
fi

# Makes the service's directory
if ! [ -d "$SERVICE_DIR" ] ; then
  mkdir -p "$SERVICE_DIR"
fi

# Builds a default subject, if none was given
if [ "$ICA_HYBRID_TYPE" = "chimera" ]; then
  subject_cn_fix_chimera
else
  subject_cn_fix
fi

# Builds the not after value for OSSL 3.4+
if [ "$(uname)" == "Darwin" ]; then
  EE_VALIDITY_OPT="-not_after "$(date -v+${EE_VALIDITY_DAYS}d +%Y%m%d%H%M%S)"Z"
else
  EE_VALIDITY_OPT="-not_after "$(date -d "+${EE_VALIDITY_DAYS} days" +%Y%m%d%H%M%S)"Z"
fi

# Generates the private key
if [ -f "$SERVICE_DIR/$EE_KEY" ] ; then
  echo
  echo "    ERROR: key file already exists, please remove it and try again ($EE_KEY)"
  echo
  exit 1
fi

if [ -n "$EE_ALT_KEY" -a -f "$SERVICE_DIR/$EE_ALT_KEY" ] ; then
  echo
  echo "    ERROR: alternate key file already exists, please remove it and try again ($EE_ALT_KEY)"
  echo
  exit 1
fi

if ! [ -f "$ICA_KEY" ]; then
  echo
  echo "    ERROR: ICA key file not found ($ICA_KEY)"
  echo
  exit 1
fi

if ! [ -f "$ICA_CERT" ]; then
  echo
  echo "    ERROR: ICA certificate file not found ($ICA_CERT)"
  echo
  exit 1
fi

if [ "$ICA_HYBRID_TYPE" = "chimera" ] ; then
  if ! [ -f "$ICA_ALT_KEY" ]; then
    echo
    echo "    ERROR: ICA alternate key file not found ($ICA_ALT_KEY)"
    echo
    exit 1
  fi
fi

echo "* Processing end-entity certificate generation:"

if [ "$ICA_HYBRID_TYPE" = "chimera" ]; then
  echo "  - Generating private key for the end-entity (chimera)..."
  res=$($X9_SDK_CMD genpkey \
          -outform "$FORMAT" \
          -native_key_alg "$EE_ALG" $EE_PARAMS \
          -native_key_out "$SERVICE_DIR/$EE_KEY" \
          -alt_key_alg "$EE_ALT_ALG" $EE_ALT_PARAMS \
          -alt_key_out "$SERVICE_DIR/$EE_ALT_KEY" 2>&1)
  if [ $? -gt 0 ] ; then
    echo && echo "ERROR: Cannot create the private key." && echo
    echo "$res" && echo
    exit 1
  fi
else
  echo "  - Generating private key for the end-entity..."
  res=$($OSSL_CMD genpkey -algorithm $EE_ALG $EE_PARAMS -outform "$FORMAT" \
          -out "$SERVICE_DIR/$EE_KEY" 2>&1)
  if [ $? -gt 0 ] ; then
    echo && echo "ERROR: Cannot create the private key." && echo
    echo "$res" && echo
    exit 1
  fi
fi

# Generates the CSRs
if [ "$ICA_HYBRID_TYPE" = "chimera" ]; then
  echo "  - Generating CSR for the end-entity (chimera)..."
  res=$($X9_SDK_CMD genreq \
          -outform "$FORMAT" \
          -subject_key "$SERVICE_DIR/$EE_KEY" \
          -subject_alt_key "$SERVICE_DIR/$EE_ALT_KEY" \
          -out "$SERVICE_DIR/$EE_REQ" \
          -subject "$SUBJECT" 2>&1)
  if [ $? -gt 0 ] ; then
    echo && echo "ERROR: Cannot create the CSR." && echo
    echo "$res" && echo
    exit 1
  fi
else
  echo "  - Generating CSR for the end-entity..."
  res=$($OSSL_CMD req -new -key "$SERVICE_DIR/$EE_KEY" \
          -inform "$FORMAT" -outform "$FORMAT" -out "$SERVICE_DIR/$EE_REQ" \
            -subj "$SUBJECT" 2>&1)
  if [ $? -gt 0 ] ; then
    echo && echo "ERROR: Cannot create the CSR." && echo
    echo "$res" && echo
    exit 1
  fi
fi

# Generates the certificates
if [ "x$NO_SIGN" = "x" ] ; then
  if [ "$ICA_HYBRID_TYPE" = "chimera" ]; then
    echo "  - Generating chimera Certificate for the end-entity (chimera)..."
    res=$($X9_SDK_CMD gencert \
           -outform "$FORMAT" \
           -req "$SERVICE_DIR/$EE_REQ" \
           -ca_native_key "$ICA_KEY" \
           -ca_alt_key "$ICA_ALT_KEY" \
           -ca_cert "$ICA_CERT" \
           -extfile "$EXTFILE" \
           -out "$SERVICE_DIR/$EE_CERT" \
              $EE_VALIDITY_OPT 2>&1)
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: Cannot sign the CSR with local CA." && echo
      echo "$res" && echo
      exit 1
    fi
  else
    res=$($OSSL_CMD x509 -req \
      -CAkey "$ICA_KEY" -CAkeyform "$FORMAT" \
        -CA "$ICA_CERT" -CAform "$FORMAT" -inform "$FORMAT" \
          -outform "$FORMAT" -out "$SERVICE_DIR/$EE_CERT" \
            -in "$SERVICE_DIR/$EE_REQ" -extfile "$EXTFILE" \
              $EE_VALIDITY_OPT 2>&1)

    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: Cannot sign the CSR with local CA." && echo
      echo "$res" && echo
      exit 1
    fi
  fi

  # Builds the chain files
  res=$($OSSL_CMD x509 -inform "$FORMAT" -in "$SERVICE_DIR/$EE_CERT" 2>&1 > "$SERVICE_DIR/$EE_CHAIN" \
        && $OSSL_CMD x509 -inform "$FORMAT" -in "$ICA_CERT" 2>&1 >> "$SERVICE_DIR/$EE_CHAIN" )
  if [ $? -gt 0 ] ; then
    echo && echo "ERROR: Cannot create the local chain file (i.e., server_cert + issuing_ca_cert)." && echo
    echo "$res" && echo
    exit 1
  fi

  res=$($OSSL_CMD x509 -inform "$FORMAT" -in "x9pki-dev/$ICA_DIR/$ROOT_CERT" 2>&1 > "$SERVICE_DIR/$ROOT_CERT")
  if [ $? -gt 0 ] ; then
    echo && echo "ERROR: Cannot create the local root file ($ROOT_CERT)." && echo
    echo "$res" && echo
    exit 1
  fi

fi

if [ "$QUIET" = "no" ] ; then

  # Prints the certificate bundle info
  echo
  echo "* Certificate bundle created (folder: $SERVICE_DIR):"
  echo "  - Request: $SERVICE_DIR/$EE_REQ"
  echo "  - Private Key: $SERVICE_DIR/$EE_KEY"
  echo "  - Certificate: $SERVICE_DIR/$EE_CERT"
  echo "  - Chain: $SERVICE_DIR/$EE_CHAIN"
  echo "  - Root: $SERVICE_DIR/$ROOT_CERT"
  echo

fi

exit 0
