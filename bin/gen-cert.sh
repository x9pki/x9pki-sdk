#!/bin/bash

# OpenSSL Command Line Tool
OSSL_CMD=$(type -path openssl)
SUDO_CMD=$(type -path sudo)
NOW=$(date +%Y%m%d%H%M%S)

# Default Parameters
PARAMS=""
USECASE=""
ALTNAME=""
COMMON_NAME="X9 DEV Certificate"
SUBJECT=""
FORMAT="PEM"
EE_VALIDITY_DAYS=90
DEBUG=0
OWNER=$(whoami)
PERMISSIONS="600"
EXPORT_DIR=""

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
  echo " * Payment QRCode:"
  echo "   - Merchant (qrcode-merchant)"
  echo "   - Cardholder (qrcode-cardholder)"
}

# Processes the command line options and allow the user
# to specify the PKI to use and the profile to use. Process
# the command line one by one
while [ "$1" != "" ] ; do
  case $1 in
    -h|--help)
      echo
      echo "Usage: $0 [ -config params/dev ] [-profile <server | client | ...>] [-subject </O=...>] [-target < redis | issuer | etc. > ]"
      echo
      echo "Defaults as follows:"
      echo "-l|list ..............: List available PKIs, profiles, and formats"
      echo "-t|trust-chain <name> : Trust chain name (use -l for the list of supported ones)"
      echo "-u|usecase <name> ....: Certificate use case (i.e., cdn-client, qrcode-signer, etc.)"
      echo "-a|altname <name> ....: Alternative names (i.e., DNS:*.example.com, IP:1.2.3.4, Email:...)"
      echo "-c|commonName <val> ..: Subject CN value (e.g., 'SERVER-ID2034912-AQ')"
      echo "-f|format <PEM|DER> ..: Output format (def. 'PEM')"
      echo "-o|owner <user> ......: Owner of the private key (def. 'root')"
      echo "-v|version ...........: Show version information"
      echo "-d|debug .............: Show debugging information"
      echo

      exit 1
      ;;
    -l|--list)
      echo && available_chains
      echo && available_usecases
      echo && available_formats
      exit 0
      ;;
    -v|--version)
      echo "Version: 0.1"
      exit 0
      ;;
    -d|--debug)
      set -x
      DEBUG=1
      shift
    ;;
    -t|--trust-chain)
      if [ "x$2" = "x" ] ; then
        echo
        echo "    ERROR: Trust chain name is required."
        echo
        echo "For the supported chains, please use the -l|--list option."
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
      ALTNAME=$2
      shift 2
    ;;
    -c|--commonName)
      if [ "$2" != "" ] ; then
        COMMON_NAME="$2"
      else
        COMMON_NAME="X9 DEV Certificate"
      fi
      shift 2
    ;;
    -o|--owner)
      OWNER=$2
      shift 2
    ;;
    -r| --permissions)
      PERMISSIONS=$2
      shift 2
    ;;
    -x| --xport)
      EXPORT_DIR=$2
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

# Checks the use-case is one of the supported ones
case $USECASE in
  generic-server)
    PROFILE=$USECASE
    ROOT_CA="generic-ica"
    ISSUING_ICA=""
    SUBJECT="/O=X9 Financial PKI/OU=Generic Issuing CA, CN=$COMMON_NAME"
    if [ "x$ALTNAME" = "x" ] ; then
      echo
      echo "   ERROR: Alternative names are required for server certificates."
      echo
      exit 1
    fi
  ;;
  generic-client)
  ;;
  code-signer)
  ;;
  cdn-server|cdn-client)
  ;;
  iso20022-signer)
  ;;
  qrcode-signer)
    PROFILE=$USECASE
    ;;
  *)
    echo
    echo "Unknown use-case: $USECASE"
    echo
    echo "Please specify one of the following use-cases:"
    echo "- generic-server"
    echo "- generic-client"
    echo "- code-signer"
    echo "- cdn-server"
    echo "- cdn-client"
    echo "- iso20022-signer"
    echo "- qrcode-signer"
    echo
    echo "For more information, please use the -l|--list option."
    echo
    exit 1
    ;;
esac

# Some Debugging Info
echo "Loading $PARAMS ..."
if ! [ -f "$PARAMS" ] ; then
  echo
  echo "    ERROR: params file does not exists ($PARAMS)"
  echo
  exit 1
fi

# Loads the parameters
. $PARAMS

# Builds the output direct
if ! [ "x$EXPORT_DIR" = "x" ] ; then
  SERVICE_DIR="$EXPORT_DIR"
else
  if [ "x$TARGET_SERVICE" = "x" ] ; then
    TARGET_SERVICE="worker"
  fi
  SERVICE_DIR="services.d/${TARGET_SERVICE}"
fi

# Makes the service's directory
if ! [ -d "$SERVICE_DIR" ] ; then
  mkdir -p "$SERVICE_DIR"
fi

# Builds a default subject, if none was given
if [ "x$SUBJECT" = "x" ] ; then
  SUBJECT="/CN=$TARGET_SERVICE"
fi

# Builds the not after value for OSSL 3.4+
if [ "$(uname)" == "Darwin" ]; then
  EE_VALIDITY_OPT="-not_after "$(date -v+${EE_VALIDITY_DAYS}d +%Y%m%d%H%M%S)"Z"
else
  EE_VALIDITY_OPT="-not_after "$(date -d "+${EE_VALIDITY_DAYS} days" +%Y%m%d%H%M%S)"Z"
fi

# Selects the right options for the installed OSSL version
ret=$($OSSL_CMD version | grep "3.0" )
if [ $? == 0 ] ; then
  EE_VALIDITY_OPT="-days ${EE_VALIDITY_DAYS}"
fi

# Generates the private key
if [ -f "$SERVICE_DIR/$PROFILE.key" ] ; then \
  $SUDO_CMD rm "$SERVICE_DIR/$PROFILE.key" ; \
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
    -CAkey "$OUT_DIR/private/ica.key" -CAkeyform "$FORMAT" \
      -CA "$OUT_DIR/certs/ica.cer" -CAform "$FORMAT" -inform "$FORMAT" \
        -outform "$FORMAT" -out "$SERVICE_DIR/$PROFILE.cer" \
          -in "$SERVICE_DIR/$PROFILE.req" -extfile "profiles/$PROFILE.profile" \
            $EE_VALIDITY_OPT 2>&1)
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: Cannot sign the CSR with local CA." && echo
      echo $res && echo
      exit 1
    fi

    # Builds the chain files
    res=$($OSSL_CMD x509 -inform "$FORMAT" -in "$SERVICE_DIR/$PROFILE.cer" 2>&1 > "$SERVICE_DIR/${PROFILE}.chain" \
          && $OSSL_CMD x509 -inform "$FORMAT" -in "$OUT_DIR/certs/ica.cer" 2>&1 >> "$SERVICE_DIR/${PROFILE}.chain" )
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: Cannot create the local chain file (i.e., server_cert + issuing_ca_cert)." && echo
      echo $res && echo
      exit 1
    fi

    res=$($OSSL_CMD x509 -inform "$FORMAT" -in "$OUT_DIR/certs/root.cer" 2>&1 > "$SERVICE_DIR/root_ca.cer")
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: Cannot create the local root file (${SERVICE_DIR}/root_ca.cer)." && echo
      echo $res && echo
      exit 1
    fi

  # Setting permissions on the private keys
  if ! [ "x$PERMISSIONS" = "x" ] ; then
    res=$($SUDO_CMD chmod "$PERMISSIONS" "$SERVICE_DIR/$PROFILE.key" 2>&1)
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: Cannot set permissions on private key to root ($SERVICE_DIR/$PROFILE.key)." && echo
      echo $res && echo
      exit 1
    fi
  fi

  if ! [ "x$OWNER" = "x" ] ; then
    res=$($SUDO_CMD chown $OWNER "$SERVICE_DIR/$PROFILE.key" 2>&1)
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: Cannot set ownership of private key ($OWNER for $SERVICE_DIR/$PROFILE.key)." && echo
      echo $res && echo
      exit 1
    fi
  fi

fi

# Provides the Certificate description
res=$(cd $OUT_DIR \
      && echo "PKI $OUT_DIR (format: $FORMAT):" \
      && echo "  Profile: $PROFILE" \
      && echo "  Algorithm: $EE_ALG" \
      && echo "  Subject DN: $SUBJECT" \
      && echo "  Output File ($EE_ALG): $SERVICE_DIR/$PROFILE.cer" )

exit 0
