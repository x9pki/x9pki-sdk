# Issuing CA Profile

subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer

basicConstraints = critical,CA:true
keyUsage = cRLSign, keyCertSign