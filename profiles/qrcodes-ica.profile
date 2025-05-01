# This is a sample profile qrCode ICA certificates.
#
# Usecase: qrCode ICA

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

# Basic Constraints (CA)
basicConstraints=critical,CA:true

# Authority Key Identifier (AKID)
authorityKeyIdentifier=keyid:always,issuer

# Subject Key Identifier (SKID)
subjectKeyIdentifier=hash

# Key Usage
keyUsage=cRLSign,keyCertSign
