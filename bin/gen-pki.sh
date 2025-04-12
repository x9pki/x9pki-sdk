#!/bin/bash

# OpenSSL Command Line Tool
OSSL_CMD=$(type -path openssl)
CURR_DIR=$PWD

# Sets the default format
if [ "x$FORMAT" = "" ] ; then
	FORMAT="PEM"
fi

# Let's reset the trust store
echo -n > x9pki-trust-store.pem

# Process the individual chains
for i in params/* ; do
  
  # Skip directories
  [ -d "$i" ] && continue

  # Loads the parameters
  . $i

  # Some Debugging Info
  echo && echo "Processing $i (x9pki-dev/$OUT_DIR)..."

  # # Selects the Date Command format
  # if [ "$(uname)" == "Darwin" ]; then
  #   ROOT_VALIDITY_OPT="-not_after "$(date -v+${ROOT_VALIDITY_DAYS}d +%Y%m%d%H%M%S)"Z"
  #   ICA_VALIDITY_OPT="-not_after "$(date -v+${ICA_VALIDITY_DAYS}d +%Y%m%d%H%M%S)"Z"
  #   EE_VALIDITY_OPT="-not_after "$(date -v+${EE_VALIDITY_DAYS}d +%Y%m%d%H%M%S)"Z"
  # else
  #   ROOT_VALIDITY_OPT="-not_after "$(date -d "+${ROOT_VALIDITY_DAYS} days" '+%Y%m%d%H%M%S')"Z"
  #   ICA_VALIDITY_OPT="-not_after "$(date -d "+${ICA_VALIDITY_DAYS} days" '+%Y%m%d%H%M%S')"Z"
  #   EE_VALIDITY_OPT="-not_after "$(date -d "+${EE_VALIDITY_DAYS} days" '+%Y%m%d%H%M%S')"Z"
  # fi

  # # Sets the days options depending on the version of openssl
  # ret=$($OSSL_CMD version | grep "3.0" )
  # if [ $? == 0 ] ; then
  #   ROOT_VALIDITY_OPT="-days ${ROOT_VALIDITY_DAYS}"
  #   ICA_VALIDITY_OPT="-days ${ICA_VALIDITY_DAYS}"
  # fi

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

    if ! [ "x$ROOT_VALIDITY_DAYS" == "x" ] ; then
      ROOT_VALIDITY_OPT="-days ${ROOT_VALIDITY_DAYS}"
    else
      if ! [ "x$ROOT_VALIDITY_NOTBEFORE" == "x" ] ; then
        ROOT_VALIDITY_OPT="-not_before $ROOT_VALIDITY_NOTBEFORE"
      else
        ROOT_VALIDITY_OPT="-not_before 20250101000000Z"
      fi
      if ! [ "x$ROOT_VALIDITY_NOTAFTER" == "x" ] ; then
        ROOT_VALIDITY_OPT="-not_after $ROOT_VALIDITY_NOTAFTER"
      else
        ROOT_VALIDITY_OPT="-not_after 99991231125959Z"
      fi
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

    # Adding the Root CA certificate to the trust store
    cat x9pki-dev/$OUT_DIR/root.cer >> "x9pki-trust-store.pem"
    if [ $? -gt 0 ] ; then
      echo
      echo "ERROR: Cannot add the Root CA certificate to the trust store."
      echo
      exit 1
    fi

    echo "Root CA certificate added to trust store."

    # Cleanup
    rm -f "x9pki-dev/$OUT_DIR/root.req"

  else
    echo "Root CA generation skipped."
  fi

            # ============
            # CDN Use-Case
            # ============

  if [ "x$CDN_ICA_GENERATE" = "xyes" -o "x$CDN_ICA_GENERATE" = "xreq" ] ; then

    echo && echo "Generating CDN ICA:"
    if [ -f "x9pki-dev/$OUT_DIR/cdn-ica.key" ] ; then
      echo "ERROR: CDN ICA key already exists."
      exit 1
    fi

    echo "  - Generating CDN ICA key..."
    res=$($OSSL_CMD genpkey -algorithm $CDN_ICA_ALG $CDN_ICA_PARAMS \
            -outform "$FORMAT" -out "x9pki-dev/$OUT_DIR/cdn-ica.key" \
            $PROVIDER 2>&1)
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: cannot generate the ICA key: $res" && echo
      exit 1;
    fi

    # Generating the ICA request
    echo "  - Generating CDN ICA CSR..."
    res=$($OSSL_CMD req -new -key "x9pki-dev/$OUT_DIR/cdn-ica.key" -outform "$FORMAT" -outform "$FORMAT" \
            -out "x9pki-dev/$OUT_DIR/cdn-ica.req" -subj "$CDN_ICA_SUBJECT_NAME" $PROVIDER 2>&1)
    if [ $? -gt 0 ] ; then
      echo
      echo "ERROR: Cannot create the Intermediate CA's CSR."
      echo
      echo $res
      echo
      exit 1
    fi

    if ! [ "x$CDN_ICA_DAYS" == "x" ] ; then
      CDN_ICA_VALIDITY_OPT="-days ${CDN_ICA_VALIDITY_DAYS}"
    else
      if ! [ "x$CDN_ICA_VALIDITY_NOTBEFORE" == "x" ] ; then
        CDN_ICA_VALIDITY_OPT="-not_before $CDN_ICA_VALIDITY_NOTBEFORE"
      else
        CDN_ICA_VALIDITY_OPT="-not_before 20250101000000Z"
      fi
      if ! [ "x$CDN_ICA_VALIDITY_NOTAFTER" == "x" ] ; then
        CDN_ICA_VALIDITY_OPT="-not_after $CDN_ICA_VALIDITY_NOTAFTER"
      else
        CDN_ICA_VALIDITY_OPT="-not_after 99991231125959Z"
      fi
    fi

    if [ "x$CDN_ICA_GENERATE" = "xyes" ] ; then
      echo "  - Signing CDN ICA Certificate... "
      res=$($OSSL_CMD x509 -req -CAkey "x9pki-dev/$OUT_DIR/root.key" -CAkeyform "$FORMAT" \
              -CAform "$FORMAT" -inform "$FORMAT" -outform "$FORMAT" \
              -CA "x9pki-dev/$OUT_DIR/root.cer" -in "x9pki-dev/$OUT_DIR/cdn-ica.req" \
              -out "x9pki-dev/$OUT_DIR/cdn-ica.cer" -extfile "profiles/cdn-ica.profile" \
              $CDN_ICA_VALIDITY_OPT $PROVIDER 2>&1)
      if [ $? -gt 0 ] ; then
        echo
        echo "ERROR: Cannot create the CDN Intermediate CA's certificate."
        echo
        echo $res
        echo
        exit 1
      fi

      # Cleanup
      rm -f "x9pki-dev/$OUT_DIR/cdn-ica.req"

    else
      echo "  - CDN ICA Request Signing skipped."
    fi

  else
    echo "CDN ICA generation skipped."
  fi


            # =================
            # ISO20022 Use-Case
            # =================

  if [ "x$ISO20022_ICA_GENERATE" = "xyes" -o "x$ISO20022_ICA_GENERATE" = "xreq" ] ; then

    echo && echo "Generating ISO20022 ICA:"
    if [ -f "x9pki-dev/$OUT_DIR/iso20022-ica.key" ] ; then
      echo "ERROR: ISO20022 ICA key already exists."
      exit 1
    fi

    echo "  - Generating ISO20022 ICA key..."
    res=$($OSSL_CMD genpkey -algorithm $ISO20022_ICA_ALG $ISO20022_ICA_PARAMS \
            -outform "$FORMAT" -out "x9pki-dev/$OUT_DIR/iso20022-ica.key" \
            $PROVIDER 2>&1)
    if [ $? -gt 0 ] ; then
      echo && echo "ERROR: cannot generate the ICA key: $res" && echo
      exit 1;
    fi

    # Generating the ICA request
    echo "  - Generating ISO20022 ICA CSR..."
    res=$($OSSL_CMD req -new -key "x9pki-dev/$OUT_DIR/iso20022-ica.key" -outform "$FORMAT" -outform "$FORMAT" \
            -out "x9pki-dev/$OUT_DIR/iso20022-ica.req" -subj "$ISO20022_ICA_SUBJECT_NAME" $PROVIDER 2>&1)
    if [ $? -gt 0 ] ; then
      echo
      echo "ERROR: Cannot create the ISO20022 Intermediate CA's CSR."
      echo
      echo $res
      echo
      exit 1
    fi

    if ! [ "x$ISO20022_ICA_DAYS" == "x" ] ; then
      ISO20022_ICA_VALIDITY_OPT="-days ${ISO20022_ICA_VALIDITY_DAYS}"
    else
      if ! [ "x$ISO20022_ICA_VALIDITY_NOTBEFORE" == "x" ] ; then
        ISO20022_ICA_VALIDITY_OPT="-not_before $ISO20022_ICA_VALIDITY_NOTBEFORE"
      else
        ISO20022_ICA_VALIDITY_OPT="-not_before 20250101000000Z"
      fi
      if ! [ "x$ISO20022_ICA_VALIDITY_NOTAFTER" == "x" ] ; then
        ISO20022_ICA_VALIDITY_OPT="-not_after $ISO20022_ICA_VALIDITY_NOTAFTER"
      else
        ISO20022_ICA_VALIDITY_OPT="-not_after 99991231125959Z"
      fi
    fi

    if [ "x$ISO20022_ICA_GENERATE" = "xyes" ] ; then
      echo "  - Signing ISO20022 ICA Certificate... "
      res=$($OSSL_CMD x509 -req -CAkey "x9pki-dev/$OUT_DIR/root.key" -CAkeyform "$FORMAT" \
              -CAform "$FORMAT" -inform "$FORMAT" -outform "$FORMAT" \
              -CA "x9pki-dev/$OUT_DIR/root.cer" -in "x9pki-dev/$OUT_DIR/iso20022-ica.req" \
              -out "x9pki-dev/$OUT_DIR/iso20022-ica.cer" -extfile "profiles/iso20022-ica.profile" \
              $ISO20022_ICA_VALIDITY_OPT $PROVIDER 2>&1)
      if [ $? -gt 0 ] ; then
        echo
        echo "ERROR: Cannot create the ISO20022 Intermediate CA's certificate."
        echo
        echo $res
        echo
        exit 1
      fi

      # Cleanup
      rm -f "x9pki-dev/$OUT_DIR/iso20022-ica.req"

    else
      echo "  - ISO20022 ICA Request Signing skipped."
    fi

  else
    echo "ISO20022 ICA generation skipped."
  fi

  # Provides the PKI description
  res=$(echo \
      && echo "PKI x9pki-dev/$OUT_DIR (format: $FORMAT):" > "x9pki-dev/$OUT_DIR/description.txt" \
      && echo "  Root CA ($ROOT_ALG): root.cer" >> "x9pki-dev/$OUT_DIR/description.txt" \
      && echo "  CDN Intermediate CA ($CDN_ICA_ALG): cdn-ica.cer" >> "x9pki-dev/$OUT_DIR/description.txt" \
      && echo "  ISO20022 Intermediate CA ($ISO20022_ICA_ALG): iso20022-ica.cer" >> "x9pki-dev/$OUT_DIR/description.txt" \
      && echo )

done

echo && echo "All Done." && echo

exit 0
