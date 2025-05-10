#!/bin/bash

# OpenSSL Command Line Tool
OSSL_CMD=$(type -path openssl)
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
  echo "-----------------------"
  echo "  eccp256 ....: Traditional ECC P-256"
  echo "  rsa2048 ....: Traditional RSA 2048"
  echo "  rsa4096 ....: Traditional RSA 4096"
  echo "  mldsa44 ....: Post-Quantum ML-DSA 44"
  echo "  mldsa87 ....: Post-Quantum ML-DSA 87"
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
    echo "list ................: List available trustchains, usecases, and formats."
    echo "issue [ options ]....: Issue a certificate bundle."
    echo "help ................: Prints this help message."
    echo 
    echo "Where [ options ] are:"
    echo "-f|--format <PEM|DER> ..: Output format (def. 'PEM')"
    echo "-o|--outdir <path> .....: Output directory (def. './newcerts/')"
    echo "-u|--usecase <name> ....: Certificate use case (i.e., cdn-client, qrcode-signer, etc.)"
    echo "-a|--altname <name> ....: Alternative names (i.e., 'DNS:*.example.com', 'IP:1.2.3.4', 'Email: ', etc.)"
    echo "-t|--trust <name> ......: Trust chain name. Use null value for the available list."
    echo "-c|--cname <val> .......: Subject CN value (e.g., 'SERVER-ID2034912-AQ')"
    echo "-q|--quiet .............: Keep the output quiet (no banner, no extra info)"
    echo "-d|--debug .............: Show debugging information"
    echo
    echo "Examples:"
    echo
    echo "   $0 list"
    echo "   $0 issue -t mldsa44 -u cdn-server -a \"DNS:myserver.x9pki.org\""
    echo "   $0 issue -t eccp256 -u qrcodes-merchant -c \"Merchant XYZ Name\""
    echo "   $0 issue -t rsa4096 -u generic-cvc"
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

    # Selects the CA's key/cert
    ISSUING_CA="generic-ica"
    SUBJECT=$GENERIC_EE_SERVER_SUBJECT_NAME
    subject_cn_fix
    
    # Checks we have a value for the altname
    if [ "x$ALTNAME" = "x" ] ; then
        echo
        echo "   ERROR: Alternative names are required for server certificates."
        echo
        exit 1
    fi

    # Copy the profile to a tmp one with the altname replaced
    EXTFILE="profiles/$USECASE.profile.tmp"
    res=$( cat "profiles/$USECASE.profile" | sed "s|@SUBJECT_ALT_NAME@|subjectAltName=$ALTNAME|g" > "$EXTFILE" )

    # Sets the variables names (translates specific-usecase
    # variables into general ones)
    EE_ALG=$GENERIC_EE_SERVER_ALG
    EE_PARAMS=$GENERIC_EE_SERVER_PARAMS
    EE_VALIDITY_DAYS=$GENERIC_EE_SERVER_VALIDITY_DAYS
  ;;
  generic-client)
    ISSUING_CA="generic-ica"
    SUBJECT=$GENERIC_EE_CLIENT_SUBJECT_NAME
    subject_cn_fix

    # Sets the variables names (translates specific-usecase
    # variables into general ones)
    EE_ALG=$GENERIC_EE_CLIENT_ALG
    EE_PARAMS=$GENERIC_EE_CLIENT_PARAMS
    EE_VALIDITY_DAYS=$GENERIC_EE_CLIENT_VALIDITY_DAYS
  ;;
  generic-cvc)
    ISSUING_CA="generic-ica"
    SUBJECT=$GENERIC_EE_CVC_SUBJECT_NAME
    subject_cn_fix

    # Sets the variables names (translates specific-usecase
    # variables into general ones)
    EE_ALG=$GENERIC_EE_CVC_ALG
    EE_PARAMS=$GENERIC_EE_CVC_PARAMS
    EE_VALIDITY_DAYS=$GENERIC_EE_CVC_VALIDITY_DAYS
  ;;
  cdn-server)
    # Selects the CA's key/cert
    ISSUING_CA="cdn-ica"
    SUBJECT=$CDN_EE_SERVER_SUBJECT_NAME
    subject_cn_fix

    # Checks we have a value for the altname
    if [ "x$ALTNAME" = "x" ] ; then
        echo
        echo "   ERROR: Alternative names are required for server certificates."
        echo
        exit 1
    fi

    # Copy the profile to a tmp one with the altname replaced
    EXTFILE="profiles/$USECASE.profile.tmp"
    res=$( cat "profiles/$USECASE.profile" | sed "s|@SUBJECT_ALT_NAME@|subjectAltName=$ALTNAME|g" > "$EXTFILE" )

    # Sets the variables names (translates specific-usecase
    # variables into general ones)
    EE_ALG=$CDN_EE_SERVER_ALG
    EE_PARAMS=$CDN_EE_SERVER_PARAMS
    EE_VALIDITY_DAYS=$CDN_EE_SERVER_VALIDITY_DAYS
  ;;
  cdn-client)
    ISSUING_CA="cdn-ica"
    SUBJECT=$CDN_EE_CLIENT_SUBJECT_NAME
    subject_cn_fix
    
    EE_ALG=$CDN_EE_CLIENT_ALG
    EE_PARAMS=$CDN_EE_CLIENT_PARAMS
    EE_VALIDITY_DAYS=$CDN_EE_CLIENT_VALIDITY_DAYS
  ;;
  iso20022-signer)
    ISSUING_CA="iso20022-ica"
    SUBJECT=$ISO20022_EE_SIGNER_SUBJECT_NAME
    subject_cn_fix
    
    EE_ALG=$ISO20022_EE_ALG
    EE_PARAMS=$ISO20022_EE_PARAMS
    EE_VALIDITY_DAYS=$ISO20022_EE_VALIDITY_DAYS
  ;;
  qrcodes-merchant)
    ISSUING_CA="qrcodes-ica"
    SUBJECT=$QRCODES_EE_MERCHANT_SUBJECT_NAME
    subject_cn_fix

    EE_ALG=$QRCODES_EE_MERCHANT_ALG
    EE_PARAMS=$QRCODES_EE_MERCHANT_PARAMS
    EE_VALIDITY_DAYS=$QRCODES_EE_MERCHANT_VALIDITY_DAYS
    ;;
  qrcodes-cardholder)
    ISSUING_CA="qrcodes-ica"
    SUBJECT=$QRCODES_EE_CARDHOLDER_SUBJECT_NAME
    subject_cn_fix

    EE_ALG=$QRCODES_EE_CARDHOLDER_ALG
    EE_PARAMS=$QRCODES_EE_CARDHOLDER_PARAMS
    EE_VALIDITY_DAYS=$QRCODES_EE_CARDHOLDER_VALIDITY_DAYS
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
if [ "x$SUBJECT" = "x" ] ; then
  SUBJECT="/CN=$COMMON_NAME"
fi

# Builds the not after value for OSSL 3.4+
if [ "$(uname)" == "Darwin" ]; then
  EE_VALIDITY_OPT="-not_after "$(date -v+${EE_VALIDITY_DAYS}d +%Y%m%d%H%M%S)"Z"
else
  EE_VALIDITY_OPT="-not_after "$(date -d "+${EE_VALIDITY_DAYS} days" +%Y%m%d%H%M%S)"Z"
fi

# Generates the private key
if [ -f "$SERVICE_DIR/$PROFILE.key" ] ; then
  echo
  echo "    ERROR: key file already exists, please remove it and try again ($SERVICE_DIR/$PROFILE.key)"
  echo
  exit 1
fi

res=$($OSSL_CMD genpkey -algorithm $EE_ALG $EE_PARAMS -outform "$FORMAT" \
        -out "$SERVICE_DIR/$PROFILE.key" 2>&1)
if [ $? -gt 0 ] ; then
  echo && echo "ERROR: Cannot create the private key." && echo
  echo $res && echo
  exit 1
fi

# Generates the CSRs
res=$($OSSL_CMD req -new -key "$SERVICE_DIR/$PROFILE.key" \
        -inform "$FORMAT" -outform "$FORMAT" -out "$SERVICE_DIR/$PROFILE.req" \
          -subj "$SUBJECT" 2>&1)
if [ $? -gt 0 ] ; then
  echo && echo "ERROR: Cannot create the CSR." && echo
  echo $res && echo
  exit 1
fi

# Generates the certificates
if [ "x$NO_SIGN" = "x" ] ; then
  res=$($OSSL_CMD x509 -req \
    -CAkey "$PREFIX_DIR/$OUT_DIR/$ISSUING_CA.key" -CAkeyform "$FORMAT" \
      -CA "$PREFIX_DIR/$OUT_DIR/$ISSUING_CA.cer" -CAform "$FORMAT" -inform "$FORMAT" \
        -outform "$FORMAT" -out "$SERVICE_DIR/$PROFILE.cer" \
          -in "$SERVICE_DIR/$PROFILE.req" -extfile "$EXTFILE" \
            $EE_VALIDITY_OPT 2>&1)

  if [ $? -gt 0 ] ; then
    echo && echo "ERROR: Cannot sign the CSR with local CA." && echo
    echo $res && echo
    exit 1
  fi

  # Builds the chain files
  res=$($OSSL_CMD x509 -inform "$FORMAT" -in "$SERVICE_DIR/$PROFILE.cer" 2>&1 > "$SERVICE_DIR/${PROFILE}.chain" \
        && $OSSL_CMD x509 -inform "$FORMAT" -in "$PREFIX_DIR/$OUT_DIR/$ISSUING_CA.cer" 2>&1 >> "$SERVICE_DIR/${PROFILE}.chain" )
  if [ $? -gt 0 ] ; then
    echo && echo "ERROR: Cannot create the local chain file (i.e., server_cert + issuing_ca_cert)." && echo
    echo $res && echo
    exit 1
  fi

  res=$($OSSL_CMD x509 -inform "$FORMAT" -in "$PREFIX_DIR/$OUT_DIR/root.cer" 2>&1 > "$SERVICE_DIR/root_ca.cer")
  if [ $? -gt 0 ] ; then
    echo && echo "ERROR: Cannot create the local root file (${SERVICE_DIR}/root_ca.cer)." && echo
    echo $res && echo
    exit 1
  fi

fi

if [ "$QUIET" = "no" ] ; then

  # Prints the banner
  banner
  echo

  # Prints the certificate bundle info
  echo "* Certificate bundle created in $SERVICE_DIR:"
  echo "  - Certificate: $SERVICE_DIR/$PROFILE.cer"
  echo "  - Private Key: $SERVICE_DIR/$PROFILE.key"
  echo "  - Chain: $SERVICE_DIR/${PROFILE}.chain"
  echo "  - Root: $SERVICE_DIR/root_ca.cer"
  echo "  - CSR: $SERVICE_DIR/$PROFILE.req"
  echo


fi

exit 0
