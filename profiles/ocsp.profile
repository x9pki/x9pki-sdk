# This is a sample profile for CDN TLS server certificates.
#
# Usecase: CDN TLS server

# Infrastructure extensions (disabled in the default SDK) and you can enable
# them in your installation, if supported.
#
# Authority Information Access
# authorityInfoAccess=OCSP;URI:http://<service_url>/<path>, caIssuers;URI:http://<service_url>/<path>
#
# CRL Distribution Points
# crlDistributionPoints = URI:http://<service_url>/<path>

# Certificate Policies
certificatePolicies=1.3.133.16.840.79.0.1

# Authority Key Identifier (AKID)
authorityKeyIdentifier=keyid:always,issuer

# Subject Key Identifier (SKID)
subjectKeyIdentifier=hash

# Key Usage
keyUsage=critical, digitalSignature

# Extended Key Usage
extendedKeyUsage=ocspSigning

# OCSP no-check (do not validate OCSP responder's certificate)
noCheck= 
