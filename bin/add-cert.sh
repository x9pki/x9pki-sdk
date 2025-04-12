#!/bin/bash

# OpenSSL Command Line Tool
OSSL_CMD=$(type -path openssl)
SUDO_CMD=$(type -path sudo)
NOW=$(date +%Y%m%d%H%M%S)

# Default Parameters
PARAMS="params/dev"
PROFILE="server"
TARGET_SERVICE="worker"
SUBJECT=""
FORMAT="PEM"
NO_SIGN=
EE_VALIDITY_DAYS=90
DEBUG=0
OWNER="root"
PERMISSIONS="600"

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
      echo "-c|config <file> .....: PKI parameters' file (def. 'params/dev')"
      echo "-p|profile <name> ....: Certificate profile (i.e., server, client, cvc, or ocsp)"
      echo "-s|subject </O=...> ..: Subject Name (def. '/OU=workers/CN=server certificate')"
      echo "-t|target <service> ..: Certificate target service (def. redis, worker, etc.)"
      echo "-n|nosign ............: Do not sign the certificate (i.e., only generate key and csr)"
      echo "-l|list ..............: List available PKIs, profiles, and formats"
      echo "-d|debug .............: Show debugging information"
      echo "-v|version ...........: Show version information"
      echo

      exit 1
      ;;
    -l|--list)
      echo "Available PKIs:"
      echo "---------------"
      ls -1 PKIs
      echo
      echo "Available Profiles:"
      echo "-------------------"
      ls -1 profiles
      echo
      echo "Available Formats:"
      echo "------------------"
      echo "  PEM"
      echo "  DER"
      echo
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
    -q|--quiet)
      exec 1>/dev/null
      shift
    ;;
    -n|--nosign)
      NO_SIGN=1
      exec 1>/dev/null
      shift
    ;;
    -c|--config)
      PARAMS=$2
      shift 2
    ;;
    -p|--profile)
      PROFILE=$2
      shift 2
    ;;
    -s| --subject)
      SUBJECT=$2
      shift 2
    ;;
    -t| --target)
      TARGET_SERVICE=$2
      shift 2
    ;;
    -o| --owner)
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
