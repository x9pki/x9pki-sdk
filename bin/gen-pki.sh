#!/bin/bash

          # =========
          # Variables
          # =========

# OpenSSL Command Line Tool
OSSL_CMD=$(type -path openssl)
X9_SDK_CMD=$(type -path x9-sdk-chimera)
CURR_DIR=$PWD

          # ===================
          # Auxillary Functions
          # ===================

function subject_cn_fix_chimera() {

  local SUBJECT=$1
  local COMMON_NAME=$2

  if [ "x$SUBJECT" = "x" ]; then
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

  echo -e -n "$SUBJECT"
}


function subject_cn_fix() {

  local SUBJECT=$1
  local COMMON_NAME=$2

  if [ "x$SUBJECT" = "x" ] ; then
    SUBJECT="/O=X9 Financial PKI/CN=localhost"
  fi

  if ! [ "x$COMMON_NAME" = "x" ] ; then
    res=$( echo "$SUBJECT" | sed -e "s|/CN=[^/]*|/CN=$COMMON_NAME|" )
    if [ $? -gt 0 ] ; then
      echo && echo "    ERROR: issue with replacing the CN value" && echo
      exit 1
    fi
    SUBJECT=$res
  fi

  echo -e -n "$SUBJECT"
}

          # =================
          # Script Main Logic
          # =================

# Let's check we have the tools we need
if [ -z "$OSSL_CMD" ] ; then
  echo "ERROR: OpenSSL command not found."
  exit 1
fi
if [ -z "$X9_SDK_CMD" ] ; then
  echo "ERROR: x9-sdk-chimera command not found."
  exit 1
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

  # Creates the PKI directory, if it does not exsists
  mkdir -p "x9pki-dev/$OUT_DIR"

  # Sets the default format
  if [ "x$FORMAT" = "" ] ; then
    FORMAT="PEM"
  fi
  
  # ==================
  # Root CA Generation 
  # ==================

  if [ "x$ROOT_GENERATE" = "xyes" ] ; then
    

    if [ -f "x9pki-dev/$OUT_DIR/root.key" ] ; then
      echo && echo "NOTICE: Root CA already exists, skipping." && echo

    else
      echo && echo "Generating chimera Root CA's keys ... "
      if [ "$ROOT_HYBRID_TYPE" = "chimera" ]; then
        echo "  - Generating Root Native and Alt keys ..."
        res=$($X9_SDK_CMD genpkey \
                -outform "$FORMAT" \
                -native_key_alg "$ROOT_ALG" $ROOT_PARAMS  \
                -native_key_out "x9pki-dev/$OUT_DIR/$ROOT_KEY" \
                -alt_key_alg "$ROOT_ALT_ALG" $ROOT_ALT_PARAMS \
                -alt_key_out "x9pki-dev/$OUT_DIR/$ROOT_ALT_KEY" 2>&1 )
        if [ $? -gt 0 ] ; then
          echo && echo "ERROR: cannot generate the chimera Root keys: $res" && echo
          exit 1;
        fi

      else
        echo "  - Generating Root key ..."
        res=$($OSSL_CMD genpkey -algorithm $ROOT_ALG $ROOT_PARAMS \
                -outform "$FORMAT" -out "x9pki-dev/$OUT_DIR/root.key" \
                  $PROVIDER 2>&1)
        if [ $? -gt 0 ] ; then
          echo && echo "ERROR: cannot generate the Root key: $res" && echo
          exit 1;
        fi
      fi

      # Generates the CSRs
      echo "  - Generating Root CSR..."
      if [ "$ROOT_HYBRID_TYPE" = "chimera" ]; then
        ROOT_SUBJECT_NAME=$(subject_cn_fix_chimera "$ROOT_SUBJECT_NAME" )
        res=$($X9_SDK_CMD genreq \
                -outform "$FORMAT" \
                -subject_key "x9pki-dev/$OUT_DIR/$ROOT_KEY" \
                -subject_alt_key "x9pki-dev/$OUT_DIR/$ROOT_ALT_KEY" \
                -out "x9pki-dev/$OUT_DIR/$ROOT_REQ" \
                -subject "$ROOT_SUBJECT_NAME" 2>&1)
        if [ $? -gt 0 ] ; then
          echo
          echo "ERROR: Cannot create the chimera Root's CSR ($ROOT_SUBJECT_NAME)."
          echo
          echo "$res"
          echo
          exit 1
        fi
      else
        ROOT_SUBJECT_NAME=$(subject_cn_fix "$ROOT_SUBJECT_NAME" "$COMMON_NAME")
        res=$($OSSL_CMD req -new -key "x9pki-dev/$OUT_DIR/root.key" -inform "$FORMAT" \
                -out "x9pki-dev/$OUT_DIR/root.req" -outform "$FORMAT" \
                -subj "$ROOT_SUBJECT_NAME" $PROVIDER 2>&1)
        if [ $? -gt 0 ] ; then
          echo
          echo "ERROR: Cannot create the Root's CSR ($ROOT_SUBJECT_NAME)."
          echo
          echo "$res"
          echo
          exit 1
        fi
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
      if [ "$ROOT_HYBRID_TYPE" = "chimera" ]; then
        echo "  - Signing chimera Root CA Certificate... "
        res=$($X9_SDK_CMD gencert \
                -outform "$FORMAT" \
                -selfsigned \
                -req "x9pki-dev/$OUT_DIR/$ROOT_REQ" \
                -ca_native_key "x9pki-dev/$OUT_DIR/$ROOT_KEY" \
                -ca_alt_key "x9pki-dev/$OUT_DIR/$ROOT_ALT_KEY" \
                -extfile "profiles/root.profile" \
                -out "x9pki-dev/$OUT_DIR/$ROOT_CERT" \
                $ROOT_VALIDITY_OPT 2>&1 )
        if [ $? -gt 0 ] ; then
          echo
          echo "ERROR: Cannot self-sign the Root's CSR."
          echo
          echo "$res"
          echo
          exit 1
        fi

      else

        echo "  - Signing Root CA Certificate... "
        res=$($OSSL_CMD x509 -req -key "x9pki-dev/$OUT_DIR/$ROOT_KEY" \
                -inform "$FORMAT" -outform "$FORMAT" -in "x9pki-dev/$OUT_DIR/$ROOT_REQ" \
                -out "x9pki-dev/$OUT_DIR/$ROOT_CERT" -extfile "profiles/root.profile" \
                $ROOT_VALIDITY_OPT $PROVIDER 2>&1)
        if [ $? -gt 0 ] ; then
          echo
          echo "ERROR: Cannot self-sign the Root's CSR."
          echo
          echo "$res"
          echo
          exit 1
        fi
      fi
    fi

    # Cleanup
    [ -f "x9pki-dev/$OUT_DIR/$ROOT_REQ" ] && rm -f "x9pki-dev/$OUT_DIR/$ROOT_REQ"

  else
    echo "Root CA generation skipped."
  fi

  ## Here we use a new approach and we cycle through the ICA_LIST
  ## array of variables names. Then we use the variable names to
  ## access the corresponding values using indirect expansion. This allows us to
  ## handle multiple ICAs in a loop without duplicating code.
  for ICA in "${ICA_LIST[@]}"; do

    ## Gets the Variables Names
    ICA_GENERATE_VAR="${ICA}_GENERATE"
    ICA_HYBRID_TYPE_VAR="${ICA}_HYBRID_TYPE"

    ICA_ALG_VAR="${ICA}_ALG"
    ICA_KEY_VAR="${ICA}_KEY"
    ICA_PARAMS_VAR="${ICA}_PARAMS"

    ICA_ALT_ALG_VAR="${ICA}_ALT_ALG"
    ICA_ALT_KEY_VAR="${ICA}_ALT_KEY"
    ICA_ALT_PARAMS_VAR="${ICA}_ALT_PARAMS"

    ICA_SUBJECT_NAME_VAR="${ICA}_SUBJECT_NAME"
    ICA_VALIDITY_NOT_BEFORE_VAR="${ICA}_VALIDITY_NOT_BEFORE"
    ICA_VALIDITY_NOT_AFTER_VAR="${ICA}_VALIDITY_NOT_AFTER"

    ICA_REQ_VAR="${ICA}_REQ"
    ICA_CERT_VAR="${ICA}_CERT"

    ## Gets the Values for the ICA Variables
    ICA_GENERATE="${!ICA_GENERATE_VAR}"
    ICA_HYBRID_TYPE="${!ICA_HYBRID_TYPE_VAR}"

    ICA_ALG="${!ICA_ALG_VAR}"
    ICA_KEY="${!ICA_KEY_VAR}"
    ICA_PARAMS="${!ICA_PARAMS_VAR}"

    ICA_ALT_ALG="${!ICA_ALT_ALG_VAR}"
    ICA_ALT_KEY="${!ICA_ALT_KEY_VAR}"
    ICA_ALT_PARAMS="${!ICA_ALT_PARAMS_VAR}"

    ICA_SUBJECT_NAME="${!ICA_SUBJECT_NAME_VAR}"
    ICA_VALIDITY_NOT_BEFORE="${!ICA_VALIDITY_NOT_BEFORE_VAR}"
    ICA_VALIDITY_NOT_AFTER="${!ICA_VALIDITY_NOT_AFTER_VAR}"

    ICA_REQ="${!ICA_REQ_VAR}"
    ICA_CERT="${!ICA_CERT_VAR}"

    echo
    echo "* Processing ICA:"
    echo "  - ICA Name ..................... : $ICA"
    echo "  - ICA Hybrid Type .............. : $ICA_HYBRID_TYPE"
    echo "  - ICA Generate ................. : $ICA_GENERATE"
    echo "  - ICA Alg and Params ........... : $ICA_ALG $ICA_PARAMS"
    echo "  - ICA Alt Alg and Alt Params ... : $ICA_ALT_ALG $ICA_ALT_PARAMS"
    echo "  - ICA Subject Name ............. : $ICA_SUBJECT_NAME"
    echo "  - ICA Validity Not Before ...... : $ICA_VALIDITY_NOT_BEFORE"
    echo "  - ICA Validity Not After ....... : $ICA_VALIDITY_NOT_AFTER"
    echo "  - ICA Key ...................... : $ICA_KEY ($ICA_PARAMS)"
    echo "  - ICA Alt Key .................. : $ICA_ALT_KEY ($ICA_ALT_PARAMS)"
    echo "  - ICA Request .................. : $ICA_REQ"
    echo "  - ICA Cert ..................... : $ICA_CERT"
    echo

    if [ "x$ICA_GENERATE" = "xyes" -o "x$ICA_GENERATE" = "xreq" ] ; then

      if [ -f "x9pki-dev/$OUT_DIR/$ICA_KEY" ] ; then
        # ICA already exists, skipping
        echo "* $ICA key already exists, skipping."

      else

        # Generating the ICA key

        echo
        echo "* Generating Keys, CSR, and Certificate:"

        if [ "$ICA_HYBRID_TYPE" = "chimera" ]; then
          echo -E -n "  - Generating chimera $ICA key..."
          res=$($X9_SDK_CMD genpkey \
                  -outform "$FORMAT" \
                  -native_key_alg "$ICA_ALG" $ICA_PARAMS \
                  -native_key_out "x9pki-dev/$OUT_DIR/$ICA_KEY" \
                  -alt_key_alg "$ICA_ALT_ALG" $ICA_ALT_PARAMS \
                  -alt_key_out "x9pki-dev/$OUT_DIR/$ICA_ALT_KEY" 2>&1)
          if [ $? -gt 0 ] ; then
            echo && echo "ERROR: cannot generate the ICA key: $res" && echo
            exit 1;
          fi
        else
          echo -E -n "  - Generating $ICA key..."
          res=$($OSSL_CMD genpkey -algorithm $ICA_ALG $ICA_PARAMS \
                  -outform "$FORMAT" -out "x9pki-dev/$OUT_DIR/$ICA_KEY" \
                  $PROVIDER 2>&1)
          if [ $? -gt 0 ] ; then
            echo && echo "ERROR: cannot generate the ICA key: $res" && echo
            exit 1;
          fi
        fi
        echo " Ok"

        # Generating the ICA request
        if [ "$ICA_HYBRID_TYPE" = "chimera" ]; then
          echo -E -n "  - Generating chimera $ICA CSR..."
          ICA_SUBJECT_NAME=$(subject_cn_fix_chimera "$ICA_SUBJECT_NAME" )
          res=$($X9_SDK_CMD genreq \
                  -outform "$FORMAT" \
                  -subject_key "x9pki-dev/$OUT_DIR/$ICA_KEY" \
                  -subject_alt_key "x9pki-dev/$OUT_DIR/$ICA_ALT_KEY" \
                  -subject "$ICA_SUBJECT_NAME" \
                  -out "x9pki-dev/$OUT_DIR/$ICA.req" 2>&1)
          if [ $? -gt 0 ] ; then
            echo
            echo && echo "ERROR: Cannot create the Intermediate CA's CSR." && echo
            echo
            echo "$res"
            echo
            exit 1
          fi
        else
          echo -E -n "  - Generating $ICA CSR..."
          res=$($OSSL_CMD req -new -key "x9pki-dev/$OUT_DIR/$ICA_KEY" -outform "$FORMAT" -outform "$FORMAT" \
                  -out "x9pki-dev/$OUT_DIR/$ICA.req" -subj "$ICA_SUBJECT_NAME" $PROVIDER 2>&1)
          if [ $? -gt 0 ] ; then
            echo
            echo && echo "ERROR: Cannot create the Intermediate CA's CSR." && echo
            echo
            echo "$res"
            echo
            exit 1
          fi
        fi
        echo "Ok"

        if ! [ "x$ICA_VALIDITY_DAYS" == "x" ] ; then
          ICA_VALIDITY_OPT="-days ${ICA_VALIDITY_DAYS}"
        else
          if ! [ "x$ICA_VALIDITY_NOTBEFORE" == "x" ] ; then
            ICA_VALIDITY_OPT="-not_before $ICA_VALIDITY_NOTBEFORE"
          else
            ICA_VALIDITY_OPT="-not_before 20250101000000Z"
          fi
          if ! [ "x$ICA_VALIDITY_NOTAFTER" == "x" ] ; then
            ICA_VALIDITY_OPT="-not_after $ICA_VALIDITY_NOTAFTER"
          else
            ICA_VALIDITY_OPT="-not_after 99991231125959Z"
          fi
        fi

        if [ "x$ICA_GENERATE" = "xyes" ] ; then
          if [ "$ROOT_HYBRID_TYPE" = "chimera" ]; then
            echo -E -n "  - Signing chimera CDN ICA Certificate... "
            res=$($X9_SDK_CMD gencert \
                    -outform "$FORMAT" \
                    -req "x9pki-dev/$OUT_DIR/$ICA.req" \
                    -ca_native_key "x9pki-dev/$OUT_DIR/$ROOT_KEY" \
                    -ca_alt_key "x9pki-dev/$OUT_DIR/$ROOT_ALT_KEY" \
                    -ca_cert "x9pki-dev/$OUT_DIR/$ROOT_CERT" \
                    -extfile "profiles/cdn-ica.profile" \
                    -out "x9pki-dev/$OUT_DIR/$ICA_CERT" \
                    $ICA_VALIDITY_OPT 2>&1)
            if [ $? -gt 0 ] ; then
              echo
              echo "ERROR: Cannot create the CDN Intermediate CA's certificate."
              echo
              echo "$res"
              echo
              exit 1
            fi
          else
            echo -E -n "  - Signing CDN ICA Certificate... "
            res=$($OSSL_CMD x509 -req -CAkey "x9pki-dev/$OUT_DIR/$ROOT_KEY" -CAkeyform "$FORMAT" \
                    -CAform "$FORMAT" -inform "$FORMAT" -outform "$FORMAT" \
                    -CA "x9pki-dev/$OUT_DIR/$ROOT_CERT" -in "x9pki-dev/$OUT_DIR/$ICA.req" \
                    -out "x9pki-dev/$OUT_DIR/$ICA_CERT" -extfile "profiles/cdn-ica.profile" \
                    $ICA_VALIDITY_OPT $PROVIDER 2>&1)
            if [ $? -gt 0 ] ; then
              echo
              echo "ERROR: Cannot create the CDN Intermediate CA's certificate."
              echo
              echo "$res"
              echo
              exit 1
            fi
          fi
          echo "Ok"

          # Cleanup
          rm -f "x9pki-dev/$OUT_DIR/$ICA.req"

        else
          echo "  - CDN ICA Request Signing skipped."
        fi
      fi
    fi

  done

  echo
  echo "* Finished ($OUT_DIR) [ ${#ICA_LIST[0]} ICAs ]"
  echo

  # Provides the PKI description
  res=$(echo \
      && echo "PKI x9pki-dev/$OUT_DIR (format: $FORMAT):" > "x9pki-dev/$OUT_DIR/description.txt" \
      && echo "  Root CA ($ROOT_ALG): root.cer (root.cer)" >> "x9pki-dev/$OUT_DIR/description.txt" \
      && echo "  CDN Intermediate CA ($CDN_ICA_ALG): cdn-ica.cer" >> "x9pki-dev/$OUT_DIR/description.txt" \
      && echo "  ISO20022 Intermediate CA ($ISO20022_ICA_ALG): iso20022-ica.cer" >> "x9pki-dev/$OUT_DIR/description.txt" \
      && echo "  Generic Intermediate CA ($GENERIC_ICA_ALG): generic-ica.cer" >> "x9pki-dev/$OUT_DIR/description.txt" \
      && echo )

done

echo && echo "All Done." && echo

exit 0
