#!/bin/bash

# OpenSSL Command Line Tool
OSSL_CMD=$(type -path openssl)
CURR_DIR=$PWD

# Selects the right options for the installed OSSL version
ret=$($OSSL_CMD version | grep "3.0" )
if [ $? == 0 ] ; then
	OSSL_VALIDITY_OPT=$OSSL_30_VALIDITY_OPT
fi

# Sets the default format
if [ "x$FORMAT" = "" ] ; then
	FORMAT="PEM"
fi

# Process the individual chains
for i in params/* ; do
  
  # Skip directories
  [ -d "$i" ] && continue

  # Loads the parameters
  . $i

  # Some Debugging Info
  echo && echo "Processing $i (x9pki-dev/$OUT_DIR)..."

  # Selects the Date Command format
  if [ "$(uname)" == "Darwin" ]; then
    ROOT_VALIDITY_OPT="-not_after "$(date -v+${ROOT_VALIDITY_DAYS}d +%Y%m%d%H%M%S)"Z"
    ICA_VALIDITY_OPT="-not_after "$(date -v+${ICA_VALIDITY_DAYS}d +%Y%m%d%H%M%S)"Z"
    EE_VALIDITY_OPT="-not_after "$(date -v+${EE_VALIDITY_DAYS}d +%Y%m%d%H%M%S)"Z"
  else
    ROOT_VALIDITY_OPT="-not_after "$(date -d "+${ROOT_VALIDITY_DAYS} days" '+%Y%m%d%H%M%S')"Z"
    ICA_VALIDITY_OPT="-not_after "$(date -d "+${ICA_VALIDITY_DAYS} days" '+%Y%m%d%H%M%S')"Z"
    EE_VALIDITY_OPT="-not_after "$(date -d "+${EE_VALIDITY_DAYS} days" '+%Y%m%d%H%M%S')"Z"
  fi

  # Sets the days options depending on the version of openssl
  ret=$($OSSL_CMD version | grep "3.0" )
  if [ $? == 0 ] ; then
    ROOT_VALIDITY_OPT="-days ${ROOT_VALIDITY_DAYS}"
    ICA_VALIDITY_OPT="-days ${ICA_VALIDITY_DAYS}"
  fi

  # Creates the PKI directory, if it does not exsists
  mkdir -p "x9pki-dev/$OUT_DIR"

  # Copies the profiles and params into the pki directory
  # cp -r profiles params $OUT_DIR

  # ==================
  # Root CA Generation 
  # ==================

  if [ "x$ROOT_GENERATE" = "xyes" ] ; then
    
    echo && echo "Generating Root CA:"
    if [ -f "x9pki-dev/$OUT_DIR/root.key" ] ; then
      echo && echo "ERROR: Root key already exists." && echo
      exit 1
    fi

    echo "  - Generating Root key..."
    res=$($OSSL_CMD genpkey -algorithm $ROOT_ALG $ROOT_PARAMS \
            -outform "$FORMAT" -out "x9pki-dev/$OUT_DIR/root.key" \
              $PROVIDER 2>&1)
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: cannot generate the Root key: $res" && echo
      exit 1;
    fi

    # Generates the CSRs
    echo "  - Generating Root CSR..."
    res=$($OSSL_CMD req -new -key "x9pki-dev/$OUT_DIR/root.key" -inform "$FORMAT" \
            -out "x9pki-dev/$OUT_DIR/root.req" -outform "$FORMAT" \
            -subj "$ROOT_SUBJECT_NAME" $PROVIDER 2>&1)
    if [ $? -gt 0 ] ; then
      echo
      echo "ERROR: Cannot create the Root's CSR ($ROOT_SUBJECT_NAME)."
      echo
      echo $res
      echo
      exit 1
    fi

    # Generates the certificates
    echo "  - Signing Root CA Certificate... "
    res=$($OSSL_CMD x509 -req -key "x9pki-dev/$OUT_DIR/root.key" \
            -inform "$FORMAT" -outform "$FORMAT" -in "x9pki-dev/$OUT_DIR/root.req" \
            -out "x9pki-dev/$OUT_DIR/root.cer" -extfile "profiles/root.profile" \
            $ROOT_VALIDITY_OPT $PROVIDER 2>&1)
    if [ $? -gt 0 ] ; then
      echo
      echo "ERROR: Cannot self-sign the Root's CSR."
      echo
      echo $res
      echo
      exit 1
    fi

  else
    echo "Root CA generation skipped."
  fi

  # ===============================
  # Issuing CA Generation: ISO20022 
  # ===============================

  if [ "x$ICA_GENERATE" = "xyes" -o "x$ICA_GENERATE" = "xreq" ] ; then

    echo && echo "Generating ICA:"
    if [ -f "x9pki-dev/$OUT_DIR/ica.key" ] ; then
      echo "ERROR: ICA key already exists."
      exit 1
    fi

    echo "  - Generating ICA key..."
    res=$($OSSL_CMD genpkey -algorithm $ICA_ALG $ICA_PARAMS \
            -outform "$FORMAT" -out "x9pki-dev/$OUT_DIR/ica.key" \
            $PROVIDER 2>&1)
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: cannot generate the ICA key: $res" && echo
      exit 1;
    fi

    # Generating the ICA request
    echo "  - Generating ICA CSR..."
    res=$($OSSL_CMD req -new -key "x9pki-dev/$OUT_DIR/ica.key" -outform "$FORMAT" -outform "$FORMAT" \
            -out "x9pki-dev/$OUT_DIR/ica.req" -subj "$ICA_SUBJECT_NAME" $PROVIDER 2>&1)
    if [ $? -gt 0 ] ; then
      echo
      echo "ERROR: Cannot create the Intermediate CA's CSR."
      echo
      echo $res
      echo
      exit 1
    fi

    if [ "x$ICA_GENERATE" = "xyes" ] ; then
      echo "  - Signing ICA Certificate... "
      res=$($OSSL_CMD x509 -req -CAkey "x9pki-dev/$OUT_DIR/root.key" -CAkeyform "$FORMAT" \
              -CAform "$FORMAT" -inform "$FORMAT" -outform "$FORMAT" \
              -CA "x9pki-dev/$OUT_DIR/root.cer" -in "x9pki-dev/$OUT_DIR/ica.req" \
              -out "x9pki-dev/$OUT_DIR/ica.cer" -extfile "profiles/ica.profile" \
              $ICA_VALIDITY_OPT $PROVIDER 2>&1)
      if [ $? -gt 0 ] ; then
        echo
        echo "ERROR: Cannot create the Intermediate CA's CSR."
        echo
        echo $res
        echo
        exit 1
      fi
    else
      echo "  - ICA Request Signing skipped."
    fi

  else
    echo "ICA generation skipped."
  fi

  # Provides the PKI description
  res=$(echo \
        && echo "PKI x9pki-dev/$OUT_DIR (format: $FORMAT):" > "x9pki-dev/$OUT_DIR/description.txt" \
        && echo "  Root CA ($ROOT_ALG): root.cer" >> "x9pki-dev/$OUT_DIR/description.txt" \
        && echo "  Intermediate CA ($ICA_ALG): ica.cer" >> "x9pki-dev/$OUT_DIR/description.txt" \
        && echo )

done

echo && echo "All Done." && echo

exit 0
