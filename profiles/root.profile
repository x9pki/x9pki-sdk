# This is a sample root CA certificates.
#
# Usecase: Root CA

# Basic Constraints (CA)
basicConstraints=critical,CA:true

# Subject Key Identifier (SKID)
subjectKeyIdentifier=hash

# Key Usage
keyUsage=cRLSign,keyCertSign
